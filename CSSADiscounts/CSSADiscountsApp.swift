//
//  CSSADiscountsApp.swift
//

import SwiftUI

@main
struct CSSADiscountsApp: App {
    @StateObject private var store = MerchantStore()
    @StateObject private var location = LocationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(location)
        }
    }
}
