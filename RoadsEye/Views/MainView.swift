import SwiftUI
import PhotosUI
import UIKit
import CoreLocation
import UserNotifications
import AVFoundation
import Speech

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @ObservedObject private var locationSpeedManager = LocationSpeedManager.shared
    @ObservedObject private var fpsManager = FPSManager.shared
    @ObservedObject private var crashDetectionManager = CrashDetectionManager.shared
    @ObservedObject private var settingsViewModel = SettingsViewModel.shared
    
    @State private var isRecording = false
    @State private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    @State private var showStopConfirmation = false
    @State private var currentOrientation = UIDevice.current.orientation
    @State private var viewSize: CGSize = .zero
    @State private var showCrashAlert = false
    @State private var crashTimerProgress: Double = 1.0
    @State private var crashTimer: Timer?
    @State private var overlayRefreshTrigger = false
    @State private var crashAlertWindow: UIWindow?
    @State private var crashAlertHostingController: UIHostingController<CrashAlertLayer>?
    @State private var showWakePhraseAlert = false

    @AppStorage("isDrivingOverlayEnabled") private var isDrivingOverlayEnabled: Bool = true

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        bodyContent
    }

    private var bodyContent: some View {
        GeometryReader { geometry in
            mainView(geometry: geometry)
        }
        .edgesIgnoringSafeArea(.all)
        .background(Color.clear)
    }
    
    private func mainView(geometry: GeometryProxy) -> some View {
        NavigationView {
            zstackView(geometry: geometry)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: showCrashAlert) { oldValue, newValue in
            if newValue {
                showCrashAlertWindow()
            } else {
                hideCrashAlertWindow()
            }
        }
        .onChange(of: crashTimerProgress) { _, _ in
            updateCrashAlertWindow()
        }
        .onAppear {
            setupOnAppear()
            viewSize = geometry.size
            IdleTimerManager.shared.disableIdleTimer(reason: "MainView onAppear")

            VideoFileManager.shared.ensureRoadsEyeFoldersExist()
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let mainWindow = windowScene.windows.first {
                mainWindow.windowLevel = .normal
                mainWindow.backgroundColor = .clear
                print("MainView: Main window set to level \(mainWindow.windowLevel.rawValue)")
            }
            
            // Voice Command Handler
            VoiceCommandManager.shared.onCommandDetected = { command in
                DispatchQueue.main.async { [self] in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showWakePhraseAlert = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showWakePhraseAlert = false
                        }
                    }
                    
                    switch command.lowercased() {
                    case "clip it", "clip recording", "clip", "save clip", "dashcam clip it":
                        handleClipCommand()
                    case "start recording":
                        startRecording()
                    case "stop recording":
                        // Same as tapping Stop: ask first, and stopping saves the video.
                        if isRecording {
                            showStopConfirmation = true
                        }
                    case "error":
                        AppNotificationsManager.shared.showNotification(title: "Voice Command Error", body: "Unable to process voice commands.")
                    default:
                        break
                    }
                }
            }
            
            
            crashDetectionManager.onCrashDetected = {
                DispatchQueue.main.async { handleCrashDetected() }
            }
            
            
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let newOrientation = UIDevice.current.orientation
            if currentOrientation != newOrientation, newOrientation.isPortrait || newOrientation.isLandscape {
                currentOrientation = newOrientation
                viewModel.objectWillChange.send()
                IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView orientation changed")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutoRecordingStarted"))) { _ in
            isRecording = true
            viewModel.isRecording = true
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView AutoRecordingStarted")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutoRecordingStopped"))) { _ in
            isRecording = false
            viewModel.isRecording = false
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView AutoRecordingStopped")
        }
        .onDisappear {
            viewModel.stopTimers()
            crashTimer?.invalidate()
            crashTimer = nil
            hideCrashAlertWindow()
            VoiceCommandManager.shared.onCommandDetected = nil
            endBackgroundTask()
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView onDisappear")
        }
    }
    
    private func zstackView(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            cameraViewLayer
                .frame(width: geometry.size.width, height: geometry.size.height)
                .edgesIgnoringSafeArea(.all)
                .zIndex(-1)
            
            VStack(spacing: 0) {
                overlayInformationLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(overlayRefreshTrigger)
            }

            controlButtonsLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(2)
        }
        .alert("Stop Recording?", isPresented: $showStopConfirmation) {
            Button("Continue Recording", role: .cancel) {
                showStopConfirmation = false
            }
            
            Button("Stop & Save Video") {
                showStopConfirmation = false
                stopAndSaveRecording()
            }
        } message: {
            Text("The current recording segment will be saved to your RoadsEye folder.")
        }
        .onChange(of: isDrivingOverlayEnabled) { _, newValue in
            print("MainView: Driving overlay enabled changed to \(newValue)")
            overlayRefreshTrigger.toggle()
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView isDrivingOverlayEnabled changed")
        }
        .onChange(of: isRecording) { oldValue, newValue in
            crashDetectionManager.updateRecordingState(newValue)
            print("MainView: Recording state changed to \(newValue)")
            if newValue {
                setupBackgroundSupport()
            } else {
                endBackgroundTask()
            }
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView isRecording changed")
        }
        .onChange(of: settingsViewModel.isVoiceRecording) { _, newValue in
            print("MainView: Voice commands toggle changed → \(newValue ? "ON" : "OFF")")
            
            if newValue {
                requestVoicePermissionsIfNeeded()
            }
            
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView isVoiceRecording changed")
        }
    }
    
    // MARK: - Control Buttons Layer
    private var controlButtonsLayer: some View {
        GeometryReader { geometry in
            ControlButtonsView(
                viewModel: viewModel,
                isRecording: $isRecording,
                showStopConfirmation: $showStopConfirmation,
                startRecording: startRecording,
                stopRecording: stopRecording,
                isPortrait: geometry.size.height > geometry.size.width,
                screenSize: geometry.size
            )
        }
    }
    
    private func requestVoicePermissionsIfNeeded() {
            let micStatus = AVAudioApplication.shared.recordPermission
            let speechStatus = SFSpeechRecognizer.authorizationStatus()
            
            if micStatus == .granted && speechStatus == .authorized {
                print("Voice permissions already granted → good to go")
                return
            }
            
            print("Requesting voice permissions because user enabled voice commands")
            
            if micStatus != .granted {
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        print("Microphone permission after toggle: \(granted ? "granted" : "denied")")
                        if !granted {
                            self.showPermissionDeniedAlert(for: "Microphone")
                        }
                    }
                }
            }
            
            if speechStatus != .authorized && speechStatus != .denied {
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        let granted = status == .authorized
                        let statusText: String
                        switch status {
                        case .authorized:       statusText = "authorized"
                        case .denied:           statusText = "denied"
                        case .restricted:       statusText = "restricted"
                        case .notDetermined:    statusText = "not determined"
                        @unknown default:       statusText = "unknown"
                        }
                        print("Speech recognition permission after toggle: \(granted ? "authorized" : statusText)")
                        if !granted && status != .denied {
                            self.showPermissionDeniedAlert(for: "Speech Recognition")
                        }
                    }
                }
            }
        }
        
        private func showPermissionDeniedAlert(for permissionType: String) {
            let title = "\(permissionType.capitalized) Access Denied"
            let message = "Road's Eye needs \(permissionType) access to enable voice commands.\n\n" +
                          "Please go to Settings → Road's Eye → \(permissionType.capitalized) and turn it on."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    var topVC = rootVC
                    while let presented = topVC.presentedViewController {
                        topVC = presented
                    }
                    topVC.present(alert, animated: true)
                }
            }
        }
        
    private var cameraViewLayer: some View {
        ZStack {
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                CameraView(isRecording: $isRecording)
                    .edgesIgnoringSafeArea(.all)
                    .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification, object: UIDevice.current)) { _ in
                        DispatchQueue.main.async {
                            viewModel.objectWillChange.send()
                            print("MainView: CameraView orientation change detected")
                            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView CameraView orientation change")
                        }
                    }
            } else {
                Color.red
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .background(Color.clear)
    }
    
    private var overlayInformationLayer: some View {
        VStack(alignment: .leading, spacing: 1.5) {
            Spacer()
                .frame(height: 25)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
        .onAppear {
            print("MainView: OverlayInformationLayer appeared - DrivingOverlay=\(isDrivingOverlayEnabled)")
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView OverlayInformationLayer onAppear")
        }
    }
    
    private func showCrashAlertWindow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 2
        window.backgroundColor = .clear
        
        let alert = CrashAlertLayer(
            crashTimerProgress: $crashTimerProgress,
            onCancel: cancelCrashDetection,
            onConfirm: confirmCrashDetection
        )
        let host = UIHostingController(rootView: alert)
        host.view.backgroundColor = .clear
        
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        
        crashAlertWindow = window
        crashAlertHostingController = host
        print("MainView: Crash alert window shown at level \(window.windowLevel.rawValue)")
        IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView showCrashAlertWindow")
    }
    
    private func updateCrashAlertWindow() {
        crashAlertHostingController?.rootView = CrashAlertLayer(
            crashTimerProgress: $crashTimerProgress,
            onCancel: cancelCrashDetection,
            onConfirm: confirmCrashDetection
        )
        IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView updateCrashAlertWindow")
    }
    
    private func hideCrashAlertWindow() {
        DispatchQueue.main.async {
            crashTimer?.invalidate()
            crashTimer = nil
            showCrashAlert = false
            crashAlertWindow?.isHidden = true
            crashAlertWindow = nil
            crashAlertHostingController = nil
            print("MainView: Crash alert window hidden")
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView hideCrashAlertWindow")
        }
    }
    
    private struct CrashAlertLayer: View {
        @Binding var crashTimerProgress: Double
        let onCancel: () -> Void
        let onConfirm: () -> Void
        
        var body: some View {
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Text("Possible Crash Detected!")
                            .font(.system(size: fontSize(for: geo, base: 32), weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                        
                        Text("Confirm if this is a crash. Video will be saved automatically in \(Int(max(crashTimerProgress, 0) * 30)) seconds.")
                            .font(.system(size: fontSize(for: geo, base: 18)))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        ProgressView(value: max(min(crashTimerProgress, 1.0), 0.0))
                            .progressViewStyle(.linear)
                            .tint(.red)
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                        
                        HStack(spacing: 20) {
                            button(title: "Cancel", color: .gray.opacity(0.9), action: onCancel)
                            button(title: "Confirm", color: .red, action: onConfirm)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 24)
                        .padding(.bottom, 28)
                    }
                    .frame(maxWidth: cardWidth(for: geo))
                    .frame(maxHeight: geo.size.height * 0.70)
                    .background(Color.black.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.red, lineWidth: redBorderWidth(for: geo))
                    )
                    .shadow(color: .red.opacity(0.6), radius: 20, x: 0, y: 0)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea()
        }
        
        private func fontSize(for geo: GeometryProxy, base: CGFloat) -> CGFloat {
            let scale = min(geo.size.width, geo.size.height) / 375
            return max(base * scale, base * 0.7)
        }
        
        private func cardWidth(for geo: GeometryProxy) -> CGFloat {
            min(geo.size.width * 0.85, 420)
        }
        
        private func redBorderWidth(for geo: GeometryProxy) -> CGFloat {
            min(geo.size.width, geo.size.height) / 150
        }
        
        private func button(title: String, color: Color, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            viewModel.startTimers()
            IdleTimerManager.shared.disableIdleTimer(reason: "MainView scenePhase active")

            if viewModel.isRecording {
                if viewModel.isAutoRecordingEnabled {
                    AutoRecordManager.shared.forceStartRecording()
                } else if !RecordingManager.shared.isRecording {
                    RecordingManager.shared.startRecording()
                }
            }
            if viewModel.isAutoRecordingEnabled {
                AutoRecordManager.shared.setEnabled(true)
            }
            print("MainView: ScenePhase active, isRecording=\(isRecording)")
            
        case .background:
            if !viewModel.isPlaying {
                viewModel.stopTimers()
            }
            if isRecording {
                setupBackgroundSupport()
            } else {
                RecordingManager.shared.handleAppStateChange(active: false)
                endBackgroundTask()
                IdleTimerManager.shared.enableIdleTimer(reason: "MainView scenePhase background")
            }
            print("MainView: ScenePhase background, isRecording=\(isRecording)")
            
        case .inactive:
            print("MainView: ScenePhase inactive, isRecording=\(isRecording)")
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView scenePhase inactive")
            
        @unknown default:
            break
        }
    }
    
    private func setupOnAppear() {
        Task {
            await requestInitialPermissionsSequentially()
            
            setupBackgroundSupport()
            viewModel.startTimers()
            fpsManager.updateFPS()

            if UserDefaults.standard.object(forKey: "isCrashDetectionEnabled") == nil {
                crashDetectionManager.setCrashDetectionEnabled(false)
            }
            if UserDefaults.standard.object(forKey: "isDrivingOverlayEnabled") == nil {
                isDrivingOverlayEnabled = true
                UserDefaults.standard.set(true, forKey: "isDrivingOverlayEnabled")
                print("MainView: Initialized driving overlay to enabled: \(isDrivingOverlayEnabled)")
            }
            if viewModel.isAutoRecordingEnabled {
                AutoRecordManager.shared.setEnabled(true)
                isRecording = AutoRecordManager.shared.isActive
                viewModel.isRecording = isRecording
                print("MainView: Initialized isRecording=\(isRecording) based on AutoRecordManager.isActive")
            }
            crashDetectionManager.setCrashDetectionEnabled(crashDetectionManager.isCrashDetectionEnabled)
            crashDetectionManager.updateRecordingState(isRecording)

            // Lets the app show launch notices without covering permission prompts.
            NotificationCenter.default.post(name: .initialPermissionsHandled, object: nil)
        }

        print("MainView: Setup complete, isRecording=\(isRecording)")
        IdleTimerManager.shared.disableIdleTimer(reason: "MainView setupOnAppear")
    }
    
    private func requestInitialPermissionsSequentially() async {
        print("Starting sequential permission requests")

        await requestNotificationsIfNeeded()
        await requestCameraIfNeeded()
        await requestPhotosIfNeeded()
        await requestLocationIfNeeded()

        if settingsViewModel.isVoiceRecording {
            await requestVoicePermissionsSequentially()
        }

        print("All initial permissions handled sequentially")
    }

    private func requestNotificationsIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        let granted = await withCheckedContinuation { continuation in
            AppNotificationsManager.shared.requestNotificationPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        print("Notification permission requested → \(granted ? "granted" : "denied")")
    }
    
    private func requestCameraIfNeeded() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else { return }
        
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
        print("Camera permission requested → \(granted ? "granted" : "denied")")
    }
    
    private func requestPhotosIfNeeded() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .notDetermined else { return }
        
        let newStatus = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        print("Photos permission requested → \(newStatus == .authorized ? "authorized" : "status=\(newStatus.rawValue)")")
    }
    
    private func requestLocationIfNeeded() async {
        let tempLocationManager = CLLocationManager()
        let status = tempLocationManager.authorizationStatus
        guard status == .notDetermined else {
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationSpeedManager.requestLocationPermissionAndStartIfNeeded()
            }
            return
        }
        
        locationSpeedManager.requestLocationPermissionAndStartIfNeeded()

        // Wait for the user to answer the prompt (up to a minute) so the next
        // prompt or launch notice doesn't appear on top of it.
        for _ in 0..<200 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if tempLocationManager.authorizationStatus != .notDetermined { break }
        }
    }
    
    private func requestVoicePermissionsSequentially() async {
        let micStatus = AVAudioApplication.shared.recordPermission
        if micStatus == .undetermined {
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            print("Microphone permission requested → \(granted ? "granted" : "denied")")
        }
        
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            let newStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            print("Speech recognition permission requested → status=\(newStatus)")
        }
    }
    
    private func startRecording() {
        requestRecordingPermissions { granted in
            DispatchQueue.main.async {
                guard granted else {
                    AppNotificationsManager.shared.showNotification(
                        title: "Permissions Required",
                        body: "Camera, Photos, and Microphone access are required."
                    )
                    return
                }
                
                if RecordingManager.shared.isRecording {
                    print("MainView: Recording already in progress")
                    return
                }
                
                print("MainView: Starting recording process...")
                
                viewModel.isPlaying = true
                viewModel.isRecording = true
                isRecording = true
                
                // Critical: Offload to background queue + small delay
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                    RecordingManager.shared.startRecording()
                }
                
                AppNotificationsManager.shared.showNotification(
                    title: "Recording Started",
                    body: "Dashcam is now recording."
                )
            }
        }
    }
    
    private func requestRecordingPermissions(completion: @escaping (Bool) -> Void) {
        let cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        let photoGranted = PHPhotoLibrary.authorizationStatus() == .authorized
        
        var microphoneGranted = true
        var speechGranted = true
        
        if settingsViewModel.isVoiceRecording {
            microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
            speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        }
        
        let allGranted = cameraGranted && photoGranted && microphoneGranted && speechGranted
        
        print("MainView: Checking permissions - Camera: \(cameraGranted), Photo: \(photoGranted), Mic: \(microphoneGranted), Speech: \(speechGranted)")
        
        if !allGranted {
            AppNotificationsManager.shared.showNotification(
                title: "Permissions Required",
                body: "Please enable required permissions in Settings to record."
            )
        }
        
        completion(allGranted)
        IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView requestRecordingPermissions check")
    }
    
    private func stopAndSaveRecording() {
        stopRecording(saveVideo: true)
        AppNotificationsManager.shared.showNotification(
            title: "Recording Stopped",
            body: "Video has been saved."
        )
    }

    private func stopRecording(saveVideo: Bool) {
        DispatchQueue.main.async {
            viewModel.isPlaying = false
            viewModel.isRecording = false
            isRecording = false

            // RecordingManager saves the final segment (already written to the
            // RoadsEye folder) to the photo library when saveVideo is true.
            // No extra clipping pass here — it used to save the same footage twice.
            if viewModel.isAutoRecordingEnabled {
                AutoRecordManager.shared.forceStopRecording(saveVideo: saveVideo)
            } else {
                RecordingManager.shared.stopRecording(saveVideo: saveVideo)
            }

            print("MainView: Recording Stopped, isRecording=\(isRecording)")
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView stopRecording")
        }
    }
    
    private func handleCrashDetected() {
        guard crashDetectionManager.isCrashDetectionEnabled else { return }
        DispatchQueue.main.async {
            showCrashAlert = true
            crashTimerProgress = 1.0
            crashTimer?.invalidate()
            crashTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                crashTimerProgress = max(crashTimerProgress - 0.1 / 30.0, 0.0)
                if crashTimerProgress <= 0 {
                    confirmCrashDetection()
                }
            }
            print("MainView: Crash alert displayed → 30s countdown started")
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView handleCrashDetected")
        }
    }
    
    private func confirmCrashDetection() {
        DispatchQueue.main.async {
            self.crashTimer?.invalidate()
            self.crashTimer = nil
            self.showCrashAlert = false
            
            print("MainView: Crash confirmed - saving last 2 minutes...")
            
            // Call the dedicated crash clip method (saves most recent 2 minutes)
            Task {
                await CrashDetectionManager.shared.saveCrashClip()
            }
            
            // Restart recording after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if self.viewModel.isAutoRecordingEnabled {
                    AutoRecordManager.shared.forceStartRecording()
                } else if self.isRecording {
                    RecordingManager.shared.startRecording()
                }
                IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView crash → restart recording")
            }
        }
    }
    
    private func cancelCrashDetection() {
        DispatchQueue.main.async {
            crashTimer?.invalidate()
            crashTimer = nil
            showCrashAlert = false
            print("MainView: Crash alert cancelled")
            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView cancelCrashDetection")
        }
    }
    
    private func handleClipCommand() {
        guard isRecording || viewModel.isAutoRecordingEnabled else {
            AppNotificationsManager.shared.showNotification(
                title: "Clip Failed",
                body: "No active recording to clip."
            )
            return
        }
        if viewModel.isAutoRecordingEnabled && !RecordingManager.shared.isRecording {
            AutoRecordManager.shared.forceStartRecording()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.processClipCommand()
            }
        } else {
            processClipCommand()
        }
    }
    
    private func processClipCommand() {
        guard RecordingManager.shared.isRecording, RecordingManager.shared.getCurrentRecordingURL() != nil else { return }
        RecordingManager.shared.saveSnapshot { snapshotURL in
            guard let snapshotURL = snapshotURL else {
                DispatchQueue.main.async {
                    AppNotificationsManager.shared.showNotification(
                        title: "Clip Failed",
                        body: "Could not capture the current recording."
                    )
                    if self.viewModel.isAutoRecordingEnabled {
                        AutoRecordManager.shared.resumeMonitoring()
                    }
                }
                return
            }

            // Same folder as clips taken with the on-screen button.
            let outputURL = VideoFileManager.shared.getManualClipsDirectory()
                .appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).mp4")

            let clipDuration = UserDefaults.standard.string(forKey: "selectedClipDuration") ?? "1m"
            let durationInSeconds: Double
            switch clipDuration {
            case "30s": durationInSeconds = 30.0
            case "2m": durationInSeconds = 120.0
            case "3m": durationInSeconds = 180.0
            default: durationInSeconds = 60.0
            }

            Task {
                // ClippingManager clamps the start to the beginning of the
                // snapshot, so a negative offset of the full duration is safe.
                _ = await ClippingManager.shared.clipVideo(
                    videoURL: snapshotURL,
                    durationInMinutes: clipDuration,
                    outputURL: outputURL,
                    startOffset: -durationInSeconds,
                    completion: { success, clippedURL in
                        DispatchQueue.main.async {
                            if success, clippedURL != nil {
                                AppNotificationsManager.shared.showNotification(
                                    title: "Video Saved",
                                    body: "The video clip has been successfully saved."
                                )
                            } else {
                                AppNotificationsManager.shared.showNotification(
                                    title: "Clip Failed",
                                    body: "Failed to save the video clip."
                                )
                            }
                            try? FileManager.default.removeItem(at: snapshotURL)
                            if self.viewModel.isAutoRecordingEnabled {
                                AutoRecordManager.shared.resumeMonitoring()
                            }
                            IdleTimerManager.shared.reinforceIdleTimer(reason: "MainView processClipCommand")
                        }
                    }
                )
            }
        }
    }
    
    private func setupBackgroundSupport() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MainViewBackgroundTask") {
            if self.backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }
        }
        print("MainView: Background task started with ID: \(backgroundTask)")
    }
    		
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            print("MainView: Ending background task with ID: \(backgroundTask)")
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

extension Notification.Name {
    static let initialPermissionsHandled = Notification.Name("InitialPermissionsHandled")
}
