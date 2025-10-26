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

    init() {
        setupInitialMonths()
    }

    func setupInitialMonths(referenceDate: Date = Date()) {
         let calendar = Calendar.current
         let currentMonthStart = referenceDate.startOfMonth()
         guard let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonthStart),
               let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart)
         else {
             displayedMonths = [currentMonthStart]
             return
         }
         displayedMonths = [prevMonth, currentMonthStart, nextMonth]
     }

    // Calculer l'intervalle pour l'appel API basé sur les mois affichés
    private var dateIntervalForAPI: DateInterval {
         let calendar = Calendar.current
         
         // Pour Jour/Semaine, basé sur selectedDate
          if viewMode != .month {
              let component: Calendar.Component = viewMode == .day ? .day : .weekOfYear
              guard let interval = calendar.dateInterval(of: component, for: selectedDate) else {
                  return DateInterval(start: selectedDate, duration: 0)
              }
              return interval
          }

         // Pour Mois, basé sur displayedMonths
          guard let firstMonth = displayedMonths.first,
                let lastMonth = displayedMonths.last,
                let lastMonthInterval = calendar.dateInterval(of: .month, for: lastMonth),
                // Étendre d'un jour pour inclure la fin du dernier mois dans l'API
                let endDayForAPI = calendar.date(byAdding: .day, value: 1, to: lastMonthInterval.end)
          else {
              // Fallback au mois courant si displayedMonths est vide
               return calendar.dateInterval(of: .month, for: Date()) ?? DateInterval()
          }
          
          // Prendre le début du premier mois et la fin+1j du dernier mois
          return DateInterval(start: firstMonth.startOfMonth(), end: endDayForAPI)
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

    // Simplifié, ne recharge plus automatiquement
    func changeDate(_ direction: Int) {
         let component: Calendar.Component = viewMode == .day ? .day : (viewMode == .week ? .weekOfYear : .month)
         let dateToChange = selectedDate // Toujours basé sur selectedDate pour jour/semaine

         if let newDate = Calendar.current.date(byAdding: component, value: direction, to: dateToChange) {
             selectedDate = newDate
             // Le rechargement est déclenché par la vue via .task ou .onChange
         }
     }
     
    // Charge plus de mois (passé ou futur)
    func loadMoreMonths(direction: Int, apiClient: MealieAPIClient?) async {
         guard !isLoadingPast && !isLoadingFuture else { return } // Eviter chargements concurrents

         if direction < 0 { isLoadingPast = true }
         if direction > 0 { isLoadingFuture = true }

         let calendar = Calendar.current
         let monthsToAdd = 3 // Charger 3 mois à la fois

         if direction < 0, let firstMonth = displayedMonths.first {
             var newMonths: [Date] = []
             for i in (1...monthsToAdd).reversed() {
                 if let prev = calendar.date(byAdding: .month, value: -i, to: firstMonth) {
                     newMonths.append(prev)
                 }
             }
             if !newMonths.isEmpty {
                 displayedMonths.insert(contentsOf: newMonths, at: 0)
                 await loadMealPlan(apiClient: apiClient) // Recharger TOUT l'intervalle étendu
             }
         } else if direction > 0, let lastMonth = displayedMonths.last {
             var newMonths: [Date] = []
             for i in 1...monthsToAdd {
                 if let next = calendar.date(byAdding: .month, value: i, to: lastMonth) {
                     newMonths.append(next)
                 }
             }
              if !newMonths.isEmpty {
                  displayedMonths.append(contentsOf: newMonths)
                  await loadMealPlan(apiClient: apiClient) // Recharger TOUT l'intervalle étendu
              }
         }
         
         if direction < 0 { isLoadingPast = false }
         if direction > 0 { isLoadingFuture = false }
     }


     func goToToday(apiClient: MealieAPIClient?) {
          let today = Date()
          let todayMonthStart = today.startOfMonth()
          selectedDate = today
          
          // Vérifier si le mois d'aujourd'hui est déjà chargé
          if !displayedMonths.contains(todayMonthStart) {
               // Si non, réinitialiser les mois autour d'aujourd'hui
               setupInitialMonths(referenceDate: today)
               // Indiquer qu'un rechargement est nécessaire
               Task { await loadMealPlan(apiClient: apiClient) }
          } else {
               // Si déjà chargé, ne rien faire de plus (la vue scrollera)
          }
      }

    func selectDateAndView(date: Date) {
          selectedDate = date
          viewMode = .day
          // Recharger pour être sûr d'avoir les données du jour/semaine si l'intervalle API était différent
           Task { await loadMealPlan(apiClient: self.apiClient) }
      }

    func loadMealPlan(apiClient: MealieAPIClient? = nil) async {
        // Mettre à jour l'apiClient interne s'il est fourni
        if let apiClient = apiClient {
            self.apiClient = apiClient
        }
        
        // Utiliser l'apiClient interne (mis à jour ou initial)
        guard let client = self.apiClient else {
             // Essayer de le récupérer de AppState comme fallback (à adapter)
             guard let fallbackClient = AppState().apiClient else {
                  errorMessage = "API Client non disponible."
                  isLoading = false
                  isLoadingPast = false
                  isLoadingFuture = false
                  return
             }
             self.apiClient = fallbackClient
             await loadMealPlan()
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
            let perPage = viewMode == .month ? 1000 : 100 // Augmenter pour couvrir potentiellement plusieurs mois
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
                // Remplacer intelligemment les données au lieu de tout écraser
                // si c'est un chargement "more" ? Pour l'instant, on remplace tout.
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
