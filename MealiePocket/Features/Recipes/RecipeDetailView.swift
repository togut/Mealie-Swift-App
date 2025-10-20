import SwiftUI

struct RecipeDetailView: View {
    let recipeSummary: RecipeSummary
    
    @State private var viewModel = RecipeDetailViewModel()
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let detail = viewModel.recipeDetail {
                    headerView(detail: detail)
                    
                    if let description = detail.description, !description.isEmpty {
                        Text(description)
                            .padding(.horizontal)
                    }
                    
                    Divider().padding(.horizontal)
                    
                    ingredientsSection(ingredients: detail.recipeIngredient)
                    
                    Divider().padding(.horizontal)
                    
                    instructionsSection(instructions: detail.recipeInstructions)
                    
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
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
        HStack(alignment: .top, spacing: 16) {
            AsyncImageView(
                url: .makeImageURL(
                    baseURL: appState.apiClient?.baseURL,
                    recipeID: detail.id,
                    imageName: "original.webp"
                )
            )
            .frame(width: 150, height: 150)
            .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 16) {
                TimeInfoView(label: "Total", time: detail.totalTime)
                TimeInfoView(label: "Prep", time: detail.prepTime)
                TimeInfoView(label: "Cook", time: detail.cookTime)
            }
        }
        .padding()
    }
    
    private func ingredientsSection(ingredients: [RecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(ingredients) { ingredient in
                    IngredientRow(text: ingredient.display)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func instructionsSection(instructions: [RecipeInstruction]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Instructions")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                ForEach(Array(instructions.enumerated()), id: \.element.id) { index, instruction in
                    InstructionRow(index: index, instruction: instruction)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

private struct TimeInfoView: View {
    let label: String
    let time: String?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(time ?? "None")
                .fontWeight(.medium)
        }
    }
}

private struct IngredientRow: View {
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
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct InstructionRow: View {
    let index: Int
    let instruction: RecipeInstruction
    @State private var isCompleted = false
    
    private var stepTitle: String {
        if let summary = instruction.summary, !summary.isEmpty {
            return summary
        } else if let title = instruction.title, !title.isEmpty {
            return title
        } else {
            return "Step \(index + 1)"
        }
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                isCompleted.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(stepTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .opacity(isCompleted ? 1 : 0)
                }
                
                if !isCompleted {
                    Text(instruction.text)
                        .font(.body)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .foregroundColor(.primary)
            .padding()
            .background(.thinMaterial)
            .cornerRadius(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

