import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Logout", role: .destructive) {
                        appState.logout()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
