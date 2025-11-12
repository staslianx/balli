//
//  InsulinHistoryView.swift
//  balli
//
//  Complete insulin log history showing both meal-connected and standalone entries
//  Displays NovoRapid (bolus), Lantus (basal), and all other insulin types
//  Design language matches LoggedMealsView for consistency
//

import SwiftUI
import CoreData
import OSLog

struct InsulinHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedEntry: MedicationEntry?
    @State private var showEditSheet = false
    @State private var entryToDelete: MedicationEntry?
    @State private var showDeleteConfirmation = false

    // Fetch all medication entries (insulin) sorted by timestamp (newest first)
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \MedicationEntry.timestamp, ascending: false)
        ],
        animation: .default
    )
    private var medicationEntries: FetchedResults<MedicationEntry>

    // Group entries by date (calendar day)
    private var groupedEntries: [(date: Date, entries: [MedicationEntry])] {
        let byDay = Dictionary(grouping: medicationEntries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }

        return byDay
            .map { (date: $0.key, entries: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.date > $1.date }
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.anaxoniclabs.balli",
        category: "InsulinHistory"
    )

    var body: some View {
        NavigationStack {
            Group {
                if groupedEntries.isEmpty {
                    ContentUnavailableView(
                        "Henüz insülin kaydı yok",
                        systemImage: "syringe",
                        description: Text("Sesle kaydettiğin insülin dozları burada görünecek.")
                    )
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.primaryPurple)
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedEntries, id: \.date) { dateGroup in
                            dayCard(for: dateGroup)
                                .listRowInsets(EdgeInsets(
                                    top: ResponsiveDesign.Spacing.small,
                                    leading: ResponsiveDesign.Spacing.medium,
                                    bottom: ResponsiveDesign.Spacing.small,
                                    trailing: ResponsiveDesign.Spacing.medium
                                ))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("İnsülin Geçmişi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let entry = selectedEntry {
                    InsulinEditSheet(medication: entry)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .alert("İnsülin Kaydını Sil", isPresented: $showDeleteConfirmation) {
                Button("İptal", role: .cancel) {
                    entryToDelete = nil
                }
                Button("Sil", role: .destructive) {
                    deleteEntry()
                }
            } message: {
                if let entry = entryToDelete {
                    Text("\(entry.medicationName) kaydını silmek istediğinden emin misin? Bu işlem geri alınamaz.")
                }
            }
        }
    }

    // MARK: - Delete Entry

    private func deleteEntry() {
        guard let entry = entryToDelete else { return }

        logger.info("🗑️ Deleting insulin entry: \(entry.medicationName) - \(Int(entry.dosage)) units")

        viewContext.delete(entry)

        do {
            try viewContext.save()
            logger.info("✅ Insulin entry deleted successfully")
        } catch {
            logger.error("❌ Failed to delete insulin entry: \(error.localizedDescription)")
        }

        entryToDelete = nil
    }

    // MARK: - Day Card View (Matches LoggedMealsView)

    @ViewBuilder
    private func dayCard(for dateGroup: (date: Date, entries: [MedicationEntry])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header at top left inside card
            Text(formatDateForHeader(dateGroup.date))
                .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.top, ResponsiveDesign.Spacing.medium)
                .padding(.bottom, ResponsiveDesign.Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Divider below date
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)

            // All insulin entries for this day
            VStack(spacing: ResponsiveDesign.Spacing.xSmall) {
                ForEach(dateGroup.entries) { entry in
                    insulinEntryRow(entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEntry = entry
                            showEditSheet = true
                        }
                        .onLongPressGesture {
                            entryToDelete = entry
                            showDeleteConfirmation = true
                        }

                    // Divider between entries (except last one)
                    if entry.id != dateGroup.entries.last?.id {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    }
                }
            }
            .padding(.vertical, ResponsiveDesign.Spacing.small)
        }
        .background(Color.white.opacity(0.05))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
    }

    // MARK: - Insulin Entry Row (Matches meal group row style)

    private func insulinEntryRow(_ entry: MedicationEntry) -> some View {
        let insulinTypeIcon = entry.isBasalInsulin ? "slowmo" : "chevron.forward.dotted.chevron.forward"
        let insulinTypeColor = AppTheme.primaryPurple

        return HStack(spacing: ResponsiveDesign.Spacing.small) {
            // Insulin type icon
            Image(systemName: insulinTypeIcon)
                .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold))
                .foregroundStyle(insulinTypeColor)
                .frame(width: ResponsiveDesign.Font.scaledSize(32), alignment: .center)

            // Insulin details
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                Text(entry.medicationName)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                // Time only (date is shown in card header)
                Text(entry.timestamp, format: .dateTime.hour().minute())
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(13), weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right-aligned metrics (insulin dosage only)
            HStack(spacing: 4) {
                Image(systemName: "microbe.fill")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .medium))
                    .foregroundStyle(AppTheme.primaryPurple)

                Text("\(Int(entry.dosage))")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryPurple)
            }
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .padding(.vertical, ResponsiveDesign.Spacing.small)
    }

    // MARK: - Helper Functions

    /// Formats date header in Turkish format (e.g., "24 Ekim Cuma 2025")
    private func formatDateForHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM EEEE yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    InsulinHistoryView()
        .environment(\.managedObjectContext, PersistenceController.previewFast.container.viewContext)
}
