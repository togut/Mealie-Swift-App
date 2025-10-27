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
    var isLoadingPast = false
    var isLoadingFuture = false
    var errorMessage: String?
    
    var displayedMonths: [Date] = []
    
    private var apiClient: MealieAPIClient?
    
    private var currentMonthStart: Date {
        Date().startOfMonth()
    }
    
    init() {
        setupInitialMonths()
    }
    
    func setupInitialMonths(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let currentMonthStart = referenceDate.startOfMonth()
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart),
              let nextMonth2 = calendar.date(byAdding: .month, value: 2, to: currentMonthStart)
        else {
            displayedMonths = [currentMonthStart]
            return
        }
        displayedMonths = [currentMonthStart, nextMonth, nextMonth2]
    }
    
    private var dateIntervalForAPI: DateInterval {
        let calendar = Calendar.current
        
        if viewMode != .month {
            let component: Calendar.Component = viewMode == .day ? .day : .weekOfYear
            guard let interval = calendar.dateInterval(of: component, for: selectedDate) else {
                return DateInterval(start: selectedDate, duration: 0)
            }
            return interval
        }
        
        guard let firstMonth = displayedMonths.first,
              let lastMonth = displayedMonths.last,
              let lastMonthInterval = calendar.dateInterval(of: .month, for: lastMonth),
              let endDayForAPI = calendar.date(byAdding: .day, value: 1, to: lastMonthInterval.end)
        else {
            return calendar.dateInterval(of: .month, for: Date()) ?? DateInterval()
        }
        
        return DateInterval(start: firstMonth.startOfMonth(), end: endDayForAPI)
    }
    
    var canChangeDateBack: Bool {
        let calendar = Calendar.current
        let component: Calendar.Component = viewMode == .day ? .day : .weekOfYear
        
        guard let newDate = calendar.date(byAdding: component, value: -1, to: selectedDate) else {
            return false
        }
        
        if viewMode == .day {
            return newDate >= currentMonthStart
        } else if viewMode == .week {
            guard let newWeekInterval = calendar.dateInterval(of: .weekOfYear, for: newDate) else {
                return false
            }
            return newWeekInterval.end > currentMonthStart
        }
        
        return false
    }
    
    var daysInSpecificMonth: (Date) -> [Date] = { date in
        Calendar.current.generateDaysInMonth(for: date)
    }
    
    var daysInWeek: [Date] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return Calendar.current.generateDates(for: weekInterval, matching: DateComponents(hour: 0, minute: 0, second: 0))
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    func changeDate(_ direction: Int) {
        let component: Calendar.Component = viewMode == .day ? .day : (viewMode == .week ? .weekOfYear : .month)
        let dateToChange = selectedDate
        
        if let newDate = Calendar.current.date(byAdding: component, value: direction, to: dateToChange) {
            selectedDate = newDate
        }
    }
    
    func loadMoreMonths(direction: Int, apiClient: MealieAPIClient?) async {
        guard !isLoadingPast && !isLoadingFuture else { return }
        
        if direction < 0 {
            return
        }
        
        if direction > 0 { isLoadingFuture = true }
        
        let calendar = Calendar.current
        let monthsToAdd = 3
        
        if direction > 0, let lastMonth = displayedMonths.last {
            var newMonths: [Date] = []
            for i in 1...monthsToAdd {
                if let next = calendar.date(byAdding: .month, value: i, to: lastMonth) {
                    newMonths.append(next)
                }
            }
            if !newMonths.isEmpty {
                displayedMonths.append(contentsOf: newMonths)
                await loadMealPlan(apiClient: apiClient)
            }
        }
        
        if direction > 0 { isLoadingFuture = false }
    }
    
    
    func goToToday(apiClient: MealieAPIClient?) {
        let today = Date()
        let todayMonthStart = today.startOfMonth()
        selectedDate = today
        
        if viewMode != .month || !displayedMonths.contains(todayMonthStart) {
            if !displayedMonths.contains(todayMonthStart) {
                setupInitialMonths(referenceDate: today)
            }
            Task { await loadMealPlan(apiClient: apiClient) }
        }
    }
    
    func selectDateAndView(date: Date) {
        selectedDate = date
        viewMode = .day
        Task { await loadMealPlan(apiClient: self.apiClient) }
    }
    
    func loadMealPlan(apiClient: MealieAPIClient? = nil) async {
        if let apiClient = apiClient {
            self.apiClient = apiClient
        }
        
        guard let client = self.apiClient else {
            errorMessage = "API Client non disponible."
            isLoading = false
            isLoadingPast = false
            isLoadingFuture = false
            return
        }
        
        if !isLoadingPast && !isLoadingFuture {
            isLoading = true
        }
        errorMessage = nil
        
        let interval = dateIntervalForAPI
        let startDateString = dateFormatter.string(from: interval.start)
        let endDateString = dateFormatter.string(from: interval.end)
        
        do {
            let perPage = viewMode == .month ? 1000 : 100
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
                self.isLoadingPast = false
                self.isLoadingFuture = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Erreur de chargement du planning: \(error.localizedDescription)"
                self.isLoading = false
                self.isLoadingPast = false
                self.isLoadingFuture = false
            }
        }
    }
}
