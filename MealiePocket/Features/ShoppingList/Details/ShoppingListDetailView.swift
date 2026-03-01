import SwiftUI

struct ShoppingListDetailView: View {
    @State private var viewModel: ShoppingListDetailViewModel
    @Environment(AppState.self) private var appState
    @State private var localEditMode: EditMode = .inactive
    @State private var showingRemoveCheckedConfirmation = false
    @State private var showingSyncFailureBanner = false
    @State private var syncFailureMessage = ""
    
    init(listSummary: ShoppingListSummary) {
        _viewModel = State(initialValue: ShoppingListDetailViewModel(listSummary: listSummary))
    }
    
    private var hasCheckedItems: Bool {
        viewModel.shoppingListDetail?.listItems.contains { $0.checked } ?? false
    }
    
    var body: some View {
        List {
            Section {
                if viewModel.isLoadingImport {
                    ProgressView("Importing...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
            }
            
            if viewModel.isLoading && viewModel.shoppingListDetail?.listItems.isEmpty ?? true {
                ProgressView().frame(maxWidth: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                Section {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
            
            if let detail = viewModel.shoppingListDetail {
                if detail.listItems.isEmpty && !viewModel.isLoading && !viewModel.isLoadingImport {
                    Section("Items") {
                        Text("No items in this list yet.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    let groups = viewModel.groupedItems
                    ForEach(groups) { group in
                        Section(groups.count > 1 ? group.title : "Items") {
                            ForEach(group.items) { item in
                                ShoppingListItemRow(item: item, viewModel: viewModel)
                            }
                            .onDelete { indexSet in
                                let itemIds = indexSet.map { group.items[$0].id }
                                Task {
                                    guard let allItems = viewModel.shoppingListDetail?.listItems else { return }
                                    let globalOffsets = IndexSet(itemIds.compactMap { id in
                                        allItems.firstIndex(where: { $0.id == id })
                                    })
                                    await viewModel.deleteItems(at: globalOffsets)
                                }
                            }
                        }
                    }
                }

                Section("Recipes") {
                    if (detail.recipeReferences?.isEmpty ?? true) && !viewModel.isLoading && !viewModel.isLoadingImport {
                        Text("No recipes in this list yet.")
                            .foregroundColor(.secondary)
                    } else {
                        
                        if let references = detail.recipeReferences, !references.isEmpty {
                            ForEach(references) { ref in
                                if let recipeName = viewModel.recipeNameMap[ref.recipeId] {
                                    HStack(spacing: 3) {
                                        Image(systemName: "book.closed")
                                        Text(recipeName)
                                            .lineLimit(1)
                                    }
                                }
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
                    Button {
                        localEditMode = .inactive
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                } else {
                    Button {
                        localEditMode = .active
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(ShoppingListSortOption.allCases) { option in
                        Button {
                            viewModel.selectSortOption(option)
                        } label: {
                            if viewModel.sortOption == option {
                                Label(
                                    option.rawValue,
                                    systemImage: viewModel.sortAscending ? "chevron.up" : "chevron.down"
                                )
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task { await viewModel.importCurrentWeekIngredients() }
                    } label: {
                        Label("Import Current Week", systemImage: "calendar.badge.plus")
                    }
                    .disabled(viewModel.isLoadingImport || viewModel.isLoading)
                    
                    Button {
                        Task { await viewModel.importNextWeekIngredients() }
                    } label: {
                        Label("Import Next Week", systemImage: "calendar.badge.plus")
                    }
                    .disabled(viewModel.isLoadingImport || viewModel.isLoading)
                    
                    Button {
                        viewModel.showingDateRangePicker = true
                    } label: {
                        Label("Import Date Range", systemImage: "calendar")
                    }
                    .disabled(viewModel.isLoadingImport || viewModel.isLoading)

                    Divider()

                    Button(role: .destructive) {
                        showingRemoveCheckedConfirmation = true
                    } label: {
                        Label("Remove Checked Items", systemImage: "trash")
                    }
                    .disabled(!hasCheckedItems || viewModel.isLoadingImport || viewModel.isLoading || viewModel.isLoadingBulkUpdate)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .environment(\.editMode, $localEditMode)
        .sheet(isPresented: $viewModel.showingAddItemSheet) {
            AddShoppingItemView(viewModel: viewModel)
                .presentationDetents([.height(620), .large])
        }
        .sheet(isPresented: $viewModel.showingEditItemSheet) {
            EditShoppingItemView(viewModel: viewModel)
                .presentationDetents([.height(620), .large])
        }
        .sheet(isPresented: $viewModel.showingDateRangePicker) {
            DateRangePickerView(viewModel: viewModel)
                .presentationDetents([.height(250)])
        }
        .task {
            await viewModel.loadListDetails(apiClient: appState.apiClient)
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard let newValue, newValue.contains("Failed to update item") else { return }
            syncFailureMessage = newValue
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSyncFailureBanner = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingSyncFailureBanner = false
                }
            }
        }
        .alert("Remove checked items?", isPresented: $showingRemoveCheckedConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeCheckedItems() }
            }
        } message: {
            Text("This removes all checked items from this list.")
        }
        .overlay(alignment: .top) {
            if showingSyncFailureBanner {
                Text(syncFailureMessage)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(.red)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                Button {
                    viewModel.prepareAddItemSheet(addMultiple: true)
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.title3.weight(.semibold))
                        .padding(12)
                        .foregroundStyle(Color.white)
                        .glassEffect(.regular.tint(.blue).interactive())
                        .clipShape(Circle())
                }

                Button {
                    viewModel.prepareAddItemSheet(addMultiple: false)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .padding()
                        .foregroundStyle(Color.white)
                        .glassEffect(.regular.tint(.accentColor).interactive())
                        .clipShape(Circle())
                }
            }
            .disabled(viewModel.isLoading || viewModel.isLoadingImport)
            .padding(.trailing, 20)
            .padding(.bottom, 10)
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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: isCheckedLocal ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCheckedLocal ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.resolvedDisplayName)
                    .strikethrough(isCheckedLocal, color: .secondary)
                    .foregroundColor(isCheckedLocal ? .secondary : .primary)

                if let references = item.recipeReferences, !references.isEmpty {
                    ForEach(references) { ref in
                        if let recipeName = viewModel.recipeNameMap[ref.recipeId] {
                            HStack(spacing: 3) {
                                Image(systemName: "book.closed")
                                Text(recipeName)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                viewModel.prepareEditItemSheet(item: item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
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
}
