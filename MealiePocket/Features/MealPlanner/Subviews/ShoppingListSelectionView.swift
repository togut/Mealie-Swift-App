import SwiftUI

struct ShoppingListSelectionView: View {
    @Bindable var viewModel: MealPlannerViewModel
    var apiClient: MealieAPIClient?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoadingShoppingLists {
                    ProgressView("Loading Lists...")
                    Spacer()
                } else if let error = viewModel.importErrorMessage, !viewModel.isImporting {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    List(viewModel.availableShoppingLists) { list in
                        Button {
                            Task {
                                await viewModel.importMealsToShoppingList(list: list)
                            }
                        } label: {
                            HStack {
                                Text(list.name ?? "Untitled List")
                                Spacer()
                                if viewModel.isImporting && viewModel.importingListId == list.id {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(viewModel.isImporting)
                        .foregroundColor(.primary)
                    }
                    .task {
                        if viewModel.availableShoppingLists.isEmpty {
                            await viewModel.loadShoppingLists()
                        }
                    }
                }
            }
            .navigationTitle("Select List to Import To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Import Successful", isPresented: $viewModel.importSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            }
        }
    }
}
