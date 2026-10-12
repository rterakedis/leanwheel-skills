import AdSupport
import AVFoundation
import CoreData
import CoreLocation
import GoogleSignIn
import StoreKit
import SwiftUI
import WebKit

// One line per fault the scan must find; see scripts/test/preflight-scan.sh.
final class TripTracker {
    let manager = CLLocationManager()                      // no location key → BLOCKER
    let session = AVCaptureSession()                       // key present but "Camera" → MEDIUM
    let container = NSPersistentCloudKitContainer(name: "Trips")   // schema never initialised
    let legacy = UIWebView()                               // ITMS-90809
    let web = WKWebView()
    let idfa = ASIdentifierManager.shared().advertisingIdentifier
    let endpoint = URL(string: "https://api.openai.com/v1/responses")
    let config = RemoteConfig.remoteConfig()

    func start() {
        manager.requestWhenInUseAuthorization()
        UserDefaults.standard.set(true, forKey: "started")
        UIApplication.shared.registerForRemoteNotifications()
        GIDSignIn.sharedInstance.signIn(withPresenting: root)
        let handle = dlopen("/System/Library/PrivateFrameworks/X.framework/X", RTLD_NOW)
        print("session token: \(token)")
    }

    func signUp(email: String) async throws {}
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {}
}

struct ChatView: View {
    var body: some View { Text("Coming soon") }
}
