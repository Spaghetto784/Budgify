import SwiftUI

struct ProtectedTabView<Content: View>: View {
    let tabName: String
    @Environment(SettingsViewModel.self) private var settingsVM
    @ViewBuilder let content: Content
    @State private var authFailed = false

    var body: some View {
        Group {
            if !settingsVM.isTabProtected(tabName) || settingsVM.isTabUnlocked(tabName) {
                content
            } else {
                lockView
            }
        }
        .onAppear {
            if settingsVM.isTabProtected(tabName) && !settingsVM.isTabUnlocked(tabName) {
                Task { await settingsVM.authenticate(for: tabName) }
            }
        }
    }

    private var lockView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(tabName)
                .font(.title2.bold())
            if authFailed {
                Text("Authentification échouée")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button("Déverrouiller") {
                Task {
                    let ok = await settingsVM.authenticate(for: tabName)
                    if !ok { authFailed = true }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle(tabName)
    }
}
