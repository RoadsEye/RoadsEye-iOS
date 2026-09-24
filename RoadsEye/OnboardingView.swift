import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("tutorialShown") var tutorialShown: Bool = false
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: nil,
            title: "Welcome to Road’s Eye",
            description: """
            Your personal dashcam that records continuously and protects every drive.

            • Automatic video recording
            • Instant clip saving
            • Crash detection ready
            """
        ),
        OnboardingPage(
            imageName: "onboarding_start",
            title: "Easy Recording",
            description: """
            • Tap the big red button to start/stop recording
            • Videos save automatically
            • Gear icon opens settings
            """
        ),
        OnboardingPage(
            imageName: "onboarding_stop_and_clip",
            title: "Save Important Moments",
            description: """
            • Blue CLIP button instantly saves the last 1–3 minutes
            • Crash Detection auto-saves on impact
            • Oldest clips are deleted when storage is full
            """
        ),
        OnboardingPage(
            imageName: nil,
            title: "Keep the App Running",
            description: """
            For reliable recording:

            • Road’s Eye must stay in the foreground (iOS Policies)
            • Keep your screen on while driving
            """
        )
    ]
    
    var body: some View {
        VStack {
            // Top bar with Skip
            HStack {
                Spacer()
                Button(action: {
                    tutorialShown = true
                }) {
                    Text("Skip")
                        .foregroundColor(.gray)
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                }
            }
            
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    PageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            Spacer()
            
            // Next / Get Started
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    tutorialShown = true
                }
            }) {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
    }
}

struct PageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if let imageName = page.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .padding()
            } else {
                Spacer().frame(height: 80) // Balance layout when no image
            }
            
            Text(page.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct OnboardingPage {
    let imageName: String?
    let title: String
    let description: String
}
