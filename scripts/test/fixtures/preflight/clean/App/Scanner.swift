import AVFoundation
import SwiftUI

// Every API here has its key and its manifest entry. A comment naming UIWebView or
// CLLocationManager must not count as a use.
struct ScannerView: View {
    let session = AVCaptureSession()
    @AppStorage("seenIntro") private var seenIntro = false

    var body: some View {
        Button("Scan") { seenIntro = true }
            .onAppear { UserDefaults.standard.set(true, forKey: "opened") }
    }
}

#if DEBUG
struct DebugTools {
    func dump(token: String) { print("auth token: \(token)") }
    func motionEnded() {}
}
#endif
