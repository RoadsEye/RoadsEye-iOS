import SwiftUI
import UIKit

@main
struct RoadsEyeApp: App {

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("selectedAppearance") private var selectedAppearance: String = "System"

    private let currentTermsVersion   = "1.7"
    private let currentPrivacyVersion = "1.7"

    @AppStorage("tutorialShown") private var tutorialShown: Bool = false
    @AppStorage("didAcceptTermsAndPrivacy") private var didAcceptTermsAndPrivacy: Bool = false
    @AppStorage("acceptedTermsVersion") private var acceptedTermsVersion: String = ""
    @AppStorage("acceptedPrivacyVersion") private var acceptedPrivacyVersion: String = ""
    @AppStorage("hideOpenSourceNotice") private var hideOpenSourceNotice: Bool = false

    @State private var showOpenSourceNotice = false
    /// "OK" hides the notice until the next launch, so it must not pop back up
    /// if MainView reappears later in the same session.
    @State private var didShowOpenSourceNotice = false

    init() {
        VideoFileManager.shared.ensureRoadsEyeFoldersExist()
        VideoFileManager.cleanAllTemporaryVideosOnLaunch()
        configureInitialSettings()
        IdleTimerManager.shared.disableIdleTimer(reason: "RoadsEyeApp init")
    }
    
    var body: some Scene {
        WindowGroup {
            // Strict launch flow: Onboarding → ToS/PP → permissions (asked by
            // MainView after acceptance) → Main App. MainView is not created
            // until terms are accepted, so no permission prompt can fire early.
            ZStack {
                if !tutorialShown {
                    OnboardingView()
                } else if needsTermsAcceptance {
                    TermsAcceptanceOverlay(
                        isPresented: .constant(true),
                        currentTermsVersion: currentTermsVersion,
                        currentPrivacyVersion: currentPrivacyVersion
                    )
                    .transition(.opacity)
                } else {
                    MainView()
                        .onAppear {
                            IdleTimerManager.shared.disableIdleTimer(reason: "MainView onAppear")
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .initialPermissionsHandled)) { _ in
                            // Open source announcement: shown once MainView has
                            // finished asking for permissions, so it never sits
                            // under a system prompt. "OK" hides it until the
                            // next launch; "Don't show again" hides it for good.
                            if !hideOpenSourceNotice && !didShowOpenSourceNotice {
                                didShowOpenSourceNotice = true
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showOpenSourceNotice = true
                                }
                            }
                        }

                    if showOpenSourceNotice {
                        OpenSourceNoticeView(isPresented: $showOpenSourceNotice)
                            .transition(.opacity)
                            .zIndex(10)
                    }
                }
            }
            .preferredColorScheme(
                selectedAppearance == "Light" ? .light :
                selectedAppearance == "Dark" ? .dark : nil
            )
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    IdleTimerManager.shared.disableIdleTimer(reason: "scene active")
                case .inactive:
                    IdleTimerManager.shared.reinforceIdleTimer(reason: "scene inactive")
                case .background:
                    IdleTimerManager.shared.enableIdleTimer(reason: "scene background")
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - First Install
    private func configureInitialSettings() {
        let defaults = UserDefaults.standard
        // Older versions kept this flag in iCloud only, so an existing
        // onboarding state also means the app has been set up before.
        let hasCompletedFirstInstall = defaults.bool(forKey: "hasCompletedFirstInstall")
            || defaults.object(forKey: "tutorialShown") != nil

        if !hasCompletedFirstInstall {
            defaults.set(true, forKey: "hasCompletedFirstInstall")

            // Reset local settings
            defaults.set(false, forKey: "tutorialShown")
            defaults.set(false, forKey: "didAcceptTermsAndPrivacy")

            defaults.removeObject(forKey: "acceptedTermsVersion")
            defaults.removeObject(forKey: "acceptedPrivacyVersion")

            LocationSpeedManager.shared.determineSpeedUnitForLocation()

            print("🚀 First install")
        } else {
            print("Not first install (reinstall or update).")
        }
    }
    
    private var needsTermsAcceptance: Bool {
        // Empty version = accepted before versioning was introduced; treat as current
        let acceptedTerms   = acceptedTermsVersion.isEmpty   ? currentTermsVersion   : acceptedTermsVersion
        let acceptedPrivacy = acceptedPrivacyVersion.isEmpty ? currentPrivacyVersion : acceptedPrivacyVersion

        return !didAcceptTermsAndPrivacy ||
               !isVersionNewerOrEqual(current: currentTermsVersion, accepted: acceptedTerms) ||
               !isVersionNewerOrEqual(current: currentPrivacyVersion, accepted: acceptedPrivacy)
    }
    
    private func isVersionNewerOrEqual(current: String, accepted: String) -> Bool {
        let c = current.split(separator: ".").compactMap { Int($0) }
        let a = accepted.split(separator: ".").compactMap { Int($0) }
        
        let len = min(c.count, a.count)
        for i in 0..<len {
            if c[i] > a[i] { return false }
            if c[i] < a[i] { return true }
        }
        return true
    }
}
