import PuzzlesSync
import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var email = ""
    @State private var code = ""
    @State private var sentTo: String?
    @State private var failed = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                if let sentTo {
                    codeStep(sentTo)
                } else {
                    chooseStep
                }
            }
            .navigationTitle(sentTo == nil ? "Sign in to sync" : "Check your email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("sign_in_cancel")
                }
            }
            .onChange(of: SyncCenter.shared.signedIn) { _, signedIn in
                if signedIn {
                    dismiss()
                }
            }
        }
    }

    private var chooseStep: some View {
        Group {
            Section {
                Text("Sync your games and settings with the website and other devices.")
                provider("Sign in with Google", .google, tag: "sign_in_google")
                provider("Sign in with Microsoft", .microsoft, tag: "sign_in_microsoft")
            }
            Section("or") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("sign_in_email")
                if failed {
                    Text("We couldn't send the email. Try again in a minute.").foregroundStyle(.red)
                }
                Button("Email me a link") { sendLink() }
                    .disabled(busy || !email.contains("@"))
                    .accessibilityIdentifier("sign_in_email_send")
            }
        }
    }

    private func codeStep(_ address: String) -> some View {
        Section {
            Text("We sent a sign-in link and a code to \(address). Open the link on this phone, or enter the code.")
            TextField("Code", text: $code)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("sign_in_code")
                .onChange(of: code) { _, value in
                    code = String(value.filter(\.isNumber).prefix(SupabaseAuth.emailCodeLength))
                }
            if failed {
                Text("That code didn't work. Check it, or send a new one.").foregroundStyle(.red)
            }
            Button("Sign in") { verify(address) }
                .disabled(busy || code.count != SupabaseAuth.emailCodeLength)
                .accessibilityIdentifier("sign_in_code_submit")
            Button("Use a different email") {
                sentTo = nil
                code = ""
                failed = false
            }
            .accessibilityIdentifier("sign_in_code_back")
        }
    }

    private func provider(_ label: String, _ provider: SignInProvider, tag: String) -> some View {
        let dark = scheme == .dark
        let google = provider == .google
        let background = Color(hex: google ? (dark ? 0x131314 : 0xFFFFFF) : (dark ? 0x2F2F2F : 0xFFFFFF))
        let border = Color(hex: google ? (dark ? 0x8E918F : 0x747775) : (dark ? 0x2F2F2F : 0x8C8C8C))
        let text = Color(hex: google ? (dark ? 0xE3E3E3 : 0x1F1F1F) : (dark ? 0xFFFFFF : 0x5E5E5E))
        return Button {
            SyncCenter.shared.signIn(provider: provider)
        } label: {
            HStack(spacing: 12) {
                SignInLogo(provider: provider).frame(width: 20, height: 20)
                Text(label).foregroundStyle(text)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(background, in: .rect(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(border))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tag)
    }

    private func sendLink() {
        busy = true
        failed = false
        Task {
            if await SyncCenter.shared.auth.sendEmailLink(email: email) {
                sentTo = email.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                failed = true
            }
            busy = false
        }
    }

    private func verify(_ address: String) {
        busy = true
        failed = false
        Task {
            if await SyncCenter.shared.auth.verifyEmailCode(email: address, code: code) {
                SyncCenter.shared.signedInNow()
            } else {
                failed = true
            }
            busy = false
        }
    }
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private struct SignInLogo: View {
    let provider: SignInProvider

    private var viewport: CGFloat {
        provider == .google ? 48 : 21
    }

    private var shapes: [(UInt32, String)] {
        switch provider {
        case .google:
            [
                (
                    0xEA4335,
                    "M24,9.5c3.54,0 6.71,1.22 9.21,3.6l6.85,-6.85C35.9,2.38 30.47,0 24,0 14.62,0 6.51,5.38 2.56,13.22l7.98,6.19C12.43,13.72 17.74,9.5 24,9.5z"
                ),
                (
                    0x4285F4,
                    "M46.98,24.55c0,-1.57 -0.15,-3.09 -0.38,-4.55H24v9.02h12.94c-0.58,2.96 -2.26,5.48 -4.78,7.18l7.73,6c4.51,-4.18 7.09,-10.36 7.09,-17.65z"
                ),
                (
                    0xFBBC05,
                    "M10.53,28.59c-0.48,-1.45 -0.76,-2.99 -0.76,-4.59s0.27,-3.14 0.76,-4.59l-7.98,-6.19C0.92,16.46 0,20.12 0,24c0,3.88 0.92,7.54 2.56,10.78l7.97,-6.19z"
                ),
                (
                    0x34A853,
                    "M24,48c6.48,0 11.93,-2.13 15.89,-5.81l-7.73,-6c-2.15,1.45 -4.92,2.3 -8.16,2.3 -6.26,0 -11.57,-4.22 -13.47,-9.91l-7.98,6.19C6.51,42.62 14.62,48 24,48z"
                ),
            ]
        case .microsoft:
            [
                (0xF25022, "M1,1h9v9h-9z"), (0x7FBA00, "M11,1h9v9h-9z"),
                (0x00A4EF, "M1,11h9v9h-9z"), (0xFFB900, "M11,11h9v9h-9z"),
            ]
        }
    }

    var body: some View {
        Canvas { context, size in
            let scale = size.width / viewport
            for (color, data) in shapes {
                let path = Path(SVGPath.parse(data).cgPath).applying(CGAffineTransform(scaleX: scale, y: scale))
                context.fill(path, with: .color(Color(hex: color)))
            }
        }
        .accessibilityHidden(true)
    }
}
