import SwiftUI
import MapKit
import CoreLocation

// MARK: - Search Autocomplete

final class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    private let completer: MKLocalSearchCompleter
    @Published var results: [MKLocalSearchCompletion] = []

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String, region: MKCoordinateRegion?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            results = []
            completer.queryFragment = ""
            return
        }

        if let region { completer.region = region }
        completer.queryFragment = trimmed
    }

    func clear() {
        results = []
        completer.queryFragment = ""
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(8))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

// MARK: - Map Screen

struct MapScreen: View {
    @EnvironmentObject private var store: MerchantStore
    @EnvironmentObject private var location: LocationManager

    private enum Persist {
        static let hasRegionKey = "map_has_region"
        static let latKey = "map_center_lat"
        static let lonKey = "map_center_lon"
        static let spanLatKey = "map_span_lat"
        static let spanLonKey = "map_span_lon"

        static func loadRegion() -> MKCoordinateRegion? {
            let d = UserDefaults.standard
            guard d.bool(forKey: hasRegionKey) else { return nil }

            let lat = d.double(forKey: latKey)
            let lon = d.double(forKey: lonKey)
            let spanLat = d.double(forKey: spanLatKey)
            let spanLon = d.double(forKey: spanLonKey)

            guard (-90...90).contains(lat),
                  (-180...180).contains(lon),
                  spanLat > 0,
                  spanLon > 0 else { return nil }

            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            )
        }

