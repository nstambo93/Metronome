//
//  SettingsView.swift
//  Metronome Watch App
//
//  Created by Nick Stamboolian on 5/4/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var engine: MetronomeEngine
    @AppStorage("defaultBPM") private var defaultBPM: Double = 180

    var body: some View {
        Form {
            // Default BPM (new)
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default BPM")
                        .font(.caption)
                    HStack {
                        Button(action: {
                            defaultBPM = max(120, defaultBPM - 5)
                        }) {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("\(Int(defaultBPM))")
                            .frame(minWidth: 50)

                        Button(action: {
                            defaultBPM = min(200, defaultBPM + 5)
                        }) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Haptic‑Only toggle (existing)
            Section {
                Toggle(isOn: $engine.forceHapticOnly) {
                    Text("Haptic Only")
                        .font(.caption)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Always use haptics, even with headphones connected.")
                    .font(.caption2)
            }
        }
        .navigationTitle("Settings")
    }
}
