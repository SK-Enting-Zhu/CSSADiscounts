//
//  RootView.swift
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MerchantStore
    @EnvironmentObject private var location: LocationManager

    var body: some View {
        TabView {
            NavigationStack {
                MapScreen()
            }
            .tabItem { Label("Map", systemImage: "map") }

            NavigationStack {
                MerchantListScreen()
            }
            .tabItem { Label("Browse", systemImage: "list.bullet") }

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CSSA Discounts")
                            .font(.title.bold())

                        Text("""
Find nearby merchants that offer McGill CSSA member discounts. Browse by category or explore the map, then get directions in Apple Maps or Google Maps.
""")

                        Text("Disclaimer")
                            .font(.headline)

                        Text("""
Data is community-maintained and may change. Always verify discount details with the merchant.
""")
                    }
                    .padding()
                }
            }
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        // Load data & request location once when the tab view appears
        .task {
            await store.loadMerchants()                 // <- now this exists
            location.requestWhenInUseAuthorization()
        }
    }
}
