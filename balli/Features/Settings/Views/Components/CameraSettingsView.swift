//
//  CameraSettingsView.swift
//  balli
//
//  Camera settings placeholder view
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct CameraSettingsView: View {
    var body: some View {
        Form {
            Section("Kamera Kalitesi") {
                Picker("Kalite", selection: .constant("Yüksek")) {
                    Text("Yüksek").tag("Yüksek")
                    Text("Orta").tag("Orta")
                    Text("Düşük").tag("Düşük")
                }
                .pickerStyle(.segmented)
            }

            Section("AI Analiz") {
                Toggle("Gelişmiş Analiz", isOn: .constant(true))
                Toggle("Güven Skoru Göster", isOn: .constant(true))
            }
        }
        .navigationTitle("Kamera Ayarları")
        .navigationBarTitleDisplayMode(.inline)
    }
}
