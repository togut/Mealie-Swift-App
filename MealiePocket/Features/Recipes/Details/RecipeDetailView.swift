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
                    
                    Divider().padding(.horizontal)
                    
                    ingredientsSection(ingredients: detail.recipeIngredient)
                    
                    Divider().padding(.horizontal)
                    
                    instructionsSection(instructions: detail.recipeInstructions)
                    
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(recipeSummary.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRecipeDetail(slug: recipeSummary.slug, apiClient: appState.apiClient, userID: appState.currentUserID)
        }
    }
    
    private func headerView(detail: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
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
                
                VStack(alignment: .leading, spacing: 10) {
                    TimeInfoView(icon: "clock", label: "Total", value: detail.totalTime)

                    HStack(spacing: 1) {
                        TimeInfoView(icon: "stopwatch", label: "Preparation", value: detail.prepTime)
                        Divider().padding()
                        TimeInfoView(icon: "frying.pan", label: "Cooking", value: detail.cookTime)
                    }

                    let servingsValue: Double? = detail.recipeServings
                    let isSingular: Bool = servingsValue == 1.0
                    
                    let servingsLabel: String = isSingular ? "Portion" : "Portions"
                    let servingsIcon: String = isSingular ? "person" : "person.2"
                    
                    if let servingsValue, servingsValue > 0 {
                        TimeInfoView(
                            icon: servingsIcon,
                            label: servingsLabel,
                            value: servingsValue
                        )
                    } else if let yield = detail.recipeYield, !yield.isEmpty {
                        TimeInfoView(
                            icon: "person.2",
                            label: "Portions",
                            value: yield
                        )
                    } else {
                        TimeInfoView(
                            icon: "person",
                            label: "Portion",
                            value: (nil as String?)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your rating")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    let ratingBinding = Binding<Double>(
                        get: { viewModel.recipeDetail?.userRating ?? 0.0 },
                        set: { newRating in
                            Task {
                                await viewModel.setRating(newRating, slug: recipeSummary.slug, apiClient: appState.apiClient, userID: appState.currentUserID)
                            }
                        }
                    )
                    StarRatingView(rating: ratingBinding)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if let globalRating = detail.rating, globalRating > 0, globalRating != viewModel.recipeDetail?.userRating {
                    HStack(spacing: 4) {
                        Text("Overall rating:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Label(String(format: "%.1f", globalRating), systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal)
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
    let text: String
    let icon: String

    init(icon: String = "clock", label: String, value: String?) {
        self.label = label
        self.text = value ?? "N/A"
        self.icon = icon
    }

    init(icon: String, label: String, value: Double?) {
        self.label = label
        self.icon = icon
        
        if let numValue = value, numValue > 0 {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 1
            self.text = formatter.string(from: NSNumber(value: numValue)) ?? "N/A"
        } else {
            self.text = "N/A"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .fontWeight(.medium)
                .lineLimit(1)
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

