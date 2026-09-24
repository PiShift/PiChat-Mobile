import Flutter
import AVFAudio
import AudioToolbox
import UIKit
import PushKit
import CallKit
import WebRTC
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  /// Tells Dart that Play was tapped on a voice-note notification.
  private var notificationActions: FlutterMethodChannel?

  /// A Play tap Dart has not taken yet — it launched the app, before Dart
  /// was listening.
  private var pendingVoicePlay: [String: String]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Sound preview channel — plays bundled .caf files via AudioServicesPlaySystemSound,
    // which completely bypasses AVAudioSession and works even when VoIP holds
    // the audio hardware exclusively.
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(
        name: "com.pishift.pichat/sound_preview",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { call, result in
        guard call.method == "playSound",
              let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        // Dart writes the Flutter asset to a temp file and passes the
        // absolute path here, so we never need to search the bundle.
        let url = URL(fileURLWithPath: filePath)
        var soundId: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
        AudioServicesPlaySystemSound(soundId)
        result(nil)
      }

      // Background time for sends. iOS suspends the app seconds after it
      // leaves the foreground, cutting an upload off mid-request; a
      // background task asks for the time to finish it. Dart wraps each send
      // in begin/end (lib/core/platform/background_task.dart).
      FlutterMethodChannel(
        name: "pichat/background_task",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { call, result in
        switch call.method {
        case "begin":
          var taskId: UIBackgroundTaskIdentifier = .invalid
          taskId = application.beginBackgroundTask(withName: "pichat.send") {
            // Out of time: end it ourselves, or iOS kills the app.
            application.endBackgroundTask(taskId)
          }
          result(taskId == .invalid ? nil : taskId.rawValue)
        case "end":
          if let raw = call.arguments as? Int {
            application.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: raw))
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let actions = FlutterMethodChannel(
        name: "pichat/notification_actions",
        binaryMessenger: controller.binaryMessenger
      )
      actions.setMethodCallHandler { [weak self] call, result in
        guard call.method == "takePendingPlay" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self?.pendingVoicePlay)
        self?.pendingVoicePlay = nil
      }
      notificationActions = actions
    }

    // Ask for standard remote-push permission so FCM can wake the app
    // (used for in-call signaling updates and chat notifications).
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let opts: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(options: opts) { _, _ in }

      // Voice-note pushes carry this category (set by the server) and get a
      // Play button that opens the conversation and starts the note.
      let play = UNNotificationAction(
        identifier: "PLAY_VOICE",
        title: NSLocalizedString("Play", comment: "Play a voice note from its notification"),
        options: [.foreground]
      )
      UNUserNotificationCenter.current().setNotificationCategories([
        UNNotificationCategory(identifier: "VOICE_NOTE", actions: [play], intentIdentifiers: [], options: [])
      ])
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

  // MARK: - Notification actions

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.actionIdentifier == "PLAY_VOICE" {
      let info = response.notification.request.content.userInfo
      let play = [
        "contact_uuid": info["contact_uuid"] as? String ?? "",
        "media_id": info["media_id"] as? String ?? "",
      ]
      // Kept until Dart confirms it has it: on a cold start nothing is
      // listening yet, and Dart asks for it once it is.
      pendingVoicePlay = play
      notificationActions?.invokeMethod("playVoice", arguments: play) { [weak self] result in
        if !(result is FlutterError) && (result as? NSObject) !== FlutterMethodNotImplemented {
          self?.pendingVoicePlay = nil
        }
      }
    }

    // Firebase still sees the tap and opens the conversation as usual.
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
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
    //   "handle": "+22236090070",
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

  // CallKit owns the audio session for a call it presents, and WebRTC has to be
  // told when that session becomes active — it does not observe CallKit itself.
  // Without these two hooks a call answered from the CallKit UI (lock screen,
  // or any VoIP-woken call) connects but carries no audio in either direction.
  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    let rtcSession = RTCAudioSession.sharedInstance()
    rtcSession.audioSessionDidActivate(audioSession)
    // WebRTC refuses to touch the session unless it believes it owns it.
    rtcSession.isAudioEnabled = true
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    let rtcSession = RTCAudioSession.sharedInstance()
    rtcSession.audioSessionDidDeactivate(audioSession)
    rtcSession.isAudioEnabled = false
  }
}
