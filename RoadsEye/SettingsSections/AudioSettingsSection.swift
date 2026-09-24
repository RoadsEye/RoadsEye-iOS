import SwiftUI

struct AudioSettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    let backgroundColor: Color
    let cardBackgroundColor: Color
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingVoiceCommandInfo = false

    var body: some View {
        SettingsSection(title: "Audio Settings", backgroundColor: backgroundColor, cardColor: cardBackgroundColor, viewModel: viewModel) {
            VStack(spacing: 1) {
                HStack {
                    ToggleRow(
                        title: "Voice Commands via Siri",
                        isOn: $viewModel.isVoiceRecording,
                        accentColor: accentColor,
                        viewModel: viewModel,
                        parentSection: "Audio Settings"
                    )
                    
                    Button(action: {
                        showingVoiceCommandInfo = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(accentColor)
                            .font(.system(size: 20))
                    }
                    .padding(.trailing, 8)
                }
                
                // No extra warning texts here anymore
            }
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingVoiceCommandInfo) {
            VoiceCommandInfoView()
        }
        // Removed .alert and .onChange(of:) that showed the microphone disclaimer
    }
}

// VoiceCommandInfoView remains completely unchanged as requested
struct VoiceCommandInfoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Use Voice Commands")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    Text("Voice commands let you control Road's Eye hands-free using Siri. Say \"Hey Siri\" or \"Siri\", then speak a command including your app name for best results.")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Requirements")
                            .font(.headline)
                        Text("• Voice Commands toggle turned ON in Audio Settings\n• Microphone & Speech Recognition permissions granted")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. Activate Siri")
                            .font(.headline)
                        Text("Start with one of these:")
                            .font(.body)
                        Text("• \"Hey Siri\"\n• \"Siri\" (single word – works on iOS 17 and later)")
                            .font(.body)
                            .padding(.leading, 10)
                        Text("Then immediately say your command (include \"in Road's Eye\" for it to work properly).")
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("2. Supported Commands")
                            .font(.headline)
                        Text("Say one of these clearly (must include \"in Road's Eye\" or similar for Siri to target your app):")
                            .font(.body)
                        Text("• **Clip it in Road's Eye** / **Clip recording in Road's Eye** / **Save clip in Road's Eye**\n• **Start recording in Road's Eye** / **Start dashcam in Road's Eye**\n• **Stop recording in Road's Eye** / **Stop dashcam in Road's Eye**")
                            .font(.body)
                            .padding(.leading, 10)
                        Text("Examples (these work reliably):")
                            .font(.body.bold())
                            .padding(.top, 4)
                        Text("• \"Hey Siri, clip it in Road's Eye\"\n• \"Siri, start recording in Road's Eye\"\n• \"Hey Siri, stop recording in Road's Eye\"")
                            .font(.body)
                            .padding(.leading, 10)
                        Text("Without \"in Road's Eye\", Siri may not understand which app to use.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("3. Stop Recording Confirmation")
                            .font(.headline)
                        Text("Saying 'Stop recording in Road's Eye' works just like tapping the Stop button: the app asks for confirmation. Tap 'Stop & Save Video' to stop and save, or 'Continue Recording' to keep going.")
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tips for Best Results")
                            .font(.headline)
                        Text("• Speak clearly and naturally\n• Works best in quiet environments\n• Commands work even when the app is in the background\n• May not work during phone calls or heavy audio playback\n• Always include \"in Road's Eye\" — Siri needs it to know which app to target")
                            .font(.body)
                    }

                    Text("Voice commands are powered by Apple's Siri (App Intents).")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Voice Commands")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}
