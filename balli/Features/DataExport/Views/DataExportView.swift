//
//  DataExportView.swift
//  balli
//
//  Data export interface with date range and format selection
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct DataExportView: View {
    @StateObject private var viewModel = DataExportViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Quick date range selection
                    quickRangeSection

                    // Custom date range
                    customDateSection

                    // Data summary
                    if let summary = viewModel.dataSummary {
                        dataSummarySection(summary)
                    }

                    // Format selection
                    formatSelectionSection

                    // Export button
                    exportButtonSection

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Veri Dışa Aktar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingShareSheet) {
                if let url = viewModel.exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Doğrulama Hatası", isPresented: $viewModel.showingValidationError) {
                Button("Tamam", role: .cancel) {}
            } message: {
                if let message = viewModel.validationMessage {
                    Text(message)
                }
            }
            .task {
                await viewModel.validateExport()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sağlık Verilerinizi Dışa Aktarın", systemImage: "square.and.arrow.up")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Öğün, glikoz, insülin ve aktivite verilerinizi analiz için dışa aktarın.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    // MARK: - Quick Range Section

    private var quickRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hızlı Seçim")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(DateRangePeriod.allCases, id: \.self) { period in
                    Button {
                        viewModel.setDateRange(period)
                    } label: {
                        Text(period.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Custom Date Section

    private var customDateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Özel Tarih Aralığı")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Text("Başlangıç:")
                        .frame(width: 100, alignment: .leading)
                    DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: viewModel.startDate) { _, _ in
                            Task {
                                await viewModel.validateExport()
                            }
                        }
                }

                HStack {
                    Text("Bitiş:")
                        .frame(width: 100, alignment: .leading)
                    DatePicker("", selection: $viewModel.endDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: viewModel.endDate) { _, _ in
                            Task {
                                await viewModel.validateExport()
                            }
                        }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Date range info
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text("\(viewModel.dayCount) gün seçildi")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Data Summary Section

    private func dataSummarySection(_ summary: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Veri Özeti")
                .font(.headline)

            VStack(spacing: 8) {
                if let meals = summary["meals"] {
                    summaryRow(icon: "fork.knife", label: "Öğünler", value: "\(meals)")
                }

                if let glucose = summary["glucose_readings"] {
                    summaryRow(icon: "drop.fill", label: "Glikoz Ölçümleri", value: "\(glucose)")
                }

                if let insulin = summary["insulin_entries"] {
                    summaryRow(icon: "cross.vial", label: "İnsülin Kayıtları", value: "\(insulin)")
                }

                if let activity = summary["activity_days"] {
                    summaryRow(icon: "figure.walk", label: "Aktivite Günleri", value: "\(activity)")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppTheme.primaryPurple)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Format Selection Section

    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dışa Aktarma Formatı")
                .font(.headline)

            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button {
                    viewModel.selectedFormat = format
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: viewModel.selectedFormat == format ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedFormat == format ? AppTheme.primaryPurple : .secondary)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(format.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.selectedFormat == format ? AppTheme.primaryPurple.opacity(0.1) : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.selectedFormat == format ? AppTheme.primaryPurple : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Export Button Section

    private var exportButtonSection: some View {
        VStack(spacing: 12) {
            if viewModel.isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.exportProgress)
                        .progressViewStyle(.linear)
                        .tint(AppTheme.primaryPurple)

                    Text(viewModel.exportStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Button {
                    Task {
                        await viewModel.exportData()
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Dışa Aktar")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canExport ? AppTheme.primaryPurple : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canExport)

                if let message = viewModel.validationMessage, !viewModel.showingValidationError {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Default State") {
    DataExportView()
}
