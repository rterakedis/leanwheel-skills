import CoreLocation
import SwiftUI

struct MapScreen: View {
    let manager = CLLocationManager()
    @AppStorage("units") private var units = "km"
    var body: some View { Text("Map") }
}
