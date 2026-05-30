import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    Messaging.messaging().delegate = self

    // Request notification permissions
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { _, _ in }
    )
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Pass APNs token to Firebase Auth explicitly (belt + suspenders with swizzling)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Firebase Auth needs this for silent push phone verification
    #if DEBUG
    Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
    #else
    Auth.auth().setAPNSToken(deviceToken, type: .prod)
    #endif
    Messaging.messaging().apnsToken = deviceToken

    #if DEBUG
    print("APNs token set for Auth + Messaging")
    #endif

    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Let Firebase Auth handle silent push for phone verification
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Auth.auth().canHandleNotification(userInfo) {
      #if DEBUG
      print("Firebase Auth handled silent push notification")
      #endif
      completionHandler(.noData)
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }

  // Handle URL callbacks (reCAPTCHA fallback for phone auth)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    #if DEBUG
    if let token = fcmToken {
      print("FCM token: \(token.prefix(20))...")
    }
    #endif
  }
}
