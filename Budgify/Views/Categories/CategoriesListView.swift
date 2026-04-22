import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(\.modelContext) private var context
    @Environment(CategoryViewModel.self) private var categoryVM
    @Query private var categories: [Category]
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(categories) { cat in
                HStack {
                    Text(cat.icon)
                    Text(cat.name)
                    Spacer()
                    Circle()
                        .fill(Color(hex: cat.colorHex))
                        .frame(width: 20, height: 20)
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { categoryVM.delete(category: categories[$0], context: context) }
            }
        }
        .navigationTitle("Catégories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddCategoryView()
        }
        .onAppear { categoryVM.categories = categories }
    }
}
