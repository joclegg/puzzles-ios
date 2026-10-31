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
        Button {
            SyncCenter.shared.signIn(provider: provider)
        } label: {
            Text(label)
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(scheme == .dark ? Color.white : Color.black)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary))
        }
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
