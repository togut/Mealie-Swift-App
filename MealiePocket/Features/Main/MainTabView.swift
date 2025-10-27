import SwiftUI

struct MainTabView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView {
                Tab("Home", systemImage: "house.fill") {
                    NavigationStack {
                        HomeView()
                    }
                }
                Tab("Recipes", systemImage: "book.fill") {
                    NavigationStack {
                        RecipeListView()
                    }
                }
                Tab("Planner", systemImage: "calendar") {
                    NavigationStack {
                        MealPlannerView()
                    }
                }
                Tab("Shopping", systemImage: "cart.fill") {
                    NavigationStack {
                        ShoppingListView()
                    }
                }
                Tab("Settings", systemImage: "gearshape.fill") {
                    NavigationStack {
                        SettingsView()
                    }
                }
            }
        }
    }
}
