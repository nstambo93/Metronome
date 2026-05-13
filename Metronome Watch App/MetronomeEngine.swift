//
//  MetronomeEngine.swift
//  Metronome Watch App
//
//  Created by Nick Stamboolian on 5/4/26.
//

import Foundation
import AVFAudio
import WatchKit
import Combine

class MetronomeEngine: NSObject, ObservableObject {
    @Published var isRunning = false
    private var timer: DispatchSourceTimer?
    private var bpm: Double = 180
    private var audioPlayer: AVAudioPlayer?
    private var useAudio = false
    private var extendedSession: WKExtendedRuntimeSession?

    // Haptic toggle – persisted in UserDefaults
    @Published var forceHapticOnly: Bool = UserDefaults.standard.bool(forKey: "forceHapticOnly") {
        didSet {
            UserDefaults.standard.set(forceHapticOnly, forKey: "forceHapticOnly")
            updateUseAudio()
        }
    }

    // Silent background audio (AVAudioEngine) – keeps session alive when minimized
    private var audioEngine: AVAudioEngine?
    private var silentNode: AVAudioPlayerNode?

    private let woodblockURL: URL? = {
        Bundle.main.url(forResource: "woodblock", withExtension: "m4a")
    }()

    override init() {
        super.init()
        configureAudioSession()
        prepareAudioPlayer()
        observeRouteChanges()
        updateUseAudio()   // apply the saved haptic preference on launch
    }

    // MARK: - Audio session
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
            self.updateUseAudio()

            guard self.isRunning else { return }

            // Stop the current silent engine immediately (it's likely dead)
            self.stopSilentBackgroundAudio()

            // Wait a moment for the audio route to settle, then restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard self.isRunning else { return }
                self.startSilentBackgroundAudio()
            }
        }
    }

    // MARK: - Start / Stop (with Extended Runtime Session, no HealthKit)
    func start(bpm: Double) {
        self.bpm = bpm
        updateUseAudio()
        startTimer()
        startSilentBackgroundAudio()   // keep app alive in background via audio
        startExtendedSession()         // primary background guarantee
        isRunning = true
    }

    func stop() {
        timer?.cancel()
        timer = nil
        stopExtendedSession()
        stopSilentBackgroundAudio()
        isRunning = false
    }

    // MARK: - Extended Runtime Session (Physical Therapy type – no HealthKit, no conflicts)
    private func startExtendedSession() {
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()
    }

    private func stopExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }

    // MARK: - Timer & Beat
    private func startTimer() {
        let interval = 60.0 / bpm
        let queue = DispatchQueue(label: "metronome.timer", qos: .userInteractive)
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
        timer?.setEventHandler { [weak self] in
            self?.tick()
            // Keep the silent engine alive – restart if it died
            if self?.audioEngine?.isRunning == false && self?.isRunning == true {
                self?.stopSilentBackgroundAudio()
                self?.startSilentBackgroundAudio()
            }
        }
        timer?.resume()
    }

    private func tick() {
        if useAudio {
            audioPlayer?.currentTime = 0
            audioPlayer?.play()
        } else {
            DispatchQueue.main.async {
                WKInterfaceDevice.current().play(.start) //(.click)
            }
        }
    }

    // MARK: - Silent background audio (keeps session alive, resilient to interruptions)
    private func startSilentBackgroundAudio() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)

        // Inaudible low‑frequency tone to keep audio session alive
        let sampleRate: Double = 44100
        let frequency: Double = 10.0        // Hz – well below human hearing
        let amplitude: Float = 0.0001       // near zero, inaudible
        let duration: Double = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        let format = player.outputFormat(forBus: 0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("Failed to create tone buffer")
            return
        }
        buffer.frameLength = frameCount

        // Generate sine wave samples
        let channelData = buffer.floatChannelData?[0]
        for i in 0..<Int(frameCount) {
            let sample = sin(2.0 * .pi * frequency * Double(i) / sampleRate)
            channelData?[i] = Float(sample) * amplitude
        }

        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)

        // Force session active before starting engine
        try? AVAudioSession.sharedInstance().setActive(true)

        do {
            try engine.start()
            print("Silent engine started successfully")
            // Ensure session remains active after engine start
            try? AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Silent engine start error: \(error.localizedDescription)")
            return
        }

        player.play()

        audioEngine = engine
        silentNode = player

        // Interruption handler
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
                self.stopSilentBackgroundAudio()
                self.startSilentBackgroundAudio()
            }
        }
    }

    // MARK: - BPM & haptic logic
    private func updateUseAudio() {
        useAudio = !forceHapticOnly && isHeadphonesConnected()
    }

    func updateBPM(_ newBPM: Double) {
        guard newBPM > 0 else { return }
        bpm = newBPM
        if isRunning {
            timer?.cancel()
            startTimer()
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension MetronomeEngine: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Renew the session if the metronome is still running (for runs longer than 1 hour)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isRunning else { return }
//            self.stopExtendedSession()
            self.startExtendedSession()
        }
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        // Unexpected invalidation – restart if still running
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.startExtendedSession()
        }
    }
}
