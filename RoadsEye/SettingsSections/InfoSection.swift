import SwiftUI

struct InfoSection: View {
    @ObservedObject var viewModel: SettingsViewModel
    let backgroundColor: Color
    let cardBackgroundColor: Color
    let accentColor: Color

    @Environment(\.colorScheme) private var colorScheme

    @State private var legalDocumentToShow: LegalDocument?
    @State private var showOpenSourceNotice = false

    var body: some View {
        SettingsSection(
            title: "More Information",
            backgroundColor: backgroundColor,
            cardColor: cardBackgroundColor,
            viewModel: viewModel
        ) {
            VStack(spacing: 1) {
                // Legal documents are read straight from the app bundle — no
                // website needed, and they keep working after roadseye.com is
                // retired.
                ActionRow(
                    title: "Terms of Service",
                    subtitle: "Read the full terms inside the app",
                    accentColor: accentColor
                ) {
                    legalDocumentToShow = .terms
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider().background(Color.white.opacity(0.08))

                ActionRow(
                    title: "Privacy Policy",
                    subtitle: "Read the full policy inside the app",
                    accentColor: accentColor
                ) {
                    legalDocumentToShow = .privacy
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider().background(Color.white.opacity(0.08))

                ActionRow(
                    title: "Source Code on GitHub",
                    subtitle: "No more updates are planned. Check GitHub for news.",
                    accentColor: accentColor
                ) {
                    UIApplication.shared.open(OpenSourceInfo.repositoryURL)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider().background(Color.white.opacity(0.08))

                ActionRow(
                    title: "Open Source Announcement",
                    subtitle: "Road's Eye is now open source",
                    accentColor: accentColor
                ) {
                    showOpenSourceNotice = true
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider().background(Color.white.opacity(0.08))

                // No support or feedback contact: support ends with the app,
                // so there is nowhere for a message to land.

                HStack {
                    Text("App Version")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Spacer()
                    Text(Bundle.main.appVersionAndBuild)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            DisclaimerView()
        }
        .sheet(item: $legalDocumentToShow) { document in
            LegalDocumentsView(initialDocument: document)
        }
        .fullScreenCover(isPresented: $showOpenSourceNotice) {
            OpenSourceNoticeView(isPresented: $showOpenSourceNotice, isLaunchNotice: false)
                .presentationBackground(.clear)
        }
    }
}
