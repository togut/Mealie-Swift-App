import SwiftUI

struct MealPlannerView: View {
    @State private var viewModel = MealPlannerViewModel()
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack {
            header
            
            if viewModel.isLoading {
                ProgressView()
                Spacer()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                calendarContent
            }
        }
        .navigationTitle("Planner")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Vue", selection: $viewModel.viewMode) {
                    ForEach(MealPlannerViewModel.ViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .task {
            await viewModel.loadMealPlan(apiClient: appState.apiClient)
        }
        .onChange(of: viewModel.viewMode) { _, _ in
            Task { await viewModel.loadMealPlan(apiClient: appState.apiClient) }
        }
        .navigationDestination(for: RecipeSummary.self) { recipe in
            RecipeDetailView(recipeSummary: recipe)
        }
    }
    
    private var header: some View {
        VStack(spacing: 5) {
            HStack {
                Button {
                    viewModel.changeDate(-1, apiClient: appState.apiClient)
                } label: { Image(systemName: "chevron.left") }
                    .padding(.leading)
                Spacer()
                Text(dateRangeTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button {
                    viewModel.changeDate(1, apiClient: appState.apiClient)
                } label: { Image(systemName: "chevron.right") }
                    .padding(.trailing)
            }
            .padding(.vertical, 8)
        }
    }
    
    private var calendarContent: some View {
        Group {
            if viewModel.viewMode == .month {
                ScrollView {
                    CalendarMonthView(
                        days: viewModel.daysInMonth,
                        mealPlanEntries: viewModel.mealPlanEntries,
                        selectedMonthDate: viewModel.selectedDate,
                        baseURL: appState.apiClient?.baseURL,
                        onDateSelected: { date in
                            viewModel.selectDateAndView(date: date)
                        }
                    )
                }
                
            } else {
                ScrollView {
                    if viewModel.viewMode == .week {
                        weekView
                    } else {
                        dayView
                    }
                }
            }
        }
    }
    
    private var weekView: some View {
        let days = viewModel.daysInWeek
        return VStack(alignment: .leading, spacing: 15) {
            ForEach(days, id: \.self) { date in
                VStack(alignment: .leading) {
                    HStack {
                        Text(date.formatted(.dateTime.weekday(.wide)))
                            .font(.headline)
                        Text(date.formatted(.dateTime.day()))
                            .font(.headline)
                            .bold(Calendar.current.isDateInToday(date))
                        Spacer()
                    }
                    .padding(.bottom, 5)
                    
                    mealEntriesList(for: date, showType: true)
                }
                
                if date != days.last {
                    Divider()
                }
            }
        }
        .padding()
    }
    
    private var dayView: some View {
        let date = Calendar.current.startOfDay(for: viewModel.selectedDate)
        return VStack(alignment: .leading) {
            Text(date.formatted(date: .complete, time: .omitted))
                .font(.title2)
                .bold()
                .padding(.bottom)
            mealEntriesList(for: date, showType: true)
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private func mealEntriesList(for date: Date, showType: Bool = false) -> some View {
        let entries = viewModel.mealPlanEntries[Calendar.current.startOfDay(for: date)] ?? []
        let sortedEntries = entries.sorted {
            let typeOrder: [String: Int] = ["breakfast": 0, "lunch": 1, "dinner": 2, "side": 3]
            let order1 = typeOrder[$0.entryType.lowercased()] ?? 4
            let order2 = typeOrder[$1.entryType.lowercased()] ?? 4
            if order1 != order2 {
                return order1 < order2
            }
            let name1 = $0.recipe?.name ?? $0.title
            let name2 = $1.recipe?.name ?? $1.title
            return name1 < name2
        }
        
        if entries.isEmpty {
            if viewModel.viewMode == .day {
                Text("Rien de prévu pour ce jour.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
            } else {
                Spacer().frame(height: 1)
            }
        } else {
            VStack(alignment: .leading, spacing: viewModel.viewMode == .month ? 1 : 8) {
                ForEach(sortedEntries) { entry in
                    mealEntryView(entry: entry, showType: showType)
                }
            }
            .padding(.horizontal, viewModel.viewMode == .month ? 0 : 5)
            .padding(.vertical, viewModel.viewMode == .month ? 0 : 5)
        }
    }
    
    @ViewBuilder
    private func mealEntryView(entry: ReadPlanEntry, showType: Bool) -> some View {
        HStack {
            if let recipe = entry.recipe {
                NavigationLink(value: recipe) {
                    labelView(entry: entry, recipeName: recipe.name, showType: showType)
                }
                .buttonStyle(.plain)
            } else {
                labelView(entry: entry, recipeName: nil, showType: showType)
            }
        }
    }
    
    @ViewBuilder
    private func labelView(entry: ReadPlanEntry, recipeName: String?, showType: Bool) -> some View {
        let isMonthView = viewModel.viewMode == .month
        let showTimes = !isMonthView && entry.recipe != nil &&
        ((entry.recipe?.totalTime?.isEmpty == false) || (entry.recipe?.prepTime?.isEmpty == false))

        let baseImageSize: CGFloat = isMonthView ? 16 : (showTimes ? 50 : 30)
        let placeholderSize: CGFloat = isMonthView ? 16 : 30
        
        HStack(spacing: isMonthView ? 4 : 8) {
            
            if let recipe = entry.recipe {
                AsyncImageView(url: .makeImageURL(
                    baseURL: appState.apiClient?.baseURL,
                    recipeID: recipe.id,
                    imageName: "min-original.webp"
                ))
                .frame(width: baseImageSize, height: baseImageSize)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: iconForEntryType(entry.entryType))
                    .foregroundColor(.accentColor)
                    .font(isMonthView ? .system(size: 10) : .callout)
                    .frame(width: placeholderSize, height: placeholderSize, alignment: .center)
                    .background(.thinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 3))
            }
            
            VStack(alignment: .leading, spacing: isMonthView ? 0 : 2) {
                if !isMonthView && (showType || viewModel.viewMode == .day) {
                    Text(entry.entryType.capitalized)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                Text(recipeName ?? (entry.title.isEmpty ? entry.text : entry.title))
                    .font(isMonthView ? .system(size: 9) : .body)
                    .lineLimit(1)
                
                if showTimes, let recipe = entry.recipe {
                    HStack(spacing: 6) {
                        if let totalTime = recipe.totalTime, !totalTime.isEmpty {
                            Label(totalTime, systemImage: "clock")
                        }
                        if let prepTime = recipe.prepTime, !prepTime.isEmpty {
                            Label(prepTime, systemImage: "stopwatch")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, isMonthView ? 2 : (showTimes ? 10 : 8))
        .padding(.horizontal, isMonthView ? 2 : 10)
        .background(
            isMonthView ? AnyShapeStyle(.clear) : AnyShapeStyle(.thinMaterial),
            in: RoundedRectangle(cornerRadius: isMonthView ? 3 : 8)
        )
    }
    
    private var dateRangeTitle: String {
        switch viewModel.viewMode {
        case .day:
            return viewModel.selectedDate.formatted(date: .complete, time: .omitted)
        case .week:
            guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: viewModel.selectedDate) else { return "" }
            let start = interval.start
            let end = interval.end.addingTimeInterval(-1)
            
            let startYear = Calendar.current.component(.year, from: start)
            let endYear = Calendar.current.component(.year, from: end)
            
            let monthDayFormat = Date.FormatStyle().month(.abbreviated).day()
            let monthDayYearFormat = Date.FormatStyle().month(.abbreviated).day().year()
            
            if startYear == endYear {
                return "\(start.formatted(monthDayFormat)) - \(end.formatted(monthDayFormat)), \(startYear)"
            } else {
                return "\(start.formatted(monthDayYearFormat)) - \(end.formatted(monthDayYearFormat))"
            }
        case .month:
            return viewModel.selectedDate.formatted(.dateTime.month(.wide).year())
        }
    }
    
    private func iconForEntryType(_ type: String) -> String {
        switch type.lowercased() {
        case "breakfast": return "sun.horizon.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        case "side": return "fork.knife"
        default: return "note.text"
        }
    }
}
