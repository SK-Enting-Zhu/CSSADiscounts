import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @EnvironmentObject private var store: MerchantStore
    @EnvironmentObject private var location: LocationManager

    // Modern camera API; track our own center to avoid Swift 6 pattern-matching issues.
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.5017, longitude: -73.5673), // Montréal
            span: MKCoordinateSpan(latitudeDelta: 0.10, longitudeDelta: 0.10)
        )
    )
    @State private var lastCenter: CLLocationCoordinate2D =
        CLLocationCoordinate2D(latitude: 45.5017, longitude: -73.5673)

    @State private var searchAddress: String = ""
    @State private var radiusKm: Double = 3.0
    @State private var navSheet: Merchant?

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                TextField("Enter address or postal code", text: $searchAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit { geocodeAndCenter() }
                Button("Go") { geocodeAndCenter() }
                    .buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .top])

            // Radius
            HStack {
                Text("Radius: \(Int(radiusKm)) km")
                Slider(value: $radiusKm, in: 1...50, step: 1)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Map
            Map(position: $cameraPosition) {
                ForEach(filteredMerchants(), id: \.id) { m in
                    if let c = m.coordinate {
                        Annotation(m.name, coordinate: c) {
                            Button { navSheet = m } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel(Text(m.name)) // accessibility on Button
                        }
                    }
                }
            }
            .onMapCameraChange { ctx in
                // In iOS 18, ctx.region is NON-optional → don’t use if-let
                let region = ctx.region
                lastCenter = region.center
            }
            .edgesIgnoringSafeArea(.bottom)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Category", selection: $store.selectedCategory) {
                        Text("All").tag(MerchantCategory?.none)
                        ForEach(MerchantCategory.allCases) { cat in
                            Text(cat.rawValue).tag(MerchantCategory?.some(cat))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    // MARK: - Helpers

    private func filteredMerchants() -> [Merchant] {
        let centerLoc = CLLocation(latitude: lastCenter.latitude, longitude: lastCenter.longitude)
        return store.merchants.compactMap { m in
            guard let c = m.coordinate else { return nil }
            if let cat = store.selectedCategory, m.category != cat { return nil }
            let mLoc = CLLocation(latitude: c.latitude, longitude: c.longitude)
            let d = centerLoc.distance(from: mLoc)
            return d <= radiusKm * 1000.0 ? m : nil
        }
    }

    private func geocodeAndCenter() {
        guard !searchAddress.isEmpty else { return }

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchAddress
        let hintRegion = MKCoordinateRegion(
            center: lastCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.20, longitudeDelta: 0.20)
        )
        req.region = hintRegion

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
