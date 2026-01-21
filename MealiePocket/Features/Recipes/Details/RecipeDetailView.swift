import SwiftUI

struct RecipeDetailView: View {
    let recipeSummary: RecipeSummary
    
    @State private var viewModel: RecipeDetailViewModel
    @Environment(AppState.self) private var appState
    
    init(recipeSummary: RecipeSummary) {
        self.recipeSummary = recipeSummary
        _viewModel = State(initialValue: RecipeDetailViewModel(recipeSummary: recipeSummary))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable().scaledToFit().frame(width: 50, height: 50).foregroundColor(.orange)
                        Text("Error").font(.title2).fontWeight(.bold)
                        Text(errorMessage).font(.callout).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 50)
                }
            }
            .padding(.vertical)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    viewModel.showingAddToPlanSheet = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
                .disabled(viewModel.recipeDetail == nil)
                
                Button {
                    hapticImpact(style: .light)
                    Task {
                        await viewModel.toggleFavorite(apiClient: appState.apiClient, userID: appState.currentUserID)
                    }
                } label: {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isFavorite ? .red : .primary)
                }
                .disabled(viewModel.recipeDetail == nil)
                
                NavigationLink {
                    if let detail = viewModel.recipeDetail {
                        EditRecipeView(
                            viewModel: EditRecipeViewModel(recipe: detail),
                            detailViewModel: viewModel,
                            apiClient: appState.apiClient
                        )
                    }
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(viewModel.recipeDetail == nil)
            }
        }
        .sheet(isPresented: $viewModel.showingAddToPlanSheet) {
            if let client = appState.apiClient {
                AddToMealPlanView(viewModel: viewModel, apiClient: client)
            }
        }
        .task {
            if viewModel.recipeDetail == nil || viewModel.needsRefresh {
                await viewModel.loadRecipeDetail(slug: recipeSummary.slug, apiClient: appState.apiClient, userID: appState.currentUserID)
            }
        }
    }

    private func headerView(detail: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.recipeDetail?.name ?? recipeSummary.name)
                .font(.title.bold())
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
                        TimeInfoView(icon: "frying.pan", label: "Cooking", value: detail.performTime)
                    }
                    .lineLimit(1)
                    
                    let servingsValue: Double? = detail.recipeServings
                    let isSingular: Bool = servingsValue == 1.0

                    let servingsLabel: LocalizedStringKey = isSingular ? "Portion" : "Portions"
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
            
            VStack(alignment: .leading, spacing: 10) {
                if let description = detail.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(description)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

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
            Text("Ingredients").font(.title2.weight(.semibold)).padding(.horizontal)
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(ingredients) { ingredient in
                    IngredientRow(text: ingredient.display)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func instructionsSection(instructions: [RecipeInstruction]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Instructions").font(.title2.weight(.semibold)).padding(.horizontal)
            LazyVStack(alignment: .leading, spacing: 15) {
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
    let label: LocalizedStringKey
    let text: String
    let icon: String
    
    init(icon: String = "clock", label: LocalizedStringKey, value: String?) {
        self.label = label
        self.text = value ?? "N/A"
        self.icon = icon
    }
    
    init(icon: String, label: LocalizedStringKey, value: Double?) {
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
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .secondary)
                    .font(.title3)
                Text(text)
                    .strikethrough(isChecked, color: .secondary)
                    .foregroundColor(isChecked ? .secondary : .primary)
                    .font(.body)
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

struct AddToMealPlanView: View {
    @Bindable var viewModel: RecipeDetailViewModel
    var apiClient: MealieAPIClient?
    
    @State private var selectedDate = Date()
    @State private var selectedMealType = "Dinner"
    let mealTypes = ["Breakfast", "Lunch", "Dinner", "Side"]
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                
                Picker("Meal Type", selection: $selectedMealType) {
                    ForEach(mealTypes, id: \.self) { type in
                        Text(LocalizedStringKey(type)).tag(type)
                    }
                }
            }
            .navigationTitle("Add to Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            await viewModel.addToMealPlan(date: selectedDate, mealType: selectedMealType, apiClient: apiClient)
                        }
                    }
                    .disabled(viewModel.recipeDetail == nil)
                }
            }
        }
    }
}
