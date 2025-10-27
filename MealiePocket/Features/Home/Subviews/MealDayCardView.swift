import SwiftUI

struct MealDayCardView: View {
    let date: Date
    let entries: [ReadPlanEntry]
    let baseURL: URL?
    let onAddRecipeTapped: (Date) -> Void

    @Environment(AppState.self) private var appState

    @Environment(MealPlannerViewModel.self) private var mealPlannerViewModel
    @Binding var selectedTab: Int
    let plannerTabIndex = 2

    private let maxEntriesToShow = 4
    private var sortedEntries: [ReadPlanEntry] {
        entries.sorted {
            let typeOrder: [String: Int] = ["breakfast": 0, "lunch": 1, "dinner": 2, "side": 3]
            let order1 = typeOrder[$0.entryType.lowercased()] ?? 4
            let order2 = typeOrder[$1.entryType.lowercased()] ?? 4
            if order1 != order2 { return order1 < order2 }
            return ($0.recipe?.name ?? $0.title) < ($1.recipe?.name ?? $1.title)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(date, format: .dateTime.weekday(.wide).day())
                    .font(.headline)

                Spacer()

                Button {
                    onAddRecipeTapped(date)
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(4)
                        .glassEffect(.regular.tint(.accentColor), in: .circle)
                        
                }
            }
            .padding(.bottom, 10)

            if sortedEntries.isEmpty {
                Text("Rien de prévu")
                    .font(.callout)
                    .padding(.bottom, 10)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    let entriesToDisplay = sortedEntries.prefix(maxEntriesToShow)
                    ForEach(entriesToDisplay.prefix(sortedEntries.count >= maxEntriesToShow ? maxEntriesToShow - 1 : maxEntriesToShow)) { entry in
                        mealEntryRow(entry: entry)
                    }

                    if sortedEntries.count >= maxEntriesToShow {
                        HStack {
                            Spacer()
                            Button {
                                mealPlannerViewModel.selectDateAndView(date: date)
                                selectedTab = plannerTabIndex
                            } label: {
                                Text("Voir plus...")
                                    .font(.subheadline)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .glassEffect(.regular.tint(.clear).interactive())
                                
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .frame(width: 300)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func mealEntryRow(entry: ReadPlanEntry) -> some View {
        if let recipe = entry.recipe {
            NavigationLink(value: recipe) {
                HStack(spacing: 6) {
                    Image(systemName: iconForEntryType(entry.entryType))
                        .foregroundColor(.secondary)
                        .frame(width: 15)
                    
                    
                    Text(recipe.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            Text(entry.title.isEmpty ? entry.text : entry.title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundColor(.secondary)
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
