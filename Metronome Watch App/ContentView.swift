//
//  ContentView.swift
//  Metronome Watch App
//
//  Created by Nick Stamboolian on 5/4/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var bpm: Double = {
        let saved = UserDefaults.standard.object(forKey: "defaultBPM") as? Double
        return saved ?? 180
    }()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 8)

            // BPM display – large, focusable for crown
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
                    // Force step to multiples of 5
                    let rounded = round(newValue / 5) * 5
                    let clamped = min(max(rounded, 120), 200)
                    if clamped != bpm {
                        bpm = clamped
                    }
                    engine.updateBPM(clamped)
                }

            // +/- buttons (step 5)
            HStack(spacing: 16) {
                Button {
                    bpm = max(120, bpm - 5)
                    engine.updateBPM(bpm)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    bpm = min(200, bpm + 5)
                    engine.updateBPM(bpm)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Start / Stop
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

            // Status
            Text(engine.isRunning ? (engine.forceHapticOnly ? "Tapping (haptic)" : "Ticking...") : "Ready")
                .foregroundColor(.secondary)
                .font(.caption2)

            // Settings button (gear + text) – at the bottom
            Button {
                showSettings.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .sheet(isPresented: $showSettings) {
            SettingsView(engine: engine)
        }
    }
}
