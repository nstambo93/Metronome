//
//  InfoView.swift
//  Metronome
//
//  Created by Nick Stamboolian on 5/5/26.
//

import SwiftUI

struct InfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("How the Metronome Works")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Headphones connected: woodblock audio click.", systemImage: "airpodspro")
                    Label("No headphones: silent haptic tap on wrist.", systemImage: "hand.tap")
                    Label("Silent Mode stops the audible tick from haptics.", systemImage: "bell.slash")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Divider()

                Text("Tips")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("• Default BPM can be set in Settings.")
                    Text("• If 'Haptic Only' is on, no audio plays even with headphones.")
                    Text("• The metronome works completely offline.")
                    Text("• The Digital Crown changes BPM in steps of 5.")
                }
                .font(.caption)
                .foregroundColor(.secondary)    
            }
            .padding()
        }
        .navigationTitle("Info")
    }
}
