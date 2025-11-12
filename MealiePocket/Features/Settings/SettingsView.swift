import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss
    @State private var isAlertPresented = false
    @State private var viewModel = SettingsViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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

                    if let appInfo = viewModel.appInfo {
                        Section("Application") {
                            ServerInfoRow(title: "Mealie Version", value: appInfo.version)
                            ServerInfoRow(title: "Demo Mode", value: appInfo.demoStatus ? "Yes" : "No")
                            ServerInfoRow(title: "Allow Signups", value: appInfo.allowSignup ? "Yes" : "No")
                        }
                    }

                    if let user = appState.currentUser {
                        Section("User") {
                            ServerInfoRow(title: "Full Name", value: user.fullName ?? "N/A")
                            ServerInfoRow(title: "Username", value: user.email)
                            ServerInfoRow(title: "Group", value: user.group)
                            ServerInfoRow(title: "Household", value: user.household)
                            ServerInfoRow(title: "Admin", value: user.admin ? "Yes" : "No")
                        }
                    }

                    if let stats = viewModel.householdStats {
                        Section("Household Statistics") {
                            ServerInfoRow(title: "Total Recipes", value: "\(stats.totalRecipes)")
                            ServerInfoRow(title: "Total Categories", value: "\(stats.totalCategories)")
                            ServerInfoRow(title: "Total Tags", value: "\(stats.totalTags)")
                        }
                    }

                    if appState.currentUser?.admin == true {
                        Section("Admin & Maintenance") {
                            NavigationLink(destination: ReportsListView()) {
                                Label("Server Logs (Reports)", systemImage: "text.book.closed")
                            }

                            Button {
                                Task { await viewModel.createBackup(apiClient: appState.apiClient) }
                            } label: {
                                Label("Create Backup", systemImage: "archivebox")
                            }
                            .disabled(viewModel.isCleaning || viewModel.isCreatingBackup)
                            
                            Button {
                                Task { await viewModel.runCleanImages(apiClient: appState.apiClient) }
                            } label: {
                                Label("Clean Images", systemImage: "sparkles")
                            }
                            .disabled(viewModel.isCleaning || viewModel.isCreatingBackup)
                            
                            Button {
                                Task { await viewModel.runCleanTemp(apiClient: appState.apiClient) }
                            } label: {
                                Label("Clean Temp Files", systemImage: "trash")
                            }
                            .disabled(viewModel.isCleaning || viewModel.isCreatingBackup)

                            if viewModel.isCleaning || viewModel.isCreatingBackup {
                                ProgressView()
                            } else if let message = viewModel.maintenanceMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        Button("Logout", role: .destructive) {
                            appState.logout()
                        }
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Copied!", isPresented: $isAlertPresented) {
            Button("OK", role: .cancel) { }
        }
        .task {
            await viewModel.loadInfo(apiClient: appState.apiClient)
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
