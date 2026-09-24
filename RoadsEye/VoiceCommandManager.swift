import Foundation
import AppIntents

// ───────────────────────────────────────────────
// MARK: - VoiceCommandManager (unchanged)
// ───────────────────────────────────────────────

class VoiceCommandManager: ObservableObject {
    static let shared = VoiceCommandManager()
    
    var onCommandDetected: ((String) -> Void)?
    
    private init() {}
    
    func notifyCommand(_ command: String) {
        DispatchQueue.main.async {
            self.onCommandDetected?(command)
        }
    }
    
    func isVoiceCommandActive() -> Bool {
        SettingsViewModel.shared.isVoiceRecording
    }
}

// ───────────────────────────────────────────────
// MARK: - Shared permission check
// ───────────────────────────────────────────────
/// Returns true only if the user has voice commands enabled
private func canExecuteVoiceCommand() -> Bool {
    return SettingsViewModel.shared.isVoiceRecording
}

// ───────────────────────────────────────────────
// MARK: - Protected App Intents (FIXED)
// ───────────────────────────────────────────────

struct ClipDashcamIntent: AppIntent {
    static var title: LocalizedStringResource = "Clip Dashcam Recording"
    
    static var description = IntentDescription(
        "Save a clip of the current dashcam recording",
        categoryName: "Dashcam Controls"
    )
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard canExecuteVoiceCommand() else {
            let message: LocalizedStringResource = "Voice commands are turned off. Please enable them in Settings."
            return .result(dialog: IntentDialog(message))
        }
        
        VoiceCommandManager.shared.notifyCommand("clip it")
        return .result(dialog: IntentDialog("Clip saving..."))
    }
}

struct StopDashcamRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Dashcam Recording"
    
    static var description = IntentDescription("Stop the current dashcam recording")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard canExecuteVoiceCommand() else {
            let message: LocalizedStringResource = "Voice commands are turned off. Please enable them in Settings."
            return .result(dialog: IntentDialog(message))
        }
        
        VoiceCommandManager.shared.notifyCommand("stop recording")
        return .result(dialog: IntentDialog("Tap Stop & Save Video on screen to stop and save the recording."))
    }
}

struct StartDashcamRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Dashcam Recording"
    
    static var description = IntentDescription(
        "Start recording with the dashcam",
        categoryName: "Dashcam Controls"
    )
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard canExecuteVoiceCommand() else {
            let message: LocalizedStringResource = "Voice commands are turned off. Please enable them in Settings."
            return .result(dialog: IntentDialog(message))
        }
        
        VoiceCommandManager.shared.notifyCommand("start recording")
        return .result(dialog: IntentDialog("Recording started!"))
    }
}

// ───────────────────────────────────────────────
// MARK: - App Shortcuts Provider (unchanged)
// ───────────────────────────────────────────────

struct RoadseyeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Clip Shortcut
        AppShortcut(
            intent: ClipDashcamIntent(),
            phrases: [
                "Clip \(.applicationName)",
                "Clip it in \(.applicationName)",
                "Save clip in \(.applicationName)",
                "Clip the dashcam in \(.applicationName)",
                "Hey \(.applicationName) clip it",
                "Hey \(.applicationName), save that",
                "Clip last few minutes in \(.applicationName)",
                "Save recent driving in \(.applicationName)",
                "Dashcam clip it in \(.applicationName)",
                "Save video clip in \(.applicationName)"
            ],
            shortTitle: "Clip Dashcam",
            systemImageName: "camera.on.rectangle"
        )
        
        // Stop Shortcut
        AppShortcut(
            intent: StopDashcamRecordingIntent(),
            phrases: [
                "Stop recording in \(.applicationName)",
                "Hey \(.applicationName) stop",
                "Hey \(.applicationName), stop recording",
                "Stop dashcam in \(.applicationName)",
                "End recording in \(.applicationName)",
                "Stop the dashcam in \(.applicationName)"
            ],
            shortTitle: "Stop Dashcam",
            systemImageName: "stop.circle"
        )
        
        // New: Start Recording Shortcut
        AppShortcut(
            intent: StartDashcamRecordingIntent(),
            phrases: [
                "Start recording in \(.applicationName)",
                "Hey \(.applicationName) start recording",
                "Hey \(.applicationName), start dashcam",
                "Record now in \(.applicationName)",
                "Start dashcam in \(.applicationName)",
                "Begin recording in \(.applicationName)",
                "Hey \(.applicationName) record",
                "Start the dashcam in \(.applicationName)"
            ],
            shortTitle: "Start Recording",
            systemImageName: "record.circle"
        )
    }
    
    static var shortcutTileColor: ShortcutTileColor = .blue
}
