import Flutter
import AVFAudio
import UIKit
import PushKit
import CallKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Ask for standard remote-push permission so FCM can wake the app
    // (used for in-call signaling updates and chat notifications).
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let opts: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(options: opts) { _, _ in }
    }
    application.registerForRemoteNotifications()

    // Register for VoIP (PushKit) pushes — required so iOS will wake the
    // app and present CallKit even when killed. The actual push payload
    // is forwarded into flutter_callkit_incoming below.
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - PushKit (VoIP) — wake-up channel for incoming calls

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    // Forward the VoIP token to flutter_callkit_incoming → consumed in Dart
    // via FlutterCallkitIncoming.getDevicePushTokenVoIP().
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    // Backend should send a payload like:
    // {
    //   "id": "<call_uuid>",
    //   "nameCaller": "John Doe",
    //   "handle": "+22236973666",
    //   "type": 0,
    //   "extra": { "wa_call_id": "...", "sdp_offer": "..." }
    // }
    // flutter_callkit_incoming will report it to CallKit and surface the
    // event to Dart on next app launch / resume.
    guard type == .voIP else { completion(); return }
    let data = payload.dictionaryPayload as NSDictionary
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
      flutter_callkit_incoming.Data(args: data),
      fromPushKit: true
    )
    completion()
  }

  // MARK: - CallkitIncomingAppDelegate

  func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
    action.fulfill()
  }

  func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onTimeOut(_ call: flutter_callkit_incoming.Call) {
    // No-op; Dart side handles missed-call bookkeeping.
  }

  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    // flutter_webrtc uses the activated session.
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    // No-op.
  }
}
