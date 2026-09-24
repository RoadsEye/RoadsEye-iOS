import UserNotifications
import UIKit

class AppNotificationsManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationsManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestNotificationPermission(completion: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                } else {
                    print("Notification permission granted: \(granted)")
                }
                completion?(granted)
            }
        }
    }
    
    func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let granted = settings.authorizationStatus == .authorized
            print("Notification permission status: \(settings.authorizationStatus.rawValue)")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func showNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { settings in
            print("Checking notification settings: \(settings.authorizationStatus.rawValue)")
            guard settings.authorizationStatus == .authorized else {
                print("Notifications not authorized, skipping notification")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                } else {
                    print("Notification scheduled: \(title) - \(body)")
                }
            }
        }
    }
    
    // Handle notifications when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Received notification in foreground: \(notification.request.content.title)")
        completionHandler([.banner, .sound])
    }
}
