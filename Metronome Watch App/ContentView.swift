//
//  ContentView.swift
//  Metronome Watch App
//
//  Created by Nick Stamboolian on 5/4/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    // Read default BPM from UserDefaults on first launch
    @State private var bpm: Double = {
        let saved = UserDefaults.standard.object(forKey: "defaultBPM") as? Double
        return saved ?? 180
    }()
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Large BPM display – focusable, crown‑adjustable
                Text("\(Int(bpm)) BPM")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .focusable(true)
                    .digitalCrownRotation(
                        $bpm,
                        from: 120.0,
                        through: 200.0,
                        by: 5.0,
                        sensitivity: .low,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                    .onChange(of: bpm) { oldValue, newValue in
                        engine.updateBPM(newValue)
                    }

                // Manual +/- buttons (step 5)
                HStack(spacing: 24) {
                    Button(action: {
                        bpm = max(120, bpm - 5)
                        engine.updateBPM(bpm)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        bpm = min(200, bpm + 5)
                        engine.updateBPM(bpm)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Start / Stop
                Button(action: {
                    if engine.isRunning {
                        engine.stop()
                    } else {
                        engine.start(bpm: bpm)
                    }
                }) {
                    Text(engine.isRunning ? "Stop" : "Start")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(engine.isRunning ? Color.red : Color.green)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // Status
                Text(engine.isRunning ? (engine.forceHapticOnly ? "Tapping (haptic)" : "Ticking...") : "Ready")
                    .foregroundColor(.secondary)
                    .font(.caption)

                // Settings button
                Button(action: {
                    showSettings.toggle()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(engine: engine)
        }
    }
}
