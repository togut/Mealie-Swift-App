import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }

            MealPlannerView()
                .tabItem {
                    Label("Planner", systemImage: "calendar")
                }

            ShoppingListView()
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
