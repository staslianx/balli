//
//  ActivitySyncSection.swift
//  balli
//
//  Activity data sync UI component for settings
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct ActivitySyncSection: View {
    let isBackfilling: Bool
    let backfillProgress: Double
    let backfillStatus: String
    let onRefresh: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Activity History", systemImage: "figure.walk")
                .font(.headline)

            if let backfillDate = UserDefaults.standard.object(forKey: "ActivityBackfillDate") as? Date,
               let backfillDays = UserDefaults.standard.object(forKey: "ActivityBackfillDays") as? Int {

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(backfillDays) days of historical data")
                            .font(.subheadline)
                        Text("Last synced: \(backfillDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else {
                Text("No historical data synced yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                Task {
                    await onRefresh()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Sync Last 90 Days")
                }
            }
            .disabled(isBackfilling)
            .buttonStyle(.bordered)
            .tint(AppTheme.primaryPurple)

            if isBackfilling {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: backfillProgress)
                    Text(backfillStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}
