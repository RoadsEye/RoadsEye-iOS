import SwiftUI

struct OtherSettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    let backgroundColor: Color
    let cardBackgroundColor: Color
    let accentColor: Color
    @State private var showingOverlayInfo = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SettingsSection(title: "Other Settings", backgroundColor: backgroundColor, cardColor: cardBackgroundColor, viewModel: viewModel) {
            VStack(spacing: 1) {
                // Appearance Toggle (New - as requested)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Appearance")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.leading, 4)
                    
                    Picker("Appearance", selection: $viewModel.selectedAppearance) {
                        Text("System").tag("System")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))
                
                // Driving Overlay Mode with Descriptive Text and Info Button
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        ToggleRow(
                            title: "Driving Overlay Mode",
                            isOn: Binding(
                                get: { viewModel.isDrivingOverlayEnabled },
                                set: { newValue in
                                    viewModel.isDrivingOverlayEnabled = newValue
                                    if !newValue {
                                        viewModel.isOverlayAlwaysActive = false // Reset dependent setting
                                    }
                                }
                            ),
                            accentColor: accentColor,
                            viewModel: viewModel,
                            parentSection: "Other Settings"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: {
                            print("Info button tapped") // Debug log
                            showingOverlayInfo = true
                        }) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(accentColor) // Match AudioSettingsSection
                                .font(.system(size: 20))
                        }
                        .padding(.trailing, 8) // Match AudioSettingsSection
                        .contentShape(Rectangle())
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))

                if viewModel.isDrivingOverlayEnabled {
                    ToggleRow(
                        title: "Overlay Always Active",
                        isOn: $viewModel.isOverlayAlwaysActive,
                        accentColor: accentColor,
                        viewModel: viewModel,
                        parentSection: "Other Settings"
                    )
                    Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))
                }

                HStack {
                    Text("Speed Units")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Spacer()
                    Picker("", selection: $viewModel.selectedSpeedUnits) {
                        ForEach(["KM/H", "MPH"], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 220)
                    .onChange(of: viewModel.selectedSpeedUnits) { _, _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingOverlayInfo) {
            DrivingOverlayInfoView()
        }
    }
}

struct DrivingOverlayInfoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Driving Overlay Mode Info")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    Text("Driving Overlay Mode provides a visual overlay on your dashcam screen to assist with driving and recording. Here's how it works:")
                        .font(.body)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. Driving Overlay Mode")
                            .font(.headline)
                        Text("When enabled, this mode displays an overlay when the vehicle is in motion (requires location permissions). The overlay hides when the vehicle is stationary, as long as recording is active.")
                            .font(.body)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("2. Overlay Always Active")
                            .font(.headline)
                        Text("When enabled, the overlay is shown continuously from the start to the stop of recording, regardless of vehicle motion. This does not require location permissions.")
                            .font(.body)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("3. Interacting with the Overlay")
                            .font(.headline)
                        Text("Tap the screen during recording to temporarily hide the overlay.")
                            .font(.body)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tips for Best Results")
                            .font(.headline)
                        Text("• Ensure location permissions are granted for Driving Overlay Mode.\n• Use Overlay Always Active for continuous display without motion detection.\n• Adjust settings based on your recording needs.")
                            .font(.body)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitle("Driving Overlay Mode", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}
