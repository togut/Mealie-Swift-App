import Foundation

@Observable
class ReportsListViewModel {
    var reports: [ReportSummary] = []
    var isLoading = false
    var errorMessage: String?
    
    @MainActor
    func loadReports(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            errorMessage = "API Client not available."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            self.reports = try await apiClient.fetchReports()
        } catch {
            errorMessage = "Failed to load reports: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
