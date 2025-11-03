import SwiftUI

struct MealPlannerDateRangePickerView: View {
    @Bindable var viewModel: MealPlannerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Select dates to import") {
                    DatePicker("Start Date", selection: $viewModel.dateRangeStart, displayedComponents: .date)
                    DatePicker("End Date", selection: $viewModel.dateRangeEnd, in: viewModel.dateRangeStart..., displayedComponents: .date)
                }
            }
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        Task {
                            await viewModel.loadShoppingLists()
                            dismiss()
                            viewModel.showingShoppingListSelection = true
                        }
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}
