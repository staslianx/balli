import Foundation

struct CostReport: Codable {
    let period: String
    let startDate: String
    let endDate: String
    let totalCost: Double
    let byFeature: [String: Double]
    let byModel: [String: Double]
    let requestCount: Int
    let averageCostPerRequest: Double
}

struct CostReportResponse: Codable {
    let success: Bool
    let data: CostReport
    let formatted: String?
}

struct FeatureCostComparison: Codable {
    let feature: String
    let totalCost: Double
    let requestCount: Int
    let averageCostPerRequest: Double
    let percentOfTotal: Double
}

struct FeatureCostsResponse: Codable {
    let success: Bool
    let data: [FeatureCostComparison]
}
