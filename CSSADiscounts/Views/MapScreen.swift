import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @EnvironmentObject private var store: MerchantStore
    @EnvironmentObject private var location: LocationManager

    // Default: Montréal (switch to real location on appear)
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.5019, longitude: -73.5674),
            span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10)
        )
    )
    @State private var lastCenter = CLLocationCoordinate2D(latitude: 45.5019, longitude: -73.5674)

    @State private var searchAddress: String = ""
    @State private var radiusKm: Double = 3.0
    @State private var navSheet: Merchant?

    var body: some View {
        VStack(spacing: 0) {

            // Search row
            HStack(spacing: 8) {
                TextField("Enter address or postal code", text: $searchAddress)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { geocodeAndCenter() }

                Button("Go") { geocodeAndCenter() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.top, 12) // small breathing room under the inline nav bar

            // Radius row
            HStack {
                Text("Radius: \(Int(radiusKm)) km")
                Slider(value: $radiusKm, in: 1...50, step: 1)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Map with floating filter button
            Map(position: $cameraPosition) {
                ForEach(filteredMerchants(), id: \.id) { m in
                    if let c = m.coordinate {
                        Annotation(m.name, coordinate: c) {
                            Button { navSheet = m } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel(Text(m.name))
                        }
                    }
                }
            }
            .onMapCameraChange { ctx in
                lastCenter = ctx.region.center
            }
            .overlay(alignment: .topTrailing) {
                // Floating filter menu (icon only) on top of the map
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
                .padding(.trailing, 10)
            }
            .sheet(item: $navSheet) { m in
                MerchantDetailView(merchant: m)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                if let c = location.location?.coordinate {
                    lastCenter = c
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: c,
                            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                        )
                    )
                }
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)   // <- removes the giant whitespace
    }

    // MARK: - Helpers

    /// Show merchants that (a) have coordinates, (b) match the selected category (if any),
    /// and (c) are within `radiusKm` of the current map center.
    private func filteredMerchants() -> [Merchant] {
        let centerLoc = CLLocation(latitude: lastCenter.latitude, longitude: lastCenter.longitude)

        return store.merchants.filter { m in
            // Must have a coordinate to place a pin
            guard let c = m.coordinate else { return false }

            // Category filter for multi-category model
            if let cat = store.selectedCategory, !m.categories.contains(cat) {
                return false
            }

            // Distance filter
            let mLoc = CLLocation(latitude: c.latitude, longitude: c.longitude)
            return centerLoc.distance(from: mLoc) <= radiusKm * 1_000.0
        }
    }

    private func geocodeAndCenter() {
        guard !searchAddress.isEmpty else { return }

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchAddress
        req.region = MKCoordinateRegion(
            center: lastCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.20, longitudeDelta: 0.20)
        )

        MKLocalSearch(request: req).start { resp, _ in
            if let item = resp?.mapItems.first {
                let region = MKCoordinateRegion(
                    center: item.placemark.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
                lastCenter = region.center
                withAnimation { cameraPosition = .region(region) }
            }
        }
    }
}
