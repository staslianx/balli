//
//  LoggedMealsView.swift
//  balli
//
//  Voice‑logged meals history grouped by date
//

import SwiftUI

struct LoggedMealsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch all meal entries sorted by timestamp (newest first)
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: false)
        ],
        animation: .default
    )
    private var mealEntries: FetchedResults<MealEntry>

    // Group entries by date (calendar day)
    private var groupedEntries: [(date: Date, meals: [MealEntry])] {
        let grouped = Dictionary(grouping: mealEntries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }

        return grouped
            .map { (date: $0.key, meals: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Helper Functions

    /// Returns appropriate SF symbol for meal type
    private func symbolForMealType(_ mealType: String) -> String {
        let normalizedType = mealType.lowercased()

        switch normalizedType {
        case "kahvaltı":
            return "sun.max"
        case "öğle yemeği":
            return "sun.max.fill"
        case "akşam yemeği":
            return "fork.knife"
        case "ara öğün":
            return "circle.hexagongrid"
        default:
            return "fork.knife"
        }
    }

    /// Formats date header in Turkish format (e.g., "16 Ekim 2025 Perşembe")
    private func formatDateForHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy EEEE"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if groupedEntries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.day.timeline.left")
                            .font(.system(size: 40, weight: .regular))
                            .foregroundStyle(AppTheme.primaryPurple)

                        Text("Henüz kayıtlı öğün yok")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Sesle kaydettiğin öğünler burada görünecek.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(groupedEntries, id: \.date) { dateGroup in
                            Section {
                                ForEach(dateGroup.meals) { entry in
                                    mealEntryRow(entry)
                                }
                            } header: {
                                dateGroupHeader(for: dateGroup.date)
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground(for: colorScheme))
            .navigationTitle("Günlük Kayıtlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Date Group Header

    @ViewBuilder
    private func dateGroupHeader(for date: Date) -> some View {
        VStack(alignment: .center, spacing: 0) {
            Text(formatDateForHeader(date))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)

            Divider()
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Meal Entry Row

    @ViewBuilder
    private func mealEntryRow(_ entry: MealEntry) -> some View {
        HStack(spacing: 12) {
            // Meal type icon
            Image(systemName: symbolForMealType(entry.mealType))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.primaryPurple)
                .frame(width: 32, alignment: .center)

            // Meal details
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.mealType.capitalized)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                // Time only (date is shown in header)
                Text(entry.timestamp, format: .dateTime.hour().minute())
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right-aligned carbohydrate badge
            if entry.consumedCarbs > 0 {
                Text("\(Int(entry.consumedCarbs)) gr")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppTheme.primaryPurple.gradient)
                    )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .listRowInsets(EdgeInsets())
    }
}

#Preview {
    LoggedMealsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
