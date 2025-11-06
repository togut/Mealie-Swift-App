import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var mealPlannerViewModel = MealPlannerViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: 0) {
                    NavigationStack() {
                        HomeView(selectedTab: $selectedTab)
                            .environment(mealPlannerViewModel)
                    }
                }
                Tab("Recipes", systemImage: "book.fill", value: 1) {
                    NavigationStack {
                        RecipeListView()
                    }
                }
                Tab("Planner", systemImage: "calendar", value: 2) {
                    NavigationStack {
                        MealPlannerView()
                            .environment(mealPlannerViewModel)
                    }
                }
                Tab("Lists", systemImage: "list.bullet", value: 3) {
                    NavigationStack {
                        ShoppingListView()
                    }
                }
                Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                    NavigationStack {
                        SettingsView()
                    }
                }
            }
        }
    }
}

