import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var mealPlannerViewModel = MealPlannerViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(selectedTab: $selectedTab)
                        .environment(mealPlannerViewModel)
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

                NavigationStack {
                    RecipeListView()
                }
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }
                .tag(1)

                NavigationStack {
                    MealPlannerView()
                        .environment(mealPlannerViewModel)
                }
                .tabItem {
                    Label("Planner", systemImage: "calendar")
                }
                .tag(2)

                NavigationStack {
                    ShoppingListView()
                }
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
                .tag(3)

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
            }
        }
    }
}

