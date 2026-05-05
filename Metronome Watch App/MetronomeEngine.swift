import Foundation
import AVFAudio
import WatchKit
import HealthKit
import Combine

class MetronomeEngine: NSObject, ObservableObject {
    @Published var isRunning = false
    private var timer: DispatchSourceTimer?
    private var bpm: Double = 180
    private var audioPlayer: AVAudioPlayer?
    private var useAudio = false
    // Haptic toggle
    @Published var forceHapticOnly: Bool = UserDefaults.standard.bool(forKey: "forceHapticOnly") {
        didSet {
            UserDefaults.standard.set(forceHapticOnly, forKey: "forceHapticOnly")
            updateUseAudio()
        }
    }

    // Silent background audio (AVAudioEngine) – proven to keep session alive when minimized
    private var audioEngine: AVAudioEngine?
    private var silentNode: AVAudioPlayerNode?

    // HealthKit workout session
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private let woodblockURL: URL? = {
        Bundle.main.url(forResource: "woodblock", withExtension: "m4a")
    }()

    override init() {
        super.init()
        configureAudioSession()
        prepareAudioPlayer()
        observeRouteChanges()
        updateUseAudio()   // Ensures audio/haptic state matches saved toggle
    }

    // MARK: - Audio session (simple playback, mixes with music)
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }

    private func prepareAudioPlayer() {
        guard let url = woodblockURL else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.prepareToPlay()
        audioPlayer?.volume = 0.8
    }

    // MARK: - Route detection
    private func isHeadphonesConnected() -> Bool {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        for output in currentRoute.outputs {
            let port = output.portType
            if port == .bluetoothA2DP || port == .bluetoothLE ||
               port == .bluetoothHFP || port == .headphones {
                return true
            }
        }
        return false
    }

    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func audioRouteChanged(notification: Notification) {
        DispatchQueue.main.async {
            // Haptic toggle
            self.updateUseAudio()
//            self.useAudio = self.isHeadphonesConnected()
        }
    }

    // MARK: - Start / Stop (with HealthKit authorization)
    func start(bpm: Double) {
        self.bpm = bpm
        // Haptic toggle
        updateUseAudio()
//        useAudio = isHeadphonesConnected()
        requestHealthKitAuthorization { [weak self] authorized in
            guard let self = self, authorized else {
                print("HealthKit authorization denied")
                return
            }
            self.startWorkoutSession()
            self.startTimer()
            self.startSilentBackgroundAudio()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        stopWorkoutSession()
        stopSilentBackgroundAudio()
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    // MARK: - Timer & Beat
    private func startTimer() {
        let interval = 60.0 / bpm
        let queue = DispatchQueue(label: "metronome.timer", qos: .userInteractive)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
        timer?.setEventHandler { [weak self] in
            self?.tick()
        }
        timer?.resume()
    }

    private func tick() {
        if useAudio {
            audioPlayer?.currentTime = 0
            audioPlayer?.play()
        } else {
            DispatchQueue.main.async {
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    // MARK: - Silent background audio (AVAudioEngine – proven on watchOS)
    private func startSilentBackgroundAudio() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)

        // Create a short silent buffer that matches the player's output format
        let sampleRate = 44100.0
        let duration = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        // Important: use the player node's output format to avoid channel count mismatch
        let mixerFormat = player.outputFormat(forBus: 0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: mixerFormat, frameCapacity: frameCount) else {
            print("Failed to create silent buffer")
            return
        }
        buffer.frameLength = frameCount
        // buffer is already zeroed (silent)

        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)

        do {
            try engine.start()
        } catch {
            print("Silent engine start error: \(error.localizedDescription)")
            return
        }

        player.play()

        audioEngine = engine
        silentNode = player

        // Listen for interruptions (widgets, calls) so we can restart
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private func stopSilentBackgroundAudio() {
        silentNode?.stop()
        silentNode = nil
        audioEngine?.stop()
        audioEngine = nil

        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .ended {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isRunning else { return }
                // Restart the silent engine after interruption ends
                self.stopSilentBackgroundAudio()
                self.startSilentBackgroundAudio()
            }
        }
    }

    // MARK: - HealthKit authorization (asks once, then remembers)
    private func requestHealthKitAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        let workoutType = HKObjectType.workoutType()
        healthStore.requestAuthorization(toShare: [workoutType], read: []) { success, error in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // MARK: - HKWorkoutSession (keeps app alive)
    private func startWorkoutSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore,
                                                  configuration: config)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
        } catch {
            print("Workout session error: \(error)")
            return
        }

        workoutSession?.delegate = self
        workoutBuilder?.delegate = self

        let startDate = Date()
        workoutSession?.startActivity(with: startDate)
        workoutBuilder?.beginCollection(withStart: startDate) { (success, error) in
            if let error = error { print("Builder start error: \(error)") }
        }
    }

    private func stopWorkoutSession() {
        let endDate = Date()
        workoutSession?.stopActivity(with: endDate)
        workoutBuilder?.endCollection(withEnd: endDate) { [weak self] (success, error) in
            if success {
                // Discard the workout – it will NOT be saved to Health
                self?.workoutBuilder?.discardWorkout()
            }
        }
        workoutSession?.end()
    }
    
    // Haptic toggle
    private func updateUseAudio() {
        useAudio = !forceHapticOnly && isHeadphonesConnected()
    }
    
    func updateBPM(_ newBPM: Double) {
        guard newBPM > 0 else { return }
        bpm = newBPM
        // Only restart the timer – keep workout session and silent audio alive
        if isRunning {
            timer?.cancel()
            startTimer()
        }
    }
}

// MARK: - HKWorkoutSessionDelegate & HKLiveWorkoutBuilderDelegate
extension MetronomeEngine: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {}

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
