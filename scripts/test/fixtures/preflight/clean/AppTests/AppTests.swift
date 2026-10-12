import CoreLocation
import XCTest

// Test-target code: none of this needs a purpose string or routes a branch.
final class AppTests: XCTestCase {
    func testLocation() {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        _ = WKWebViewStandIn()
    }
}
struct WKWebViewStandIn {}
