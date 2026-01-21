import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private var bugReportTemplate: String {
            """
            ## Bug Description
            <!-- Describe the bug clearly and concisely -->
            
            
            ## Steps to Reproduce
            1.
            2.
            3.
            
            ## Expected Behavior
            <!-- What did you expect to happen? -->
            
            
            ## Actual Behavior
            <!-- What actually happened? -->
            
            
            ## Screenshots
            <!-- If applicable, add screenshots to help explain the issue -->
            
            
            ## Device Information
            - App Version: \(appVersion)
            - iOS Version: \(UIDevice.current.systemVersion)
            - Device: \(UIDevice.current.model)
            """
    }
    
    private static let fallbackGitHubURL = URL(string: "https://github.com/Loriage/Mealie-Swift-App/issues")!
    private static let fallbackEmailURL = URL(string: "mailto:contact@nohit.dev")!
        
    private var bugReportGitHubURL: URL {
        var components = URLComponents(string: "https://github.com/Loriage/Mealie-Swift-App/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "[Bug] "),
            URLQueryItem(name: "body", value: bugReportTemplate)
        ]
        return components?.url ?? Self.fallbackGitHubURL
    }
        
    private var bugReportEmailURL: URL {
        var components = URLComponents(string: "mailto:contact@nohit.dev")
        components?.queryItems = [
            URLQueryItem(name: "subject", value: "[Bug Report] Beszel Companion"),
            URLQueryItem(name: "body", value: bugReportTemplate)
        ]
        return components?.url ?? Self.fallbackEmailURL
    }
    
    var body: some View {
        Group {
            List {
                if let user = appState.currentUser {
                    Section {
                        NavigationLink(destination: UserProfileView(user: user)) {
                            HStack(spacing: 15) {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.fullName ?? "User")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section("General") {
                    NavigationLink(destination: ServerInfoView(viewModel: viewModel)) {
                        HStack(spacing: 12) {
                            SettingsIconView(icon: "server.rack", color: .blue)
                            Text("Server & Application")
                        }
                    }
                    
                    NavigationLink(destination: StatisticsView(stats: viewModel.householdStats)) {
                        HStack(spacing: 12) {
                            SettingsIconView(icon: "chart.bar.xaxis", color: .orange)
                            Text("Statistics")
                        }
                    }
                }
                
                if appState.currentUser?.admin == true {
                    Section("Administration") {
                        NavigationLink(destination: AdminDashboardView(viewModel: viewModel)) {
                            HStack(spacing: 12) {
                                SettingsIconView(icon: "wrench.and.screwdriver.fill", color: .gray)
                                Text("Maintenance & Logs")
                            }
                        }
                    }
                }
                
                Section {
                    Link(destination: bugReportGitHubURL) {
                        HStack {
                            Image(systemName: "ant")
                            Text("settings.support.reportBug.github")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: bugReportEmailURL) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("settings.support.reportBug.email")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("settings.support")
                }

                Section {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Logout")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Version \(appVersion)")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            if viewModel.appInfo == nil {
                await viewModel.loadInfo(apiClient: appState.apiClient)
            }
        }
        .overlay {
            if viewModel.isLoading && appState.currentUser?.admin == true && viewModel.appInfo == nil {
                ProgressView("Loading...")
            }
        }
    }
}

struct UserProfileView: View {
    let user: User
    
    var body: some View {
        List {
            Section("Identity") {
                ServerInfoRow(title: "ID", value: user.id)
                ServerInfoRow(title: "Full Name", value: user.fullName ?? "N/A")
                ServerInfoRow(title: "Email", value: user.email)
            }
            
            Section("Permissions") {
                ServerInfoRow(title: "Group", value: user.group)
                ServerInfoRow(title: "Household", value: user.household)
                ServerInfoRow(title: "Admin Access", value: user.admin ? "Yes" : "No")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ServerInfoView: View {
    var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    @State private var isAlertPresented = false
    
    var body: some View {
        List {
            Section("Connection") {
                ServerInfoRow(
                    title: "Server URL",
                    value: appState.apiClient?.baseURL.absoluteString ?? "N/A",
                    onCopy: { copyToClipboard(appState.apiClient?.baseURL.absoluteString) }
                )
                ServerInfoRow(title: "Auth Method", value: appState.authMethod?.rawValue.capitalized ?? "N/A")
                ServerInfoRow(title: "Last Login", value: appState.loginTime?.formatted(date: .abbreviated, time: .shortened) ?? "N/A")
            }
            
            if let appInfo = viewModel.appInfo {
                Section("Application Details") {
                    ServerInfoRow(title: "Mealie Version", value: appInfo.version)
                    ServerInfoRow(title: "Demo Mode", value: appInfo.demoStatus ? "Yes" : "No")
                    ServerInfoRow(title: "Open Signups", value: appInfo.allowSignup ? "Allowed" : "Closed")
                    ServerInfoRow(title: "OpenAI Enabled", value: appInfo.enableOpenai ? "Yes" : "No")
                }
            }
        }
        .navigationTitle("Server Info")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Copied!", isPresented: $isAlertPresented) { Button("OK", role: .cancel) { } }
    }
    
    private func copyToClipboard(_ text: String?) {
        guard let text else { return }
        UIPasteboard.general.string = text
        hapticImpact(style: .light)
        isAlertPresented = true
    }
}

struct StatisticsView: View {
    let stats: HouseholdStatistics?
    
    var body: some View {
        List {
            if let stats = stats {
                Section {
                    LabeledContent("Total Recipes", value: "\(stats.totalRecipes)")
                    LabeledContent("Categories", value: "\(stats.totalCategories)")
                    LabeledContent("Tags", value: "\(stats.totalTags)")
                    LabeledContent("Tools", value: "\(stats.totalTools)")
                    LabeledContent("Users", value: "\(stats.totalUsers)")
                } header: {
                    Text("Household Data")
                } footer: {
                    Text("These statistics apply to your current household.")
                }
            } else {
                ContentUnavailableView("No Statistics", systemImage: "chart.bar.xaxis")
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AdminDashboardView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    
    var body: some View {
        List {
            Section("Logs") {
                NavigationLink(destination: ReportsListView()) {
                    HStack(spacing: 12) {
                        SettingsIconView(icon: "text.book.closed", color: .gray)
                        Text("View Server Reports")
                    }
                }
            }
            
            Section("Backups") {
                Button {
                    Task { await viewModel.createBackup(apiClient: appState.apiClient) }
                } label: {
                    HStack {
                        Spacer()
                        Text("Create New Backup")
                        Spacer()
                    }
                }
                .disabled(viewModel.isCleaning || viewModel.isCreatingBackup)
                .foregroundStyle(Color.blue)
            }
            
            Section("Maintenance") {
                Button {
                    Task { await viewModel.runCleanImages(apiClient: appState.apiClient) }
                } label: {
                    HStack {
                        Spacer()
                        Text("Clean Unused Images")
                        Spacer()
                    }
                }
                .disabled(viewModel.isCleaning || viewModel.isCreatingBackup)
                .foregroundStyle(.red)

                Button {
                    Task { await viewModel.runCleanTemp(apiClient: appState.apiClient) }
                } label: {
                    HStack {
                        Spacer()
                        Text("Clean Temporary Files")
                        Spacer()
                    }
                }
                .disabled(viewModel.isCleaning || viewModel.isCreatingBackup)
                .foregroundStyle(.red)
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            

            if viewModel.isCleaning || viewModel.isCreatingBackup {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.trailing, 5)
                        Text("Processing...")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }

            if let message = viewModel.maintenanceMessage {
                Section("Status") {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.inline)
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
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            if let onCopy {
                Button(action: onCopy) {
                    Image(systemName: "document.on.document")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
    }
}

struct SettingsIconView: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.gradient)
                .frame(width: 28, height: 28)
            
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
