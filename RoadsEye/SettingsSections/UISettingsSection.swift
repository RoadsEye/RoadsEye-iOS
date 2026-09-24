import SwiftUI

struct UISettingsSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    let backgroundColor: Color
    let cardBackgroundColor: Color
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SettingsSection(title: "On-Screen Display", backgroundColor: backgroundColor, cardColor: cardBackgroundColor, viewModel: viewModel) {
            VStack(spacing: 1) {
                ToggleRow(
                    title: "Location",
                    isOn: $viewModel.isShowingLocation,
                    accentColor: accentColor,
                    viewModel: viewModel
                )
                Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))
                ToggleRow(
                    title: "Date",
                    isOn: $viewModel.isShowingDate,
                    accentColor: accentColor,
                    viewModel: viewModel
                )
                Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))
                ToggleRow(
                    title: "Time",
                    isOn: $viewModel.isShowingTime,
                    accentColor: accentColor,
                    viewModel: viewModel
                )
                Divider().background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3))
                ToggleRow(
                    title: "Speed",
                    isOn: $viewModel.isShowingSpeed,
                    accentColor: accentColor,
                    viewModel: viewModel
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