        static func saveRegion(_ region: MKCoordinateRegion) {
            let d = UserDefaults.standard
            d.set(true, forKey: hasRegionKey)
            d.set(region.center.latitude, forKey: latKey)
            d.set(region.center.longitude, forKey: lonKey)
            d.set(region.span.latitudeDelta, forKey: spanLatKey)
            d.set(region.span.longitudeDelta, forKey: spanLonKey)
        }
    }

    @State private var cameraPosition: MapCameraPosition
    @State private var lastCenter: CLLocationCoordinate2D

    @State private var searchAddress = ""
    @State private var radiusKm: Double = 3
    @State private var navSheet: Merchant?

    // show searched address/POI pin
    @State private var searchedCoordinate: CLLocationCoordinate2D? = nil
    @State private var searchedLabel: String? = nil

    @State private var hasCenteredOnUser = false

    @StateObject private var searchCompleter = SearchCompleter()
    @FocusState private var searchFocused: Bool

    init() {
        if let saved = Persist.loadRegion() {
            _cameraPosition = State(initialValue: .region(saved))
            _lastCenter = State(initialValue: saved.center)
        } else {
            let montreal = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 45.5019, longitude: -73.5674),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            _cameraPosition = State(initialValue: .region(montreal))
            _lastCenter = State(initialValue: montreal.center)
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Search + Suggestions
            VStack(spacing: 8) {
                HStack {
                    TextField("Enter address or postal code", text: $searchAddress)
                        .textFieldStyle(.roundedBorder)
                        .focused($searchFocused)
                        .onSubmit { geocodeAndCenter() }
                        .onChange(of: searchAddress) { newValue in
                            let biasRegion = MKCoordinateRegion(
                                center: lastCenter,
                                span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
                            )
                            searchCompleter.update(query: newValue, region: biasRegion)
                        }

                    Button("Go") { geocodeAndCenter() }
                        .buttonStyle(.borderedProminent)
                }

                if searchFocused && !searchCompleter.results.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(searchCompleter.results, id: \.self) { item in
                            Button { selectCompletion(item) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary)
                    )
                    .frame(maxHeight: 260)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .zIndex(2)

            // Radius
            HStack {
                Text("Radius: \(Int(radiusKm)) km")
                Slider(value: $radiusKm, in: 1...50, step: 1)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .zIndex(1)

            Map(position: $cameraPosition) {
                // Blue dot (user)
                UserAnnotation()

                // Pin for searched address/postal code/POI
                if let searchedCoordinate {
                    Annotation(searchedLabel ?? "Searched location", coordinate: searchedCoordinate) {
                        VStack(spacing: 0) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                            if let searchedLabel {
                                Text(searchedLabel)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                // Merchants with category-based icons
                ForEach(filteredMerchants(), id: \.id) { m in
                    if let c = m.coordinate {
                        let style = markerStyle(for: m)
                        Annotation(m.name, coordinate: c) {
                            Button { navSheet = m } label: {
                                Image(systemName: style.symbol)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(7)
                                    .background(style.color, in: Circle())
                                    .shadow(radius: 1)
                            }
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange { ctx in
                lastCenter = ctx.region.center
                Persist.saveRegion(ctx.region)
            }

            // Filter menu (left)
            .overlay(alignment: .topLeading) {
                Menu {
                    Picker("Category", selection: $store.selectedCategory) {
                        Text("All").tag(MerchantCategory?.none)
                        ForEach(MerchantCategory.browseOrder, id: \.self) { cat in
                            Text(cat.rawValue).tag(MerchantCategory?.some(cat))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.top, 10)
                .padding(.leading, 10)
            }

            .sheet(item: $navSheet) { m in
                MerchantDetailView(merchant: m)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                if location.authorizationStatus == .notDetermined {
                    location.requestWhenInUseAuthorization()
                }
                if !hasCenteredOnUser, let c = location.location?.coordinate {
                    centerMap(on: c, animated: false)
                }
            }
            .onChange(of: location.location) { newLoc in
                guard !hasCenteredOnUser, let c = newLoc?.coordinate else { return }
                centerMap(on: c, animated: true)
            }
            .onTapGesture {
                searchFocused = false
                searchCompleter.clear()
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private struct MarkerStyle {
        let symbol: String
        let color: Color
    }

    private func markerStyle(for merchant: Merchant) -> MarkerStyle {
        // Pick a primary category in a predictable order
        let primary: MerchantCategory? =
            merchant.categories.contains(.specials) ? .specials :
            merchant.categories.contains(.restaurants) ? .restaurants :
            merchant.categories.contains(.desserts) ? .desserts :
            merchant.categories.contains(.entertainment) ? .entertainment :
            merchant.categories.contains(.shopping) ? .shopping :
            merchant.categories.first

        switch primary {
        case .specials:
            return MarkerStyle(symbol: "tag.fill", color: .purple)
        case .restaurants:
            return MarkerStyle(symbol: "fork.knife", color: .red)
        case .desserts:
            return MarkerStyle(symbol: "cup.and.saucer.fill", color: .orange)
        case .entertainment:
            return MarkerStyle(symbol: "ticket.fill", color: .green)
        case .shopping:
            return MarkerStyle(symbol: "bag.fill", color: .blue)
        case .none:
            return MarkerStyle(symbol: "mappin", color: .gray)
        }
    }

    private func filteredMerchants() -> [Merchant] {
        let centerLoc = CLLocation(latitude: lastCenter.latitude, longitude: lastCenter.longitude)

        return store.merchants.filter { m in
            guard let c = m.coordinate else { return false }
            if let cat = store.selectedCategory, !m.categories.contains(cat) { return false }

            let mLoc = CLLocation(latitude: c.latitude, longitude: c.longitude)
            return centerLoc.distance(from: mLoc) <= radiusKm * 1_000
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D, animated: Bool) {
        hasCenteredOnUser = true
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        lastCenter = region.center
        Persist.saveRegion(region)

        if animated {
            withAnimation { cameraPosition = .region(region) }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        if completion.subtitle.isEmpty {
            searchAddress = completion.title
        } else {
            searchAddress = "\(completion.title), \(completion.subtitle)"
        }

        searchFocused = false
        searchCompleter.clear()

        let request = MKLocalSearch.Request(completion: completion)
        request.region = MKCoordinateRegion(
            center: lastCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )

        MKLocalSearch(request: request).start { resp, _ in
            if let item = resp?.mapItems.first {
                let c = item.placemark.coordinate
                let region = MKCoordinateRegion(
                    center: c,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )

                searchedCoordinate = c
                if let name = item.name, !name.isEmpty {
                    searchedLabel = name
                } else {
                    searchedLabel = searchAddress
                }

                lastCenter = region.center
                Persist.saveRegion(region)
                withAnimation { cameraPosition = .region(region) }
            }
        }
    }

    private func geocodeAndCenter() {
        let trimmed = searchAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if searchFocused, let first = searchCompleter.results.first {
            selectCompletion(first)
            return
        }

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = trimmed
        req.region = MKCoordinateRegion(
            center: lastCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )

        MKLocalSearch(request: req).start { resp, _ in
            if let item = resp?.mapItems.first {
                let c = item.placemark.coordinate
                let region = MKCoordinateRegion(
                    center: c,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )

                searchedCoordinate = c
                if let name = item.name, !name.isEmpty {
                    searchedLabel = name
                } else {
                    searchedLabel = trimmed
                }

                lastCenter = region.center
                Persist.saveRegion(region)
                withAnimation { cameraPosition = .region(region) }
            }
        }

        searchFocused = false
        searchCompleter.clear()
    }
}
