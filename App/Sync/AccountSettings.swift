import SwiftUI

struct AccountSettings: View {
    @State private var confirming = false
    @State private var deleting = false
    @State private var failed = false

    var body: some View {
        if SyncCenter.shared.signedIn {
            VStack(alignment: .leading, spacing: 12) {
                Text("Account").font(.headline)
                if let email = SyncCenter.shared.email {
                    Text(email).font(.subheadline).foregroundStyle(.secondary)
                }
                Button("Delete account", role: .destructive) { confirming = true }
                    .buttonStyle(.bordered)
                    .disabled(deleting)
                    .accessibilityIdentifier("delete_account")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .modifier(SudokuTileStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .confirmationDialog("Delete account?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { delete() }
                    .accessibilityIdentifier("delete_account_confirm")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Your synced scores, history and settings will be permanently deleted from the server. Data on this device stays."
                )
            }
            .alert("Couldn't delete account", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check your connection and try again. You're still signed in.")
            }
        }
    }

    private func delete() {
        deleting = true
        Task {
            let deleted = await SyncCenter.shared.deleteAccount()
            deleting = false
            failed = !deleted
        }
    }
}
