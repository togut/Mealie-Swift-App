import Foundation
import SwiftUI

@Observable
class MealPlannerViewModel {
    
    enum ViewMode: String, CaseIterable, Identifiable {
        case day = "Jour"
        case week = "Semaine"
        case month = "Mois"
        var id: String { self.rawValue }
    }
    
    var selectedDate = Date()
    var viewMode: ViewMode = .month
    var mealPlanEntries: [Date: [ReadPlanEntry]] = [:]
    var isLoading = false
    var errorMessage: String?
    
    private var dateIntervalForAPI: DateInterval {
        let calendar = Calendar.current
        let targetDate = selectedDate
        let component: Calendar.Component = viewMode == .day ? .day : (viewMode == .week ? .weekOfYear : .month)
        guard let interval = calendar.dateInterval(of: component, for: targetDate) else {
            return DateInterval(start: targetDate, duration: 0)
        }
        
        if viewMode == .month {
            let days = generateDaysInMonth(for: targetDate)
            if let first = days.first, let last = days.last {
                return DateInterval(start: first, end: last.addingTimeInterval(86400))
            }
        }
        return interval
    }
    
    var daysInMonth: [Date] {
        generateDaysInMonth(for: selectedDate)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private func generateDaysInMonth(for date: Date) -> [Date] {
        Calendar.current.generateDaysInMonth(for: date)
    }

    func changeDate(_ direction: Int, apiClient: MealieAPIClient?) {
        let component: Calendar.Component = viewMode == .day ? .day : (viewMode == .week ? .weekOfYear : .month)
        if let newDate = Calendar.current.date(byAdding: component, value: direction, to: selectedDate) {
            selectedDate = newDate
            Task { await loadMealPlan(apiClient: apiClient) }
        }
    }

    func goToToday(apiClient: MealieAPIClient?) {
        selectedDate = Date()
        Task { await loadMealPlan(apiClient: apiClient) }
    }
    
    func loadMealPlan(apiClient: MealieAPIClient? = nil) async {
        guard let client = apiClient else {
            errorMessage = "API Client non disponible."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let interval = dateIntervalForAPI
        let startDateString = dateFormatter.string(from: interval.start)
        let endDateString = dateFormatter.string(from: interval.end)
        
        do {
            let perPage = viewMode == .month ? 200 : 100
            let response = try await client.fetchMealPlanEntries(startDate: startDateString, endDate: endDateString, perPage: perPage)
            
            var groupedEntries: [Date: [ReadPlanEntry]] = [:]
            for entry in response.items {
                if let entryDate = dateFormatter.date(from: entry.date) {
                    let dayStart = Calendar.current.startOfDay(for: entryDate)
                    groupedEntries[dayStart, default: []].append(entry)
                } else {
                    print("Warning: Could not parse date string \(entry.date)")
                }
            }
            
            await MainActor.run {
                self.mealPlanEntries = groupedEntries
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Erreur de chargement du planning: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    var daysInWeek: [Date] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return Calendar.current.generateDates(for: weekInterval, matching: DateComponents(hour: 0, minute: 0, second: 0))
    }
}
