//
//  NotificationSettingsView.swift
//  balli
//
//  Notification settings placeholder view
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct NotificationSettingsView: View {
    var body: some View {
        Form {
            Section("Bildirim Türleri") {
                Toggle("Kan Şekeri Hatırlatıcıları", isOn: .constant(true))
                Toggle("Öğün Hatırlatıcıları", isOn: .constant(true))
                Toggle("İlaç Hatırlatıcıları", isOn: .constant(false))
            }

            Section("Zaman Ayarları") {
                DatePicker("Sabah Hatırlatıcı", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                DatePicker("Akşam Hatırlatıcı", selection: .constant(Date()), displayedComponents: .hourAndMinute)
            }
        }
        .navigationTitle("Bildirim Ayarları")
        .navigationBarTitleDisplayMode(.inline)
    }
}
