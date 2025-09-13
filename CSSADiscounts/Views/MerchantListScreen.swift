import SwiftUI

// MARK: - Browse (List) Screen with swipeable category chips

struct MerchantListScreen: View {
    @EnvironmentObject private var store: MerchantStore
    @State private var searchText: String = ""

    // Build the chip row: first is "All" (nil), then real categories
    private var chipItems: [CategoryItem] {
        var items: [CategoryItem] = [.init(title: "All", icon: "square.grid.2x2", category: nil)]
        items += MerchantCategory.allCases.map { cat in
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
            List(filteredMerchants) { m in
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

// MARK: - Filtering

private extension MerchantListScreen {
    var filteredMerchants: [Merchant] {
        let needle = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return store.merchants.filter { m in
            // Category filter
            if let cat = store.selectedCategory, m.category != cat { return false }

            // Text filter (name + address)
            if !needle.isEmpty {
                // address is non-optional in your model
                let haystack = (m.name + " " + m.address).lowercased()
                if !haystack.contains(needle) { return false }
            }
            return true
        }
    }

    func chipTitle(for cat: MerchantCategory) -> String {
        switch cat {
        case .restaurants:   return "Restaurants"
        case .desserts:      return "Desserts"
        case .entertainment: return "Life & Entertainment"  // FIX: full title
        case .shopping:      return "Shopping"
        case .specials:      return "Specials"
        }
    }

    func chipIcon(for cat: MerchantCategory) -> String {
        switch cat {
        case .restaurants:   return "fork.knife"
        case .desserts:      return "cup.and.saucer"
        case .entertainment: return "sparkles"
        case .shopping:      return "bag"
        case .specials:      return "percent"
        }
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
            // toggle to nil when tapping the same chip (like Uber’s “All”)
            if selection == item.category {
                selection = nil
            } else {
                selection = item.category
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .imageScale(.medium)
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false) // prevents truncation
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

// MARK: - Minimal in-file row (fixes "Cannot find MerchantRow in scope")

private struct MerchantRow: View {
    let merchant: Merchant

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(merchant.name)
                .font(.headline)
                .foregroundStyle(.blue)

            HStack(spacing: 6) {
                Text(merchant.subtitle ?? merchant.category.rawValue)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(merchant.category.rawValue)
                    .foregroundStyle(.secondary)
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
