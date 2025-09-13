import SwiftUI

// MARK: - Browse (List) Screen with swipeable category chips

struct MerchantListScreen: View {
    @EnvironmentObject private var store: MerchantStore
    @State private var searchText: String = ""

    // Build the chip row: first is "All" (nil), then real categories
    private var chipItems: [CategoryItem] {
        var items: [CategoryItem] = [
            .init(title: "All", icon: "square.grid.2x2", category: nil)
        ]
        items += MerchantCategory.browseOrder.map { cat in
            .init(title: chipTitle(for: cat), icon: chipIcon(for: cat), category: cat)
        }
        return items
    }

    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { store.searchText = searchText }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            // Uber-style horizontally scrollable category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(chipItems) { item in
                        CategoryChip(item: item, selection: $store.selectedCategory)
                    }
                }
                .padding(.horizontal)
            }

            // Results list
            List(store.filteredMerchants()) { m in
                NavigationLink(destination: MerchantDetailView(merchant: m)) {
                    MerchantRow(merchant: m)
                }
            }
            .listStyle(.plain)
            .animation(.snappy, value: store.selectedCategory?.id)
            .animation(.snappy, value: store.searchText)
        }
        .navigationTitle("Browse")
        .onAppear { searchText = store.searchText }
    }
}

// MARK: - Chip model + view

private struct CategoryItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let category: MerchantCategory?
}

private struct CategoryChip: View {
    let item: CategoryItem
    @Binding var selection: MerchantCategory?

    var isSelected: Bool { selection == item.category }

    var body: some View {
        Button {
            selection = (selection == item.category) ? nil : item.category
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .imageScale(.medium)
                Text(item.title)
                    .font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.accentColor.opacity(0.18))
                    } else {
                        Capsule().fill(Color(.secondarySystemBackground))
                    }
                }
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor : Color(.separator), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .contentShape(Capsule())
    }
}

// MARK: - Minimal in-file row

private struct MerchantRow: View {
    let merchant: Merchant

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(merchant.name)
                .font(.headline)
                .foregroundStyle(.blue)

            // “Category • Subtitle” line
            HStack(spacing: 6) {
                Text(merchant.categories.first?.rawValue ?? "—")
                    .foregroundStyle(.secondary)
                if let sub = merchant.subtitle, !sub.isEmpty {
                    Text("·").foregroundStyle(.tertiary)
                    Text(sub).foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            if let discount = merchant.discountText, !discount.isEmpty {
                Text(discount)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(merchant.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Helpers (titles/icons)

private func chipTitle(for cat: MerchantCategory) -> String {
    switch cat {
    case .restaurants:   return "Restaurants"
    case .desserts:      return "Desserts"
    case .entertainment: return "Life…"
    case .shopping:      return "Shopping"
    case .specials:      return "Specials"
    }
}

private func chipIcon(for cat: MerchantCategory) -> String {
    switch cat {
    case .restaurants:   return "fork.knife"
    case .desserts:      return "cup.and.saucer"
    case .entertainment: return "sparkles"
    case .shopping:      return "bag"
    case .specials:      return "percent"
    }
}
