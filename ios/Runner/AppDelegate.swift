import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Configure notification categories for call actions
    configureNotificationCategories()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func configureNotificationCategories() {
    // Define call notification actions
    let acceptAction = UNNotificationAction(
      identifier: "accept_call",
      title: "Accept",
      options: [.foreground]
    )
    
    let declineAction = UNNotificationAction(
      identifier: "decline_call",
      title: "Decline",
      options: [.destructive]
    )
    
    // Create call category with actions
    let callCategory = UNNotificationCategory(
      identifier: "CALL_CATEGORY",
      actions: [acceptAction, declineAction],
      intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: "Incoming Call",
      options: [.customDismissAction]
    )
    
    // Register the category
    UNUserNotificationCenter.current().setNotificationCategories([callCategory])
  }
}
