import SwiftUI
import AVFoundation

struct ControlButtonsView: View {
    @ObservedObject var viewModel: MainViewModel
    @ObservedObject var settingsViewModel = SettingsViewModel.shared
    @Binding var isRecording: Bool
    @Binding var showStopConfirmation: Bool
    let startRecording: () -> Void
    let stopRecording: (Bool) -> Void
    var isPortrait: Bool
    var screenSize: CGSize
    
    @State private var isProcessingClip = false
    @State private var animateDisabledButton = false
    @AppStorage("selectedClipDuration") private var selectedClipDuration = "1m"
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 100, height: 75)
                            .offset(x: 10)
                        
                        HStack(spacing: 80) {
                            ZStack(alignment: .center) {
                                // Main Button: Start / Stop
                                Button(action: {
                                    if !isRecording {
                                        startRecording()
                                    } else {
                                        showStopConfirmation = true
                                    }
                                }) {
                                    Image(isRecording ? "Stop_Icon" : "play_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .background(isRecording ? Color.red : Color.red)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                }
                                .zIndex(2)
                                
                                // Clip Button
                                if isRecording {
                                    Button(action: {
                                        performManualClip()
                                    }) {
                                        Image("Capture_Icon")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 90, height: 90)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                                            .opacity(isProcessingClip ? 0.5 : 1.0)
                                    }
                                    .disabled(isProcessingClip)
                                    .offset(y: -100)
                                    .zIndex(3)
                                }
                            }
                            .id(viewModel.isPlaying)
                            
                            // Settings Button
                            NavigationLink(destination: SettingsMenu()) {
                                Image("Settings_Icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 56)
                                    .background(isRecording ? Color.gray.opacity(0.7) : Color.white.opacity(1))
                                    .cornerRadius(10)
                                    .opacity(isRecording ? 0.5 : 1.0)
                                    .scaleEffect(animateDisabledButton ? 0.95 : 1.0)
                            }
                            .disabled(isRecording)
                            .buttonStyle(PlainButtonStyle())
                            .onTapGesture {
                                if isRecording {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        animateDisabledButton = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            animateDisabledButton = false
                                        }
                                    }
                                }
                            }
                            .zIndex(2)
                            .offset(x: -70)
                        }
                    }
                    .padding(.leading, 30)

                    Spacer()
                }
                .padding(.bottom, 35)
            }
        }
    }
    
    // MARK: - Manual Clip Logic (Improved)
    private func performManualClip() {
        guard !isProcessingClip else { return }
        isProcessingClip = true
        
        RecordingManager.shared.saveSnapshot { snapshotURL in
            guard let snapshotURL = snapshotURL else {
                DispatchQueue.main.async {
                    self.isProcessingClip = false
                    AppNotificationsManager.shared.showNotification(title: "Clip Failed", body: "Could not capture the current recording.")
                }
                return
            }

            // saveSnapshot has already started a fresh segment, so recording
            // carries on uninterrupted while the clip is exported.
            let outputURL = VideoFileManager.shared.getManualClipsDirectory()
                .appendingPathComponent("manual_\(Int(Date().timeIntervalSince1970)).mp4")

            Task {
                // Negative offset = the last N seconds of the snapshot;
                // ClippingManager clamps it to the start of the video.
                _ = await ClippingManager.shared.clipVideo(
                    videoURL: snapshotURL,
                    durationInMinutes: self.selectedClipDuration,
                    outputURL: outputURL,
                    startOffset: -self.clipDurationSeconds
                ) { success, clippedURL in
                    DispatchQueue.main.async {
                        if success, clippedURL != nil {
                            AppNotificationsManager.shared.showNotification(title: "Clip Saved", body: "Saved to ManualClips")
                        } else {
                            AppNotificationsManager.shared.showNotification(title: "Clip Failed", body: "Failed to save clip")
                        }

                        try? FileManager.default.removeItem(at: snapshotURL)
                        self.isProcessingClip = false
                    }
                }
            }
        }
    }

    private var clipDurationSeconds: Double {
        switch selectedClipDuration {
        case "30s": return 30
        case "2m": return 120
        case "3m": return 180
        default: return 60
        }
    }
}
