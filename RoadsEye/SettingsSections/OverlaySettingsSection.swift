import SwiftUI

struct OverlaySettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    let backgroundColor: Color
    let cardBackgroundColor: Color
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SettingsSection(title: "Overlay Settings", backgroundColor: backgroundColor, cardColor: cardBackgroundColor, viewModel: viewModel) {
            VStack(spacing: 1) {
                ToggleRow(
                    title: "Embed Information in Recording",
                    isOn: $viewModel.embedOverlayInVideo,
                    accentColor: accentColor,
                    viewModel: viewModel
                )
                
                Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))
                
                SegmentedOptionView(
                    title: "Overlay Quality",
                    options: ["Low", "Medium", "High"],
                    selection: $viewModel.overlayQuality,
                    accentColor: accentColor,
                    viewModel: viewModel
                )
                
                Text("Note: Overlay quality may increase battery usage and recording save time.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
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
