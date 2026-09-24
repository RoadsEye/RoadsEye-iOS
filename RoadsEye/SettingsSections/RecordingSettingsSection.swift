import SwiftUI

struct RecordingSettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    let backgroundColor: Color
    let cardBackgroundColor: Color
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme

    @State private var showCrashDetectionAlert: Bool = false

    var body: some View {
        SettingsSection(title: "Recording Settings", backgroundColor: backgroundColor, cardColor: cardBackgroundColor, viewModel: viewModel) {
            mainContent
        }
        .alert(isPresented: $showCrashDetectionAlert) {
            Alert(
                title: Text("Disable Crash Detection?"),
                message: Text("Are you sure you want to turn off Crash Detection? This feature can help by automatically detecting and saving clips of potential accidents."),
                primaryButton: .destructive(Text("Disable")) {
                    viewModel.isCrashDetectionEnabled = false
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: viewModel.isCrashDetectionEnabled) { _, newValue in
            if !newValue {
                showCrashDetectionAlert = true
            }
        }
    }
    
    // MARK: - Extracted Content to Fix Type-Checking
    private var mainContent: some View {
        VStack(spacing: 1) {
            recordingSegmentLengthRow
            Divider().background(dividerColor)
            
            maximumStorageRow
            Divider().background(dividerColor)
            
            crashDetectionRow
            Divider().background(dividerColor)
            
            autoRecordSection
        }
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dividerColor, lineWidth: 1)
        )
    }
    
    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3)
    }
    
    private var recordingSegmentLengthRow: some View {
        SegmentedOptionView(
            title: "Recording Segment Length",
            options: ["1m", "2m", "3m"],
            selection: $viewModel.selectedClipDuration,
            accentColor: accentColor,
            viewModel: viewModel,
            parentSection: "Recording Settings"
        )
    }
    
    private var maximumStorageRow: some View {
        SegmentedOptionView(
            title: "Maximum Storage",
            options: ["2GB", "5GB", "10GB"],
            selection: $viewModel.maxStorageLimit,
            accentColor: accentColor,
            viewModel: viewModel,
            parentSection: "Recording Settings"
        )
    }
    
    private var crashDetectionRow: some View {
        ToggleRow(
            title: "Crash Detection (BETA)",
            isOn: $viewModel.isCrashDetectionEnabled,
            accentColor: accentColor,
            viewModel: viewModel,
            parentSection: "Recording Settings"
        )
    }
    
    private var autoRecordSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Auto Record")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isAutoRecording)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: accentColor))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if viewModel.isAutoRecording {
                autoRecordOptions
            }
        }
    }
    
    private var autoRecordOptions: some View {
        VStack(spacing: 1) {
            Divider().background(dividerColor)
            
            SliderRow(
                title: "Speed Threshold",
                value: $viewModel.autoRecordSpeedThreshold,
                range: 1...10,
                step: 1,
                units: viewModel.selectedSpeedUnits,
                accentColor: accentColor
            )

            Divider().background(dividerColor)

            SliderRow(
                title: "Duration Threshold",
                value: $viewModel.autoRecordDurationThreshold,
                range: 1...10,
                step: 1,
                units: "sec",
                accentColor: accentColor
            )
            
            Text("Recording starts automatically when speed exceeds threshold for the specified duration.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Reusable Slider Row
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let units: String
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(colorScheme == .dark ? .white : .black)

            Spacer()

            Text("\(Int(value))")
                .foregroundColor(.gray)

            Slider(value: $value, in: range, step: step)
                .frame(width: 120)
                .accentColor(accentColor)

            Text(units)
                .foregroundColor(.gray)
                .frame(width: 45, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
