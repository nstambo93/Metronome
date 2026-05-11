import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var bpm: Double = {
        let saved = UserDefaults.standard.object(forKey: "defaultBPM") as? Double
        return saved ?? 180
    }()
    @State private var showSettings = false
    @State private var showInfo = false
    @State private var showPicker = false

    // Two‑step deliberate‑turn detection
    @State private var crownValue: Double = 0          // value coming from the crown (never shows on UI)
    @State private var crownTravel: Double = 0          // total absolute movement since last reset
    @State private var crownTurnedOnce = false          // true after first successful turn
    @State private var crownTimer: Timer?

    private let turnThreshold = 5.0                    // detents required for one "deliberate turn"

    var body: some View {
        ZStack {
            VStack(spacing: 6) {
                Spacer(minLength: 8)

                // BPM label – tap to open picker, crown for two‑step open
                Button {
                    showPicker = true
                    resetCrownState()
                } label: {
                    Text("\(Int(bpm)) BPM")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(true)                         // enables green focus ring when crown active
                .digitalCrownRotation(
                    $crownValue,
                    from: 0.0,
                    through: 10000.0,                    // huge range – no wrap during normal use
                    by: 1.0,
                    sensitivity: .medium,
                    isContinuous: true,                  // live updates, no scroll bar
                    isHapticFeedbackEnabled: false
                )
                .onChange(of: crownValue) { oldValue, newValue in
                    // compute how many detents were just turned (absolute value)
                    let delta = abs(newValue - oldValue)
                    // ignore huge jumps that might be initialisation or glitches
                    guard delta < 1000 else { return }

                    crownTravel += delta

                    if crownTravel >= turnThreshold {
                        // one deliberate turn completed
                        if crownTurnedOnce {
                            // second turn → open the picker
                            showPicker = true
                            resetCrownState()
                        } else {
                            // first turn → mark intent and start timer
                            crownTurnedOnce = true
                            startCrownTimer()
                        }
                        crownTravel = 0                // reset for next turn
                    }
                }

                // Start/Stop Button
                Button {
                    if engine.isRunning {
                        engine.stop()
                    } else {
                        engine.start(bpm: bpm)
                    }
                } label: {
                    Text(engine.isRunning ? "Stop" : "Start")
                        .font(.title3)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(engine.isRunning ? Color.red : Color.green)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())

                // Status Message
                Text(engine.isRunning ? (engine.forceHapticOnly ? "Tapping (haptic)" : "Ticking...") : "Ready")
                    .foregroundColor(.secondary)
                    .font(.caption2)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)

            // Bottom‑left: Info button
            VStack {
                Spacer()
                HStack {
                    Button {
                        showInfo.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
                    Spacer()
                }
            }

            // Bottom‑right: Settings button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showSettings.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $showInfo) { InfoView() }
        .sheet(isPresented: $showSettings) { SettingsView(engine: engine) }
        .sheet(isPresented: $showPicker) { BPMPickerView(selectedBPM: $bpm, isPresented: $showPicker) }
    }

    // MARK: - Crown helpers

    private func resetCrownState() {
        crownTravel = 0
        crownTurnedOnce = false
        crownTimer?.invalidate()
        crownTimer = nil
    }

    private func startCrownTimer() {
        crownTimer?.invalidate()
        // If no second turn within 3 seconds, forget the first turn
        crownTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                self.crownTurnedOnce = false
            }
        }
    }
}
