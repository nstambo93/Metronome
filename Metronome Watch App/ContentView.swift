import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var bpm: Double = {
        let saved = UserDefaults.standard.object(forKey: "defaultBPM") as? Double
        return saved ?? 180
    }()
    @State private var showSettings = false
    @State private var showInfo = false
    
    private var crownBinding: Binding<Double> {
        Binding<Double>(
            get: { bpm },
            set: { newValue in
                let step = 5.0
                let minBPM = 120.0
                let maxBPM = 200.0

                // Snap to nearest multiple of step, then clamp
                let snapped = round(min(max(newValue, minBPM), maxBPM) / step) * step
                let clamped = min(max(snapped, minBPM), maxBPM)

                // Detect wrap‑around by comparing with the current bpm
                // (the last valid snapped value stored in bpm)
                let delta = abs(clamped - bpm)
                if delta > step * 2 {
                    // Crown wrapped – stay at the boundary
                    if bpm >= maxBPM - step {
                        bpm = maxBPM
                    } else if bpm <= minBPM + step {
                        bpm = minBPM
                    }
                    engine.updateBPM(bpm)
                    return
                }

                // Normal change – accept the snapped & clamped value
                if clamped != bpm {
                    bpm = clamped
                    engine.updateBPM(clamped)
                }
            }
        )
    }
    
    var body: some View {
        ZStack {
            // Main controls – unchanged
            VStack(spacing: 6) {
                Spacer(minLength: 8)

                Text("\(Int(bpm)) BPM")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .focusable(true)
                    .digitalCrownRotation(
                        crownBinding,      // use the custom binding instead of $bpm
                        from: 120.0,
                        through: 200.0,
                        by: 5.0,
                        sensitivity: .medium,
                        isContinuous: true,
                        isHapticFeedbackEnabled: true // FIXME: Taps when decrementing/incrementing at min/max
                    )

//                HStack(spacing: 16) {
//                    Button {
//                        bpm = max(120, bpm - 5)
//                        engine.updateBPM(bpm)
//                    } label: {
//                        Image(systemName: "minus.circle.fill")
//                            .font(.title2)
//                    }
//                    .buttonStyle(PlainButtonStyle())
//
//                    Button {
//                        bpm = min(200, bpm + 5)
//                        engine.updateBPM(bpm)
//                    } label: {
//                        Image(systemName: "plus.circle.fill")
//                            .font(.title2)
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }

//              Start/Stop Button
                Button {
                    if engine.isRunning {
                        engine.stop()
                    } else {
                        engine.start(   bpm: bpm)
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

//              Status Message
                Text(engine.isRunning ? (engine.forceHapticOnly ? "Tapping (haptic)" : "Ticking...") : "Ready")
                    .foregroundColor(.secondary)
                    .font(.caption2)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)

            // Bottom‑left: Info button (white "i" inside a circle)
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

            // Bottom‑right: Settings button (gear only, same circular style)
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
        .sheet(isPresented: $showInfo) {
            InfoView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(engine: engine)
        }
    }
}
