import Foundation

@Observable
class SettingsViewModel {
    var appInfo: AppInfo?
    var householdStats: HouseholdStatistics?
    var isLoading = false
    var errorMessage: String?
    
    var isCleaning = false
    var isCreatingBackup = false
    var maintenanceMessage: String?
    
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

    @MainActor
    func createBackup(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            maintenanceMessage = "API Client not available."
            return
        }
        isCreatingBackup = true
        maintenanceMessage = nil
        
        do {
            let response = try await apiClient.createBackup()
            maintenanceMessage = response.message
        } catch {
            maintenanceMessage = "Error creating backup: \(error.localizedDescription)"
        }
        isCreatingBackup = false
    }

    @MainActor
    func runCleanImages(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            maintenanceMessage = "API Client not available."
            return
        }
        isCleaning = true
        maintenanceMessage = nil
        
        do {
            let response = try await apiClient.cleanImages()
            maintenanceMessage = response.message
        } catch {
            maintenanceMessage = "Error cleaning images: \(error.localizedDescription)"
        }
        isCleaning = false
    }

    @MainActor
    func runCleanTemp(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            maintenanceMessage = "API Client not available."
            return
        }
        isCleaning = true
        maintenanceMessage = nil
        
        do {
            let response = try await apiClient.cleanTempFiles()
            maintenanceMessage = response.message
        } catch {
            maintenanceMessage = "Error cleaning temp files: \(error.localizedDescription)"
        }
        isCleaning = false
    }
}
