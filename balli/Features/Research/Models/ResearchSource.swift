//
//  ResearchSource.swift
//  balli
//
//  Research source with credibility tracking
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Represents a research source cited in a search answer
struct ResearchSource: Identifiable, Codable, Sendable {
    let id: String
    let url: URL
    let domain: String
    let title: String
    let snippet: String?
    let publishDate: Date?
    let author: String?
    let credibilityBadge: CredibilityType?
    let faviconURL: URL?

    enum CredibilityType: String, Codable, Sendable {
        case peerReviewed = "Bilimsel Kaynak"
        case medicalSource = "Sağlık Kaynağı"
        case majorNews = "Güvenilir Haber"
        case government = "Resmi Kaynak"
        case academic = "Akademik"
    }

    /// Analyze domain for credibility
    static func analyzeDomain(_ url: URL) -> CredibilityType? {
        let domain = url.host?.lowercased() ?? ""

        // Medical/health sources
        if domain.contains("nih.gov") || domain.contains("who.int") ||
           domain.contains("mayoclinic.org") || domain.contains("cdc.gov") ||
           domain.contains("saglik.gov.tr") {
            return .government
        }

        // Peer-reviewed databases
        if domain.contains("pubmed") || domain.contains("scholar.google") ||
           domain.contains("sciencedirect") || domain.contains("ncbi.nlm.nih.gov") {
            return .peerReviewed
        }

        // Academic institutions
        if domain.hasSuffix(".edu") {
            return .academic
        }

        // Medical sources
        if domain.contains("webmd") || domain.contains("healthline") ||
           domain.contains("medscape") {
            return .medicalSource
        }

        return nil
    }

    /// Generate favicon URL from domain
    static func generateFaviconURL(from url: URL) -> URL? {
        guard let host = url.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=32")
    }
}
