import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(CategoryViewModel.self) private var categoryVM

    @State private var name = ""
    @State private var icon = "🍔"
    @State private var colorHex = "FF6B6B"

    private let icons = ["🍔", "🚗", "🏠", "✈️", "🎮", "👕", "💊", "📚", "🎵", "🏋️", "🐶", "💡"]
    private let colors = ["FF6B6B", "4ECDC4", "45B7D1", "96CEB4", "FFEAA7", "DDA0DD", "98D8C8", "F7DC6F"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Ex: Nourriture", text: $name)
                }
                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { i in
                            Text(i)
                                .font(.title2)
                                .padding(8)
                                .background(icon == i ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture { icon = i }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(colors, id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: colorHex == c ? 3 : 0)
                                )
                                .onTapGesture { colorHex = c }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Nouvelle catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter") { save() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        categoryVM.add(category: Category(name: name, colorHex: colorHex, icon: icon), context: context)
        dismiss()
    }
}
