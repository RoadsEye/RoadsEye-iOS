import SwiftUI

// MARK: - Open source details
enum OpenSourceInfo {
    static let repositoryURL = URL(string: "https://github.com/RoadsEye/RoadsEye-iOS")!
    static let repositoryDisplayText = "github.com/RoadsEye/RoadsEye-iOS"
}

// MARK: - Open source announcement
/// Shown on launch until the user picks "Don't show again". "OK" only hides it
/// for the current session. Re-openable any time from Settings → More Information.
struct OpenSourceNoticeView: View {
    @Binding var isPresented: Bool

    /// The automatic launch showing offers "Don't show again". Reopening it from
    /// Settings only needs a Close button.
    var isLaunchNotice: Bool = true

    @AppStorage("hideOpenSourceNotice") private var hideOpenSourceNotice: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private let accentColor = Color(red: 0.0, green: 0.68, blue: 1.0)

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.15) : .white
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {}   // Don't let a stray tap dismiss the note

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(accentColor)
                        .padding(.top, 26)

                    Text("Road's Eye Is Now Open Source")
                        .font(.title2.bold())
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)

                VStack(alignment: .leading, spacing: 14) {
                    Text("The full source code for Road's Eye is now public on GitHub. Anyone can read it, learn from it, build it themselves, or keep it going.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("From now on, there will most likely be no more updates. Check GitHub for more info.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(primaryTextColor)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        openURL(OpenSourceInfo.repositoryURL)
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text(OpenSourceInfo.repositoryDisplayText)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.footnote)
                        }
                        .foregroundColor(accentColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)

                Divider()
                    .background(Color.gray.opacity(0.25))

                VStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Text(isLaunchNotice ? "OK" : "Close")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if isLaunchNotice {
                        Button {
                            hideOpenSourceNotice = true
                            dismiss()
                        } label: {
                            Text("Don't show again")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: 440)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(accentColor.opacity(0.45), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
            .padding(.horizontal, 20)
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }
}

#Preview {
    OpenSourceNoticeView(isPresented: .constant(true))
}
