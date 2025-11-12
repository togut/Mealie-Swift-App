import SwiftUI

struct ReportDetailView: View {
    @State var viewModel: ReportDetailViewModel
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if let entries = viewModel.reportDetail?.entries, !entries.isEmpty {
                List(entries) { entry in
                    LogEntryView(entry: entry)
                }
            } else {
                ContentUnavailableView("No Log Entries", systemImage: "doc.text", description: Text("This report has no log entries."))
            }
        }
        .navigationTitle(viewModel.reportSummary.name)
        .task {
            await viewModel.loadReportDetail(apiClient: appState.apiClient)
        }
    }
}

struct LogEntryView: View {
    let entry: ReportEntryOut
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.success ? "checkmark.circle" : "xmark.circle")
                .foregroundStyle(entry.success ? .green : .red)
                .padding(.top, 2)
            
            VStack(alignment: .leading) {
                Text(entry.message)
                    .font(.body)
                
                if let exception = entry.exception, !exception.isEmpty {
                    Text(exception)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                
                Text(formattedDate(entry.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
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
