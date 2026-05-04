//
//  ContentView.swift
//  Metronome Watch App
//
//  Created by Nick Stamboolian on 5/4/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var engine = MetronomeEngine()
    @State private var bpm: Double = 180

    var body: some View {
        VStack(spacing: 16) {
            Text("\(Int(bpm)) BPM")
                .font(.largeTitle)
                .fontWeight(.bold)

            Slider(value: $bpm, in: 120...200, step: 1) {
                Text("BPM")
            }
            .padding(.horizontal)

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

            // Small status indicator
            Text(engine.isRunning ? "Ticking..." : "Ready")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
    }
}

