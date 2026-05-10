import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var bpm: Double = {
        let saved = UserDefaults.standard.object(forKey: "defaultBPM") as? Double
        return saved ?? 180
    }()
    @State private var showSettings = false
    @State private var showInfo = false

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
                        $bpm,
                        from: 120.0,
                        through: 200.0,
                        by: 5.0,
                        sensitivity: .medium,
                        isContinuous: true,
                        isHapticFeedbackEnabled: false
                    )
                    .onChange(of: bpm) { oldValue, newValue in
                        let rounded = round(newValue / 5) * 5
                        let clamped = min(max(rounded, 120), 200)
                        if clamped != bpm {
                            bpm = clamped
                        }
                        engine.updateBPM(clamped)
                    }

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
