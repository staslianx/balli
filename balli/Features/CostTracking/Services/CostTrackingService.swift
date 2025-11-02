import Foundation

@MainActor
class CostTrackingService: ObservableObject {
    @Published var todayReport: CostReport?
    @Published var weeklyReport: CostReport?
    @Published var monthlyReport: CostReport?
    @Published var featureComparison: [FeatureCostComparison] = []
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL: String

    init(baseURL: String = "https://us-central1-balli-diabetes-assistant.cloudfunctions.net") {
        self.baseURL = baseURL
    }

    func fetchTodayCosts() async {
        await fetchReport(endpoint: "getTodayCosts") { report in
            self.todayReport = report
        }
    }

    func fetchWeeklyCosts() async {
        await fetchReport(endpoint: "getWeeklyCosts") { report in
            self.weeklyReport = report
        }
    }

    func fetchMonthlyCosts() async {
        await fetchReport(endpoint: "getMonthlyCosts") { report in
            self.monthlyReport = report
        }
    }

    func fetchFeatureComparison(days: Int = 7) async {
        isLoading = true
        error = nil

        guard let url = URL(string: "\(baseURL)/getFeatureCosts?days=\(days)") else {
            error = "Invalid URL"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(FeatureCostsResponse.self, from: data)

            if response.success {
                featureComparison = response.data
            } else {
                error = "Failed to fetch feature costs"
            }
        } catch {
            self.error = "Network error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func fetchAllReports() async {
        await fetchTodayCosts()
        await fetchWeeklyCosts()
        await fetchMonthlyCosts()
        await fetchFeatureComparison()
    }

    private func fetchReport(endpoint: String, completion: @escaping (CostReport) -> Void) async {
        isLoading = true
        error = nil

        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            error = "Invalid URL"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(CostReportResponse.self, from: data)

            if response.success {
                completion(response.data)
            } else {
                error = "Failed to fetch cost report"
            }
        } catch {
            self.error = "Network error: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
