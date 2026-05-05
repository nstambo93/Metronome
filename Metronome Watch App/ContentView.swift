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
        ZStack(alignment: .topLeading) {
            // Main controls – fit without scrolling
            VStack(spacing: 6) {
                Spacer(minLength: 16) // push content down a bit to clear the gear icon

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
                        engine.updateBPM(newValue)
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

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)

            // Top‑left settings gear
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 12)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(engine: engine)
        }
    }
}
