import SwiftUI

struct VideoSettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    let backgroundColor: Color
    let cardBackgroundColor: Color
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SettingsSection(title: "Video Settings", backgroundColor: backgroundColor, cardColor: cardBackgroundColor, viewModel: viewModel) {
            VStack(spacing: 1) {
                // Video Resolution
                VStack(alignment: .leading, spacing: 10) {
                    Text("Video Resolution")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.leading, 4)

                    Picker("Video Resolution", selection: $viewModel.selectedQuality) {
                        Text("Low").tag("Low")
                        Text("Medium").tag("Medium")
                        Text("High").tag("High")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: viewModel.selectedQuality) { _, _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))

                // Frames Per Second
                SegmentedOptionView(
                    title: "Frames Per Second",
                    options: ["15", "30", "60"],
                    selection: $viewModel.selectedFPS,
                    accentColor: accentColor,
                    viewModel: viewModel,
                    parentSection: "Video Settings"
                )

                Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))

                // Camera Zoom
                SegmentedOptionView(
                    title: "Camera Zoom",
                    options: ["0.5x", "1x", "2x"],
                    selection: $viewModel.selectedFOV,
                    accentColor: accentColor,
                    viewModel: viewModel,
                    parentSection: "Video Settings"
                )
            }
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
