import SwiftUI
import MapKit

struct MerchantDetailView: View, Identifiable {
    var id: String { merchant.id }
    let merchant: Merchant

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Images (optional URLs)
                if let imgs = merchant.images, !imgs.isEmpty {
                    TabView {
                        ForEach(imgs, id: \.self) { urlStr in
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(.gray.opacity(0.2))
                                }
                                .frame(height: 220).clipped().cornerRadius(12)
                            }
                        }
                    }
                    .frame(height: 220)
                    .tabViewStyle(.page)
                }

                Text(merchant.name).font(.title2.bold())
                if let sub = merchant.subtitle { Text(sub).foregroundStyle(.secondary) }
                if let discount = merchant.discountText { Label(discount, systemImage: "tag") }

                Group {
                    Label(merchant.address, systemImage: "mappin.and.ellipse")
                    if let hours = merchant.hours { Label(hours, systemImage: "clock") }
                    if let phone = merchant.phone {
                        let digits = phone.filter(\.isNumber)
                        if let telURL = URL(string: "tel://\(digits)") {
                            Link(destination: telURL) { Label(phone, systemImage: "phone") }
                        }
                    }
                    if let pay = merchant.payment { Label(pay, systemImage: "creditcard") }
                }
                .font(.subheadline)

                if let c = merchant.coordinate {
                    HStack {
                        Button { openInAppleMaps(coordinate: c, name: merchant.name) } label: {
                            Label("Apple Maps", systemImage: "map")
                        }
                        .buttonStyle(.borderedProminent)

                        Button { openInGoogleMaps(coordinate: c, name: merchant.name) } label: {
                            Label("Google Maps", systemImage: "globe")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let menu = merchant.menuURL, let url = URL(string: menu) {
                    NavigationLink(destination: WebView(url: url)) {
                        Label("View Menu", systemImage: "menucard")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Details")
    }

    // MARK: - Maps

    private func openInAppleMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func openInGoogleMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let scheme = "comgooglemaps://?q=\(encoded)&center=\(coordinate.latitude),\(coordinate.longitude)&zoom=14&directionsmode=driving"
        if let appURL = URL(string: scheme), UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let web = URL(string: "https://maps.google.com/?q=\(coordinate.latitude),\(coordinate.longitude)") {
            UIApplication.shared.open(web)
        }
    }
}
