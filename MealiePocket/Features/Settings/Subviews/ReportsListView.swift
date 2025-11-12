import SwiftUI

struct ReportsListView: View {
    @State private var viewModel = ReportsListViewModel()
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if viewModel.reports.isEmpty {
                ContentUnavailableView("No Reports", systemImage: "text.book.closed", description: Text("No server reports were found."))
            } else {
                List(viewModel.reports) { report in
                    NavigationLink(value: report) {
                        ReportRowView(report: report)
                    }
                }
            }
        }
        .navigationTitle("Server Logs")
        .task {
            await viewModel.loadReports(apiClient: appState.apiClient)
        }
        .navigationDestination(for: ReportSummary.self) { report in
            ReportDetailView(viewModel: ReportDetailViewModel(reportSummary: report))
        }
    }
}

struct ReportRowView: View {
    let report: ReportSummary
    
    var body: some View {
        HStack {
            Image(systemName: iconForStatus(report.status))
                .font(.title2)
                .foregroundStyle(colorForStatus(report.status))
            
            VStack(alignment: .leading) {
                Text(report.name)
                    .font(.headline)
                Text(report.category.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(formattedDate(report.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    func iconForStatus(_ status: ReportSummaryStatus) -> String {
        switch status {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .partial: "exclamationmark.triangle.fill"
        case .inProgress: "hourglass"
        }
    }
    
    func colorForStatus(_ status: ReportSummaryStatus) -> Color {
        switch status {
        case .success: .green
        case .failure: .red
        case .partial: .orange
        case .inProgress: .blue
        }
    }
    
    func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date.formatted(date: .numeric, time: .shortened)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return date.formatted(date: .numeric, time: .shortened)
        }
        return "Invalid Date"
    }
}
