//
//  DataPrivacyView.swift
//  balli
//
//  Data privacy information view
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct DataPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                Text("Veri Güvenliği")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text("balli uygulaması verilerini güvenle saklar:")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
                    DataPrivacyRow(icon: "lock.shield", title: "Yerel Depolama", description: "Tüm veriler cihazında saklanır")
                    DataPrivacyRow(icon: "eye.slash", title: "Gizlilik", description: "Kişisel veriler paylaşılmaz")
                    DataPrivacyRow(icon: "key", title: "Şifreleme", description: "Veriler şifrelenerek korunur")
                }

                Spacer(minLength: ResponsiveDesign.Spacing.large)
            }
            .padding()
        }
        .navigationTitle("Veri & Gizlilik")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper Component

struct DataPrivacyRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppTheme.primaryPurple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
