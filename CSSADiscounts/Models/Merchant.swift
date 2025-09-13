import Foundation
import CoreLocation

// MARK: - Category

enum MerchantCategory: String, Codable, CaseIterable, Identifiable {
    case restaurants = "Restaurants"
    case desserts = "Desserts & Drinks"
    case entertainment = "Life & Entertainment"
    case shopping = "Shopping"
    case specials = "Special Offers"

    var id: String { rawValue }
}

// MARK: - Merchant model

struct Merchant: Codable, Identifiable {
    // Stable computed ID so ForEach works without storing IDs in JSON
    var id: String { "\(name)|\(address)" }

    let name: String
    let subtitle: String?
    let category: MerchantCategory
    let discountText: String?
    let address: String
    let phone: String?
    let hours: String?
    let payment: String?
    let menuURL: String?
    let images: [String]?
    let latitude: Double?
    let longitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Store

@MainActor
final class MerchantStore: ObservableObject {
    @Published var merchants: [Merchant] = []
    @Published var filteredMerchants: [Merchant] = []
    @Published var selectedCategory: MerchantCategory? = nil
    @Published var searchText: String = ""

    func loadMerchants() async {
        guard let url = Bundle.main.url(forResource: "merchants", withExtension: "json") else {
            print("ERROR: merchants.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Merchant].self, from: data)
            merchants = decoded
            filteredMerchants = decoded
        } catch {
            print("ERROR decoding merchants.json: \(error)")
        }
    }

    func applyFilters() {
        var list = merchants
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        filteredMerchants = list
    }
}
