import SwiftUI

struct MainTabView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            TabView {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                
                NavigationStack {
                    RecipeListView()
                }
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }

                NavigationStack {
                    MealPlannerView()
                }
                .tabItem {
                    Label("Planner", systemImage: "calendar")
                }

                NavigationStack {
                    ShoppingListView()
                }
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
                
                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
        }
    }
}
