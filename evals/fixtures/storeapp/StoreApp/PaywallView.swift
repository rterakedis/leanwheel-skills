import StoreKit
import SwiftUI

/// Sells Pro. The yearly product is declared here but missing from StoreApp.storekit —
/// the PRODUCTS DIFF eval expects that mismatch to be reported.
struct PaywallView: View {
    static let productIDs = [
        "com.example.storeapp.pro.monthly",
        "com.example.storeapp.pro.yearly",
    ]
    @State private var products: [Product] = []

    var body: some View {
        List(products) { product in
            Text("\(product.displayName) — \(product.displayPrice)")
        }
        .task { products = (try? await Product.products(for: Self.productIDs)) ?? [] }
    }
}
