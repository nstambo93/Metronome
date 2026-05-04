//
//  MetronomeEngine.swift
//  Metronome Watch App
//
//  Created by Nick Stamboolian on 5/4/26.
//

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

    // HealthKit workout session (keeps app alive during run)
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private let woodblockURL: URL? = {
        // Make sure the filename & extension match your actual file
        Bundle.main.url(forResource: "woodblock", withExtension: "m4a")
    }()

    override init() {
        super.init()
        configureAudioSession()
        prepareAudioPlayer()
        observeRouteChanges()
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
            self.useAudio = self.isHeadphonesConnected()
        }
    }

    // MARK: - Start / Stop
    func start(bpm: Double) {
        self.bpm = bpm
        useAudio = isHeadphonesConnected()
        startWorkoutSession()
        startTimer()
        isRunning = true
    }

    func stop() {
        timer?.cancel()
        timer = nil
        stopWorkoutSession()
        isRunning = false
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

    // MARK: - HKWorkoutSession (keeps app alive, saves minimal workout)
    private func startWorkoutSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor   // change to .indoor if you prefer

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
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: endDate) { [weak self] (success, error) in
            if success {
                self?.workoutBuilder?.finishWorkout { (workout, error) in
                    if let error = error { print("Finish workout error: \(error)") }
                }
            }
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
