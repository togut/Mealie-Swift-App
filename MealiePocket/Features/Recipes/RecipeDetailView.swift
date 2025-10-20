import SwiftUI

struct RecipeDetailView: View {
    let recipeSummary: RecipeSummary
    
    @State private var viewModel = RecipeDetailViewModel()
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let detail = viewModel.recipeDetail {
                    headerView(detail: detail)
                    
                    if let description = detail.description, !description.isEmpty {
                        Text(description)
                            .padding()
                    }
                    
                    timeSection(detail: detail)
                    
                    ingredientsSection(ingredients: detail.recipeIngredient)
                    
                    instructionsSection(instructions: detail.recipeInstructions)
                    
                } else if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .navigationTitle(recipeSummary.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRecipeDetail(slug: recipeSummary.slug, apiClient: appState.apiClient)
        }
    }
    
    private func headerView(detail: RecipeDetail) -> some View {
        VStack {
            AsyncImageView(
                url: .makeImageURL(
                    baseURL: appState.apiClient?.baseURL,
                    recipeID: detail.id,
                    imageName: "original.webp"
                )
            )
            .frame(height: 250)
            
            Text(detail.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func timeSection(detail: RecipeDetail) -> some View {
        HStack {
            TimeInfoView(label: "Total", time: detail.totalTime)
            Spacer()
            TimeInfoView(label: "Prep", time: detail.prepTime)
            Spacer()
            TimeInfoView(label: "Cook", time: detail.cookTime)
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private func ingredientsSection(ingredients: [RecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(ingredients) { ingredient in
                IngredientRow(text: ingredient.display)
            }
        }
        .padding()
    }
    
    private func instructionsSection(instructions: [RecipeInstruction]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Instructions")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(Array(instructions.enumerated()), id: \.element.id) { index, instruction in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .fontWeight(.bold)
                    Text(instruction.text)
                }
            }
        }
        .padding()
    }
}

struct TimeInfoView: View {
    let label: String
    let time: String?
    
    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(time ?? "None")
                .fontWeight(.medium)
        }
    }
}

struct IngredientRow: View {
    let text: String
    @State private var isChecked = false
    
    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .accentColor : .secondary)
                Text(text)
                    .strikethrough(isChecked, color: .secondary)
                    .foregroundColor(isChecked ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}
