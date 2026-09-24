import SwiftUI

// MARK: - Bundled legal documents
/// The Terms of Service and Privacy Policy ship inside the app bundle, so they
/// stay readable after roadseye.com goes offline. Nothing here touches the
/// network.
enum LegalDocument: String, CaseIterable, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms:   return "Terms of Service"
        case .privacy: return "Privacy Policy"
        }
    }

    /// Short label for the segmented picker.
    var shortTitle: String {
        switch self {
        case .terms:   return "Terms"
        case .privacy: return "Privacy"
        }
    }

    private var resourceName: String {
        switch self {
        case .terms:   return "ToS"
        case .privacy: return "PrivacyPolicy"
        }
    }

    /// Full text straight from the bundle. Falls back to a plain message rather
    /// than pointing at a website that will not be there.
    var text: String {
        guard let path = Bundle.main.path(forResource: resourceName, ofType: "txt"),
              let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "\(title) could not be loaded from this copy of the app.\n\nReinstalling Road's Eye from the App Store will restore it."
        }
        return text
    }
}

// MARK: - Viewer
struct LegalDocumentsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selected: LegalDocument

    private let accentColor = Color(red: 0.0, green: 0.68, blue: 1.0)

    init(initialDocument: LegalDocument = .terms) {
        _selected = State(initialValue: initialDocument)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.15) : Color(.systemGray6)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Document", selection: $selected) {
                        ForEach(LegalDocument.allCases) { document in
                            Text(document.shortTitle).tag(document)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    ScrollView {
                        Text(selected.text)
                            .font(.callout)
                            .lineSpacing(5)
                            .textSelection(.enabled)
                            .foregroundColor(colorScheme == .dark ? Color(white: 0.92) : Color(white: 0.15))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(cardBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                    // Jump back to the top when switching documents.
                    .id(selected)
                }
            }
            .navigationTitle(selected.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(accentColor)
                }
            }
        }
    }
}

#Preview {
    LegalDocumentsView()
}
