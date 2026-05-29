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
    // Initialize Firebase (must be before other Firebase calls)
    FirebaseApp.configure()

    // Set up Firebase Messaging delegate
    Messaging.messaging().delegate = self

    // Request notification permissions
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]

    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { granted, error in
        if granted {
          DispatchQueue.main.async {
            application.registerForRemoteNotifications()
          }
        }
      }
    )
    // Register immediately (needed for silent push / phone auth)
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // CRITICAL: Pass APNs token to BOTH Firebase Auth AND Messaging
  // Firebase Auth needs this for silent push verification (phone OTP)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Firebase Auth — required for silent push phone verification
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)

    // Firebase Messaging — required for FCM push notifications
    Messaging.messaging().apnsToken = deviceToken

    #if DEBUG
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    print("APNs token registered: \(tokenString.prefix(20))...")
    #endif
  }

  // CRITICAL: Handle silent push notifications from Firebase Auth
  // This is what Firebase sends to verify the phone number without reCAPTCHA
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    // Let Firebase Auth handle silent push verification
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }

    // Pass to Flutter for other notifications
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }

  // Firebase Messaging delegate
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    #if DEBUG
    if let token = fcmToken {
      print("FCM token: \(token.prefix(20))...")
    }
    #endif
  }

  // Handle remote notification registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    #if DEBUG
    print("Failed to register for remote notifications: \(error.localizedDescription)")
    #endif
  }
}
