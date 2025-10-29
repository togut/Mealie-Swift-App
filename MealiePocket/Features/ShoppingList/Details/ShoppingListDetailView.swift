import SwiftUI

struct ShoppingListDetailView: View {
    @State private var viewModel: ShoppingListDetailViewModel
    @Environment(AppState.self) private var appState
    @State private var localEditMode: EditMode = .inactive
    @Namespace var buttonNamespace
    
    init(listSummary: ShoppingListSummary) {
        _viewModel = State(initialValue: ShoppingListDetailViewModel(listSummary: listSummary))
    }
    
    private var hasUncheckedItems: Bool {
        viewModel.shoppingListDetail?.listItems.contains { !$0.checked } ?? false
    }
    
    private var hasCheckedItems: Bool {
        viewModel.shoppingListDetail?.listItems.contains { $0.checked } ?? false
    }
    
    var body: some View {
        List {
            if viewModel.isLoading && viewModel.shoppingListDetail?.listItems.isEmpty ?? true {
                ProgressView().frame(maxWidth: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                Section {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
            
            if let detail = viewModel.shoppingListDetail {
                Section("Items") {
                    if detail.listItems.isEmpty && !viewModel.isLoading {
                        Text("No items in this list yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(detail.listItems) { item in
                            ShoppingListItemRow(item: item, viewModel: viewModel)
                        }
                        .onDelete { indexSet in
                            Task {
                                await viewModel.deleteItems(at: indexSet)
                            }
                        }
                    }
                }
            } else if !viewModel.isLoading {
                Text("Could not load list details.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(viewModel.shoppingListDetail?.name ?? "Shopping List")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if localEditMode.isEditing {
                    Button("Done") {
                        localEditMode = .inactive
                    }
                } else {
                    Button("Edit") {
                        localEditMode = .active
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.prepareAddItemSheet()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .environment(\.editMode, $localEditMode)
        .sheet(isPresented: $viewModel.showingAddItemSheet) {
            AddShoppingItemView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadListDetails(apiClient: appState.apiClient)
        }
    }
}

struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    let viewModel: ShoppingListDetailViewModel
    @Environment(\.editMode) private var editMode
    @State private var isCheckedLocal: Bool

    init(item: ShoppingListItem, viewModel: ShoppingListDetailViewModel) {
        self.item = item
        self.viewModel = viewModel
        _isCheckedLocal = State(initialValue: item.checked)
    }

    var body: some View {
        HStack {
            Image(systemName: isCheckedLocal ? "checkmark.circle.fill" : "circle")
                 .foregroundColor(isCheckedLocal ? .green : .secondary)
                 .font(.title3)

            VStack(alignment: .leading){
                Text(item.note ?? item.display ?? "Unknown Item")
                     .strikethrough(isCheckedLocal, color: .secondary)
                     .foregroundColor(isCheckedLocal ? .secondary : .primary)
                 if let qty = item.quantity, qty != 1 {
                      Text("Qty: \(formattedQuantity(qty))")
                           .font(.caption)
                           .foregroundColor(.secondary)
                 }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isCheckedLocal.toggle()
            hapticImpact()
            viewModel.updateItemCheckedState(itemId: item.id, isChecked: isCheckedLocal)
        }
        .opacity(editMode?.wrappedValue.isEditing == true ? 0.5 : 1.0)
        .onChange(of: item.checked) { _, newValue in
             if isCheckedLocal != newValue {
                 isCheckedLocal = newValue
             }
        }
    }

     private func formattedQuantity(_ quantity: Double) -> String {
         let formatter = NumberFormatter()
         formatter.minimumFractionDigits = 0
         formatter.maximumFractionDigits = 2
         return formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
     }
}

struct AddShoppingItemView: View {
    @Bindable var viewModel: ShoppingListDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("New Item") {
                    TextField("Name or Note", text: $viewModel.newItemNote)
                    Stepper("Quantity: \(formattedQuantity(viewModel.newItemQuantity))", value: $viewModel.newItemQuantity, in: 0.1...100, step: 0.1)
                }
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        viewModel.resetNewItemFields()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task {
                                await viewModel.addItem()
                            }
                        }
                        .disabled(viewModel.newItemNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
    
    private func formattedQuantity(_ quantity: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
    }
}
