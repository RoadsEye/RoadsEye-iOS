import SwiftUI
import AVFoundation
import CoreMotion

// MARK: - Camera Preview Layer
struct CameraPreviewLayer: UIViewRepresentable {
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            backgroundColor = .clear	
        }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.backgroundColor = UIColor.clear.cgColor

        updateOrientationForCurrentDevice(for: view.videoPreviewLayer)
        context.coordinator.previewView = view
        context.coordinator.startDeviceOrientationMonitoring()

        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        updateOrientationForCurrentDevice(for: uiView.videoPreviewLayer)
        uiView.videoPreviewLayer.frame = uiView.bounds
    }
    
    private func updateOrientationForCurrentDevice(for previewLayer: AVCaptureVideoPreviewLayer) {
        let interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .portrait
        
        let rotationAngle = fixedRotationAngleMapping(interfaceOrientation)
        
        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }
    
    private func fixedRotationAngleMapping(_ orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:           return 90
        case .portraitUpsideDown: return 270
        case .landscapeLeft:      return 180
        case .landscapeRight:     return 0
        default:                  return 90
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        let parent: CameraPreviewLayer
        weak var previewView: PreviewView?
        private var motionManager: CMMotionManager?
        private var orientationObserver: NSObjectProtocol?

        init(parent: CameraPreviewLayer) {
            self.parent = parent
            super.init()
        }

        deinit {
            stopDeviceOrientationMonitoring()
        }

        func startDeviceOrientationMonitoring() {
            orientationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleOrientationChange()
            }

            if motionManager == nil {
                motionManager = CMMotionManager()
            }

            if let motionManager = motionManager, motionManager.isDeviceMotionAvailable {
                motionManager.deviceMotionUpdateInterval = 0.5
                motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                    guard let self = self, let motion = motion, error == nil else { return }
                    if UIDevice.current.orientation == .faceUp || UIDevice.current.orientation == .faceDown {
                        self.handleOrientationChangeWithMotion(motion)
                    }
                }
            }
        }

        func stopDeviceOrientationMonitoring() {
            if let observer = orientationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            motionManager?.stopDeviceMotionUpdates()
        }

        /// Rotates ONLY the on-screen preview. The recording output must stay
        /// at the sensor's native orientation — rotating its connection used to
        /// corrupt the saved video's orientation when the device was rotated.
        private func applyPreviewRotation(for orientation: UIInterfaceOrientation) {
            let rotationAngle = parent.fixedRotationAngleMapping(orientation)

            DispatchQueue.main.async { [weak self] in
                guard let connection = self?.previewView?.videoPreviewLayer.connection,
                      connection.isVideoRotationAngleSupported(rotationAngle) else { return }
                connection.videoRotationAngle = rotationAngle
            }
        }

        private func handleOrientationChange() {
            let interfaceOrientation = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.interfaceOrientation ?? .portrait

            applyPreviewRotation(for: interfaceOrientation)
        }

        private func handleOrientationChangeWithMotion(_ motion: CMDeviceMotion) {
            let gravity = motion.gravity
            var orientation: UIInterfaceOrientation = .portrait

            if abs(gravity.x) > abs(gravity.y) {
                orientation = gravity.x > 0 ? .landscapeRight : .landscapeLeft
            } else {
                orientation = gravity.y > 0 ? .portraitUpsideDown : .portrait
            }

            applyPreviewRotation(for: orientation)
        }
    }
}

// MARK: - Driving Overlay
struct DrivingOverlayView: View {
    @AppStorage("isDrivingOverlayEnabled") private var isDrivingOverlayEnabled: Bool = true
    @AppStorage("isOverlayAlwaysActive") private var isOverlayAlwaysActive: Bool = false
    @Binding var isRecording: Bool
    @ObservedObject private var locationSpeedManager = LocationSpeedManager.shared
    
    @State private var isVisible: Bool = true
    @State private var shouldShowOverlay: Bool = false
    
    private func computeShouldShowOverlay() -> Bool {
        if isOverlayAlwaysActive && isRecording {
            return true
        }
        let speedThreshold = 1.0
        return isDrivingOverlayEnabled && locationSpeedManager.speed >= speedThreshold && isRecording
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if shouldShowOverlay && isVisible {
                VStack(spacing: 12) {
                    Text("Driving Overlay Mode Active")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("Keep app in foreground during recording")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(Color.black.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(shouldShowOverlay && isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: shouldShowOverlay)
        .onTapGesture {
            withAnimation { isVisible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { isVisible = true }
            }
        }
        .onChange(of: isRecording) { _, _ in
            shouldShowOverlay = computeShouldShowOverlay()
        }
        .onChange(of: locationSpeedManager.speed) { _, _ in
            shouldShowOverlay = computeShouldShowOverlay()
        }
    }
}

// MARK: - Camera Preview Content
struct CameraPreviewContent: View {
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        Group {
            if sessionManager.isSessionRunning {
                if let session = sessionManager.captureSession {
                    CameraPreviewLayer(session: session)
                        .background(Color.clear)
                        .zIndex(-1)
                } else {
                    Text("Session is nil")
                        .foregroundColor(.red)
                }
            } else {
                ProgressView()
            }
        }
    }
}

// MARK: - Main CameraView
struct CameraView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @Binding var isRecording: Bool
    @Environment(\.scenePhase) private var scenePhase

    @State private var isSetupComplete = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreviewContent(sessionManager: sessionManager)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .edgesIgnoringSafeArea(.all)

                DrivingOverlayView(isRecording: $isRecording)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .edgesIgnoringSafeArea(.all)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .edgesIgnoringSafeArea(.all)
        }
        .ignoresSafeArea()
        .onAppear {
            if !isSetupComplete {
                sessionManager.setupAndRequestPermissions()
                isSetupComplete = true
            } else if !sessionManager.isSessionRunning {
                sessionManager.handleAppActive()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            switch newValue {
            case .active:
                if isSetupComplete {
                    sessionManager.handleAppActive()
                }
            case .background:
                sessionManager.handleAppBackground()
            default:
                break
            }
        }
        .onChange(of: isRecording) { oldValue, newValue in
            if newValue && !oldValue {
                sessionManager.startRecording()
            } else if !newValue && oldValue {
                sessionManager.stopRecording()
            }
        }
    }
}
