import UIKit

class IdleTimerManager {
    static let shared = IdleTimerManager()
    
    private var isIdleTimerDisabled: Bool = false
    private var idleTimerObserver: NSObjectProtocol?
    private var reinforcementTimer: Timer?
    
    // MARK: - Log Throttling
    private var lastReinforceLogTime: Date = Date.distantPast
    private let reinforceLogThrottleInterval: TimeInterval = 3.0  // Limit reinforcement spam
    
    private init() {
        setupIdleTimerObserver()
        disableIdleTimer(reason: "IdleTimerManager initialization")
    }
    
    deinit {
        if let observer = idleTimerObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopReinforcementTimer()
    }
    
    func disableIdleTimer(reason: String) {
        isIdleTimerDisabled = true
        updateIdleTimerState()
        startReinforcementTimer()
        print("IdleTimerManager: Idle timer disabled - Reason: \(reason)")
    }
    
    func enableIdleTimer(reason: String) {
        isIdleTimerDisabled = false
        updateIdleTimerState()
        stopReinforcementTimer()
        print("IdleTimerManager: Idle timer enabled - Reason: \(reason)")
    }
    
    func reinforceIdleTimer(reason: String) {
        guard isIdleTimerDisabled else { return }
        
        let now = Date()
        if now.timeIntervalSince(lastReinforceLogTime) > reinforceLogThrottleInterval {
            print("IdleTimerManager: Idle timer reinforced - Reason: \(reason)")
            lastReinforceLogTime = now
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    private func updateIdleTimerState() {
        DispatchQueue.main.async {
            let currentState = UIApplication.shared.isIdleTimerDisabled
            if currentState != self.isIdleTimerDisabled {
                print("IdleTimerManager: State mismatch detected - Expected: \(self.isIdleTimerDisabled), Actual: \(currentState)")
            }
            UIApplication.shared.isIdleTimerDisabled = self.isIdleTimerDisabled
        }
    }
    
    private func setupIdleTimerObserver() {
        idleTimerObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.isIdleTimerDisabled && !UIApplication.shared.isIdleTimerDisabled {
                print("IdleTimerManager: Unexpected idle timer change detected on scene activation")
                self.disableIdleTimer(reason: "Scene activation recovery")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.isIdleTimerDisabled && !UIApplication.shared.isIdleTimerDisabled {
                print("IdleTimerManager: Unexpected idle timer change detected on orientation change")
                self.disableIdleTimer(reason: "Orientation change recovery")
            }
        }
    }
    
    private func startReinforcementTimer() {
        if reinforcementTimer == nil {
            reinforcementTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.reinforceIdleTimer(reason: "Periodic reinforcement")
            }
            RunLoop.main.add(reinforcementTimer!, forMode: .common)
        }
    }
    
    private func stopReinforcementTimer() {
        reinforcementTimer?.invalidate()
        reinforcementTimer = nil
    }
}
