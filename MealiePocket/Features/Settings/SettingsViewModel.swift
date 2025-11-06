import Foundation

@Observable
class SettingsViewModel {
    var appInfo: AppInfo?
    var householdStats: HouseholdStatistics?
    var isLoading = false
    var errorMessage: String?
    
    @MainActor
    func loadInfo(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            errorMessage = "API Client not available."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let appInfoTask = apiClient.fetchAppInfo()
            async let statsTask = apiClient.fetchHouseholdStatistics()
            
            self.appInfo = try await appInfoTask
            self.householdStats = try await statsTask
            
        } catch {
            errorMessage = "Failed to load settings info: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
