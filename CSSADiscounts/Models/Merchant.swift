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

extension MerchantCategory {
    static var browseOrder: [MerchantCategory] {
        return [.specials, .restaurants, .desserts, .entertainment, .shopping]
    }
}

// MARK: - Merchant model

/// We only need to *decode* from JSON, so this is `Decodable` (not `Codable`).
struct Merchant: Decodable, Identifiable {
    /// A stable computed ID so ForEach works without storing IDs in JSON
    var id: String { "\(name)|\(address)" }

    let name: String
    let subtitle: String?

    /// Multiple categories supported
    var categories: [MerchantCategory]

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

    // MARK: - Decoding that supports BOTH old "category" and new "categories"

    enum CodingKeys: String, CodingKey {
        case name, subtitle, discountText, address, phone, hours, payment, menuURL, images, latitude, longitude
        case category      // legacy single value
        case categories    // new array value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name         = try c.decode(String.self, forKey: .name)
        subtitle     = try c.decodeIfPresent(String.self, forKey: .subtitle)
        discountText = try c.decodeIfPresent(String.self, forKey: .discountText)
        address      = try c.decode(String.self, forKey: .address)
        phone        = try c.decodeIfPresent(String.self, forKey: .phone)
        hours        = try c.decodeIfPresent(String.self, forKey: .hours)
        payment      = try c.decodeIfPresent(String.self, forKey: .payment)
        menuURL      = try c.decodeIfPresent(String.self, forKey: .menuURL)
        images       = try c.decodeIfPresent([String].self, forKey: .images)
        latitude     = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude    = try c.decodeIfPresent(Double.self, forKey: .longitude)

        // Preferred: array
        if let cats = try c.decodeIfPresent([MerchantCategory].self, forKey: .categories) {
            categories = cats
        } else if let single = try c.decodeIfPresent(MerchantCategory.self, forKey: .category) {
            // Legacy: wrap single into array
            categories = [single]
        } else {
            categories = []
        }
    }

    // Convenience init for tests/manual creation (not used by decoder)
    init(
        name: String,
        subtitle: String? = nil,
        categories: [MerchantCategory],
        discountText: String? = nil,
        address: String,
        phone: String? = nil,
        hours: String? = nil,
        payment: String? = nil,
        menuURL: String? = nil,
        images: [String]? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.name = name
        self.subtitle = subtitle
        self.categories = categories
        self.discountText = discountText
        self.address = address
        self.phone = phone
        self.hours = hours
        self.payment = payment
        self.menuURL = menuURL
        self.images = images
        self.latitude = latitude
        self.longitude = longitude
    }

    // Helper for filtering
    func isInCategory(_ cat: MerchantCategory?) -> Bool {
        guard let cat else { return true } // "All"
        return categories.contains(cat)
    }
}

// MARK: - Store

@MainActor
final class MerchantStore: ObservableObject {
    @Published var merchants: [Merchant] = []

    // UI state
    @Published var selectedCategory: MerchantCategory? = nil
    @Published var searchText: String = ""

    /// Load merchants from merchants.json in the app bundle.
    func loadMerchants() async {
        do {
            guard let url = Bundle.main.url(forResource: "merchants", withExtension: "json") else {
                print("❌ merchants.json not found in bundle. Make sure Target Membership is checked.")
                return
            }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Merchant].self, from: data)
            self.merchants = decoded
            print("✅ Loaded \(decoded.count) merchants.")
        } catch {
            print("❌ Failed to load merchants.json: \(error)")
            self.merchants = []
        }
    }

    /// Simple in-memory filtering for the list screen
    func filteredMerchants() -> [Merchant] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return merchants.filter { m in
            guard m.isInCategory(selectedCategory) else { return false }
            if needle.isEmpty { return true }
            let haystack = (m.name + " " + m.address + " " + (m.subtitle ?? "")).lowercased()
            return haystack.contains(needle)
        }
    }
}
