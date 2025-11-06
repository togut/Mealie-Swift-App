import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss
    @State private var isAlertPresented = false

    var body: some View {
        List {
            Section("Server Information") {
                ServerInfoRow(
                    title: "Server URL",
                    value: appState.apiClient?.baseURL.absoluteString ?? "N/A",
                    onCopy: {
                        if let url = appState.apiClient?.baseURL.absoluteString {
                            UIPasteboard.general.string = url
                            hapticImpact(style: .light)
                            isAlertPresented = true
                        }
                    }
                )
                ServerInfoRow(
                    title: "User ID",
                    value: appState.currentUserID ?? "N/A",
                    onCopy: {
                        if let currentUserID = appState.currentUserID {
                            UIPasteboard.general.string = currentUserID
                            hapticImpact(style: .light)
                            isAlertPresented = true
                        }
                    }
                )
                ServerInfoRow(title: "Auth Method", value: appState.authMethod?.rawValue.capitalized ?? "N/A")
                ServerInfoRow(title: "Last Auth", value: appState.loginTime?.formatted(date: .abbreviated, time: .shortened) ?? "N/A")
            }
            
            Section {
                Button("Logout", role: .destructive) {
                    appState.logout()
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Copied!", isPresented: $isAlertPresented) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        }
    }
}

struct ServerInfoRow: View {
    let title: String
    let value: String
    let onCopy: (() -> Void)?

    init(title: String, value: String, onCopy: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.onCopy = onCopy
    }
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if onCopy != nil {
                Button {
                    onCopy?()
                } label: {
                    Image(systemName: "document.on.document")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}
