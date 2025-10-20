import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Welcome to MealiePocket")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            VStack {
                TextField("Server URL", text: $viewModel.serverURL)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
                
                TextField("Username", text: $viewModel.username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: {
                    Task {
                        await viewModel.login(appState: appState)
                    }
                }) {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
    }
}
