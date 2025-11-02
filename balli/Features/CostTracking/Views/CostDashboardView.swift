import SwiftUI

struct CostDashboardView: View {
    @StateObject private var service = CostTrackingService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if service.isLoading {
                        ProgressView("Loading cost data...")
                            .padding()
                    } else if let error = service.error {
                        CostErrorView(message: error)
                    } else {
                        // Period summary cards
                        VStack(spacing: 16) {
                            if let today = service.todayReport {
                                CostSummaryCard(title: "Today", report: today, color: .blue)
                            }

                            if let week = service.weeklyReport {
                                CostSummaryCard(title: "This Week", report: week, color: .green)
                            }

                            if let month = service.monthlyReport {
                                CostSummaryCard(title: "This Month", report: month, color: .purple)
                            }
                        }
                        .padding(.horizontal)

                        // Feature comparison
                        if !service.featureComparison.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Cost by Feature (Last 7 Days)")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(service.featureComparison, id: \.feature) { feature in
                                    FeatureCostRow(feature: feature)
                                }
                            }
                            .padding(.top)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("API Cost Tracking")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await service.fetchAllReports()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await service.fetchAllReports()
        }
    }
}

struct CostSummaryCard: View {
    let title: String
    let report: CostReport
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                Text("$\(report.totalCost, specifier: "%.4f")")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(report.requestCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Avg/Request")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(report.averageCostPerRequest, specifier: "%.6f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            // Top 3 features
            if !report.byFeature.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Features:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(report.byFeature.sorted(by: { $0.value > $1.value }).prefix(3)), id: \.key) { feature, cost in
                        HStack {
                            Text(feature.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption)
                            Spacer()
                            Text("$\(cost, specifier: "%.4f")")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct FeatureCostRow: View {
    let feature: FeatureCostComparison

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.feature.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(feature.requestCount) requests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(feature.totalCost, specifier: "%.4f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("\(feature.percentOfTotal, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            // Progress bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(colorForFeature(feature.feature))
                    .frame(width: geometry.size.width * CGFloat(feature.percentOfTotal / 100), height: 4)
            }
            .frame(height: 4)
        }
        .cornerRadius(8)
    }

    private func colorForFeature(_ feature: String) -> Color {
        switch feature {
        case let f where f.contains("recipe"):
            return .blue
        case let f where f.contains("research"):
            return .purple
        case let f where f.contains("image"):
            return .green
        case let f where f.contains("nutrition"):
            return .orange
        case let f where f.contains("chat"):
            return .pink
        default:
            return .gray
        }
    }
}

struct CostErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Error Loading Costs")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview("Cost Dashboard") {
    CostDashboardView()
}

#Preview("Cost Summary Card") {
    CostSummaryCard(
        title: "Today",
        report: CostReport(
            period: "daily",
            startDate: "2025-11-02",
            endDate: "2025-11-02",
            totalCost: 0.0247,
            byFeature: [
                "recipe_generation": 0.0120,
                "research_deep_t3": 0.0090,
                "nutrition_calculation": 0.0037
            ],
            byModel: [
                "gemini-2.5-flash": 0.0157,
                "gemini-2.5-pro": 0.0090
            ],
            requestCount: 15,
            averageCostPerRequest: 0.001647
        ),
        color: .blue
    )
    .padding()
}

#Preview("Feature Cost Row") {
    FeatureCostRow(
        feature: FeatureCostComparison(
            feature: "recipe_generation",
            totalCost: 0.0120,
            requestCount: 8,
            averageCostPerRequest: 0.0015,
            percentOfTotal: 48.6
        )
    )
    .padding()
}
