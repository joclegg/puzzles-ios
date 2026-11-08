import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STORE = Path(__file__).resolve().parent.parent / "store"
API = "https://api.appstoreconnect.apple.com"


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def der_integer(der, offset):
    length = der[offset + 1]
    value = der[offset + 2 : offset + 2 + length]
    return value.lstrip(b"\0").rjust(32, b"\0"), offset + 2 + length


def token():
    header = b64(json.dumps({"alg": "ES256", "kid": os.environ["KEY_ID"], "typ": "JWT"}).encode())
    now = int(time.time())
    claims = {"iss": os.environ["ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    payload = b64(json.dumps(claims).encode())
    signed = header + b"." + payload
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", os.environ["KEY_PATH"]],
        input=signed, capture_output=True, check=True,
    ).stdout
    r, offset = der_integer(der, 3 if der[1] & 0x80 else 2)
    s, _ = der_integer(der, offset)
    return (signed + b"." + b64(r + s)).decode()


AUTH = token()


def call(method, path, body=None):
    request = urllib.request.Request(
        API + path,
        method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {AUTH}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request) as response:
            text = response.read()
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path} failed with {error.code}: {error.read().decode()}")
    return json.loads(text) if text else {}


def text(locale, name):
    path = STORE / locale / f"{name}.txt"
    return path.read_text().strip() if path.exists() else None


def editable(items, states):
    return next((item for item in items if item["attributes"][states] in EDITABLE), None)


DONE = {"READY_FOR_SALE", "REPLACED_WITH_NEW_VERSION", "REMOVED_FROM_SALE", "DEVELOPER_REMOVED_FROM_SALE"}

EDITABLE = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}


def localization_id(version_id, locale):
    existing = call("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    return next(item["id"] for item in existing if item["attributes"]["locale"] == locale)


def upload_screenshots(localization):
    files = sorted((STORE / "screenshots").glob("*.png"))
    wanted = [hashlib.md5(path.read_bytes()).hexdigest() for path in files]
    sets = call("GET", f"/v1/appStoreVersionLocalizations/{localization}/appScreenshotSets")["data"]
    for old in sets:
        if old["attributes"]["screenshotDisplayType"] != "APP_IPHONE_67":
            continue
        current = call("GET", f"/v1/appScreenshotSets/{old['id']}/appScreenshots?limit=10")["data"]
        if [shot["attributes"]["sourceFileChecksum"] for shot in current] == wanted:
            print("Screenshots are unchanged")
            return
    for old in sets:
        if old["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67":
            call("DELETE", f"/v1/appScreenshotSets/{old['id']}")
    screenshot_set = call("POST", "/v1/appScreenshotSets", {"data": {
        "type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
        "relationships": {"appStoreVersionLocalization": {"data": {
            "type": "appStoreVersionLocalizations", "id": localization}}},
    }})["data"]
    for path in files:
        data = path.read_bytes()
        screenshot = call("POST", "/v1/appScreenshots", {"data": {
            "type": "appScreenshots",
            "attributes": {"fileName": path.name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": screenshot_set["id"]}}},
        }})["data"]
        for operation in screenshot["attributes"]["uploadOperations"]:
            part = data[operation["offset"] : operation["offset"] + operation["length"]]
            headers = {header["name"]: header["value"] for header in operation["requestHeaders"]}
            request = urllib.request.Request(operation["url"], method=operation["method"], data=part, headers=headers)
            urllib.request.urlopen(request).read()
        call("PATCH", f"/v1/appScreenshots/{screenshot['id']}", {"data": {
            "type": "appScreenshots", "id": screenshot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


def main():
    version_string = sys.argv[1]
    config = json.loads((STORE / "app.json").read_text())
    locale = config["primaryLocale"]

    app = call("GET", f"/v1/apps?filter%5BbundleId%5D={config['bundleId']}")["data"][0]
    app_id = app["id"]
    call("PATCH", f"/v1/apps/{app_id}", {"data": {"type": "apps", "id": app_id, "attributes": {
        "contentRightsDeclaration": config["contentRightsDeclaration"]}}})

    versions = call("GET", f"/v1/apps/{app_id}/appStoreVersions?filter%5Bplatform%5D=IOS&limit=50")["data"]
    released = any(v["attributes"]["appStoreState"] == "READY_FOR_SALE" for v in versions)
    version = editable(versions, "appStoreState")
    attributes = {"versionString": version_string, "copyright": f"{time.gmtime().tm_year} {config['copyright']}"}
    if version is None and any(v["attributes"]["appStoreState"] not in DONE for v in versions):
        print("A version is with App Review, so the listing is left as it is")
        return
    if version is None:
        version = call("POST", "/v1/appStoreVersions", {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", **attributes},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }})["data"]
    else:
        call("PATCH", f"/v1/appStoreVersions/{version['id']}", {"data": {
            "type": "appStoreVersions", "id": version["id"], "attributes": attributes}})
    version_id = version["id"]

    localization = {
        "description": text(locale, "description"),
        "keywords": text(locale, "keywords"),
        "promotionalText": text(locale, "promotional-text"),
        "supportUrl": text(locale, "support-url"),
        "marketingUrl": text(locale, "marketing-url"),
    }
    if released:
        localization["whatsNew"] = text(locale, "release-notes")
    existing = call("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    match = next((item for item in existing if item["attributes"]["locale"] == locale), None)
    if match is None:
        call("POST", "/v1/appStoreVersionLocalizations", {"data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {"locale": locale, **localization},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
        }})
    else:
        call("PATCH", f"/v1/appStoreVersionLocalizations/{match['id']}", {"data": {
            "type": "appStoreVersionLocalizations", "id": match["id"], "attributes": localization}})

    info = editable(call("GET", f"/v1/apps/{app_id}/appInfos")["data"], "state")
    if info is not None:
        categories = {
            key: {"data": {"type": "appCategories", "id": config[key]}}
            for key in ("primaryCategory", "primarySubcategoryOne", "primarySubcategoryTwo")
        }
        call("PATCH", f"/v1/appInfos/{info['id']}", {"data": {
            "type": "appInfos", "id": info["id"], "relationships": categories}})
        info_localizations = call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]
        info_localization = next(item for item in info_localizations if item["attributes"]["locale"] == locale)
        call("PATCH", f"/v1/appInfoLocalizations/{info_localization['id']}", {"data": {
            "type": "appInfoLocalizations", "id": info_localization["id"], "attributes": {
                "name": text(locale, "name"),
                "subtitle": text(locale, "subtitle"),
                "privacyPolicyUrl": text(locale, "privacy-policy-url"),
            }}})
        rating = call("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]
        call("PATCH", f"/v1/ageRatingDeclarations/{rating['id']}", {"data": {
            "type": "ageRatingDeclarations", "id": rating["id"],
            "attributes": json.loads((STORE / "age-rating.json").read_text())}})

    review = dict(config["reviewContact"])
    review["contactPhone"] = os.environ.get("REVIEW_CONTACT_PHONE") or review["contactPhone"]
    if review["contactPhone"]:
        detail = call("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail").get("data")
        if detail is None:
            call("POST", "/v1/appStoreReviewDetails", {"data": {
                "type": "appStoreReviewDetails", "attributes": review,
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }})
        else:
            call("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", {"data": {
                "type": "appStoreReviewDetails", "id": detail["id"], "attributes": review}})

    upload_screenshots(localization_id(version_id, locale))

    print(f"Updated the App Store listing for version {version_string} ({version_id})")


main()
