import SwiftUI
import Foundation

/// Publishes the user's selected FPS so views can react to changes.
/// SessionManager is responsible for actually applying it to the camera.
class FPSManager: ObservableObject {
    static let shared = FPSManager()

    @Published var currentFPS: Int = 30

    static var selectedFPS: String {
        UserDefaults.standard.string(forKey: "selectedFPS") ?? "30"
    }

    private init() {
        updateFPS()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDefaultsChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleUserDefaultsChange() {
        updateFPS()
    }

    func updateFPS() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.updateFPS() }
            return
        }
        let newFPS = FPSManager.getCurrentFPS()
        if currentFPS != newFPS {
            currentFPS = newFPS
        }
    }

    static func getCurrentFPS() -> Int {
        return Int(selectedFPS) ?? 30
    }
}
