import SwiftUI

// MARK: - Reusable Components
struct SettingsSection<Content: View>: View {
    let title: String
    let backgroundColor: Color
    let cardColor: Color
    let content: Content
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, backgroundColor: Color, cardColor: Color, viewModel: SettingsViewModel, @ViewBuilder content: () -> Content) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.cardColor = cardColor
        self.viewModel = viewModel
        self.content = content()
    }
   
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .padding(.leading, 4)
            content
        }
        .padding(.bottom, 16)
    }
}

struct SegmentedOptionView: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    let accentColor: Color
    @ObservedObject var viewModel: SettingsViewModel
    let parentSection: String
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, options: [String], selection: Binding<String>, accentColor: Color, viewModel: SettingsViewModel, parentSection: String = "") {
        self.title = title
        self.options = options
        self._selection = selection
        self.accentColor = accentColor
        self.viewModel = viewModel
        self.parentSection = parentSection
    }
   
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .padding(.leading, 4)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selection) { _, _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    let accentColor: Color
    @ObservedObject var viewModel: SettingsViewModel
    let parentSection: String
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, isOn: Binding<Bool>, isEnabled: Bool = true, accentColor: Color, viewModel: SettingsViewModel, parentSection: String = "") {
        self.title = title
        self._isOn = isOn
        self.isEnabled = isEnabled
        self.accentColor = accentColor
        self.viewModel = viewModel
        self.parentSection = parentSection
    }
   
    var body: some View {
        HStack {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .disabled(!isEnabled)
                .toggleStyle(SwitchToggleStyle(tint: accentColor))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

/// A tappable settings row with an optional subtitle and icon.
struct ActionRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    let accentColor: Color
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 22)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(accentColor)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

struct DisclaimerView: View {
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - clickable to expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(isExpanded ? "Hide Disclaimers" : "View Important Disclaimers & Safety Information")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(colorScheme == .dark ? Color(.systemGray6).opacity(0.3) : Color(.systemGray5).opacity(0.6))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content - only shown when expanded
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    disclaimerText(
                        "Use of this application is at your own risk. The developer assumes no liability for any damages, injuries, or legal consequences arising from its use. Ensure compliance with all applicable local, state, and federal laws, including those related to distracted driving."
                    )
                    
                    disclaimerText(
                        "All information provided by this app — including but not limited to location, date, time, speed, and other data — is approximate, may contain errors, and is provided 'AS IS' without any warranty of accuracy or reliability. Do NOT rely on this information for any critical decisions or purposes."
                    )
                    
                    disclaimerText(
                        "Not every option or feature may be supported depending on the device being used. Some cameras, sensors, or hardware capabilities may be required for full functionality."
                    )
                    
                    disclaimerText(
                        "During any mode — including Picture-in-Picture (PiP) mode — we cannot guarantee that every feature will work as intended."
                    )

                    disclaimerText(
                        "Road's Eye is now open source and no longer maintained. It is provided 'AS IS', free of charge, with no updates, support, or warranty of any kind. Versions built or modified by others are not endorsed or supported by Road's Eye."
                    )
                    
                    Spacer(minLength: 8)
                    
                    Text("The complete Terms of Service and Privacy Policy are stored in the app — open them above under More Information, no internet required.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.56, green: 0.79, blue: 0.98)) // ≈ #90CAF9
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(colorScheme == .dark ? Color(.systemGray5).opacity(0.6) : Color(.systemGray6).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorScheme == .dark ? Color(.systemGray4) : Color.gray.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private func disclaimerText(_ content: String) -> some View {
        Text(content)
            .font(.system(size: 12))
            .foregroundColor(.gray)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}
