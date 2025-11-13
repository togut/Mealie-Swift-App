import Foundation

struct ReportSummary: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: String
    let category: ReportCategory
    let name: String
    let status: ReportSummaryStatus
}

struct ReportOut: Codable {
    let id: UUID
    let timestamp: String
    let category: ReportCategory
    let name: String
    let status: ReportSummaryStatus
    let entries: [ReportEntryOut]
}

struct ReportEntryOut: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: String
    let success: Bool
    let message: String
    let exception: String?
}

enum ReportCategory: String, Codable, CaseIterable, Identifiable {
    case backup, restore, migration, bulk_import
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .backup: return "Backup"
        case .restore: return "Restore"
        case .migration: return "Migration"
        case .bulk_import: return "Bulk Import"
        }
    }
}

enum ReportSummaryStatus: String, Codable {
    case inProgress = "in-progress"
    case success, failure, partial
}

struct SuccessResponse: Codable {
    let message: String
    let error: Bool?
}
