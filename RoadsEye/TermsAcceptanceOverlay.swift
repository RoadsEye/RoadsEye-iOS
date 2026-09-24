import SwiftUI

struct TermsAcceptanceOverlay: View {
    
    @Binding var isPresented: Bool
    
    let currentTermsVersion: String
    let currentPrivacyVersion: String
    
    // Checkbox states
    @State private var termsAccepted = false
    @State private var privacyAccepted = false

    // Written through @AppStorage rather than UserDefaults directly, so the
    // launch gate in RoadsEyeApp sees the change and swaps this overlay out.
    @AppStorage("didAcceptTermsAndPrivacy") private var didAcceptTermsAndPrivacy: Bool = false
    @AppStorage("acceptedTermsVersion") private var acceptedTermsVersion: String = ""
    @AppStorage("acceptedPrivacyVersion") private var acceptedPrivacyVersion: String = ""


    // Loaded from the bundled copies — same source the in-app viewer in
    // Settings uses, so the two can never drift apart.
    private var termsText: String { LegalDocument.terms.text }

    private var privacyText: String { LegalDocument.privacy.text }

    var bothAccepted: Bool {
        termsAccepted && privacyAccepted
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {}   // Prevent accidental dismiss
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 48)
                    
                    Text("Welcome to Road's Eye")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text("Please review and accept our policies to continue")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    // ── Terms of Service section ───────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Terms of Service")
                            .font(.title3.bold())
                        
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(termsText)
                                .font(.body)
                                .lineSpacing(6)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 240)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // ── Privacy Policy section ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy Policy")
                            .font(.title3.bold())
                        
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(privacyText)
                                .font(.body)
                                .lineSpacing(6)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 240)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // ── Checkboxes ─────────────────────────────────────────────
                    // Plain buttons rather than Toggles: the whole row is the
                    // tap target, so acceptance can't be blocked by a switch
                    // that is hard to hit.
                    acceptanceRow(
                        title: "I accept the Terms of Service",
                        isAccepted: $termsAccepted
                    )

                    acceptanceRow(
                        title: "I accept the Privacy Policy",
                        isAccepted: $privacyAccepted
                    )
                    
                    // ── Continue button ────────────────────────────────────────
                    Button {
                        acceptTerms()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                bothAccepted ? Color.accentColor : Color.gray
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!bothAccepted)
                    .padding(.horizontal, 40)
                    
                    Spacer(minLength: 60)
                }
                .padding(.vertical, 20)
            }
            .background(Color(UIColor.systemBackground))
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
    
    @ViewBuilder
    private func acceptanceRow(title: String, isAccepted: Binding<Bool>) -> some View {
        Button {
            isAccepted.wrappedValue.toggle()
            print("TermsAcceptanceOverlay: \(title) → \(isAccepted.wrappedValue)")
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isAccepted.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isAccepted.wrappedValue ? Color.accentColor : Color.secondary)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    private func acceptTerms() {
        print("TermsAcceptanceOverlay: accepted \(currentTermsVersion)/\(currentPrivacyVersion)")

        acceptedTermsVersion = currentTermsVersion
        acceptedPrivacyVersion = currentPrivacyVersion
        didAcceptTermsAndPrivacy = true

        isPresented = false
    }
}
