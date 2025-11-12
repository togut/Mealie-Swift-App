import Foundation

@Observable
class ReportDetailViewModel {
    var reportDetail: ReportOut?
    var isLoading = false
    var errorMessage: String?
    
    let reportSummary: ReportSummary
    
    init(reportSummary: ReportSummary) {
        self.reportSummary = reportSummary
    }
    
    @MainActor
    func loadReportDetail(apiClient: MealieAPIClient?) async {
        guard let apiClient else {
            errorMessage = "API Client not available."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            self.reportDetail = try await apiClient.fetchReportDetail(id: reportSummary.id)
        } catch {
            errorMessage = "Failed to load report details: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
