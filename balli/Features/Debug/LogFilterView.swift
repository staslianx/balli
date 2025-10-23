//
//  LogFilterView.swift
//  balli
//
//  Filtering UI component for memory decision logs
//

import SwiftUI

/// Header view containing search and filter controls
public struct LogFilterHeaderView: View {
    @Binding var searchText: String
    @Binding var selectedOperationType: String
    let operationTypes: [String]
    let statistics: LogStatistics
    
    public var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Filter picker
            Picker("Operation Type", selection: $selectedOperationType) {
                ForEach(operationTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Statistics bar
            LogStatisticsView(statistics: statistics)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
}

/// Statistics display view
public struct LogStatisticsView: View {
    let statistics: LogStatistics
    
    public var body: some View {
        HStack(spacing: 20) {
            StatisticCard(
                title: "Total Sessions",
                value: "\(statistics.totalSessions)",
                icon: "chart.bar.fill",
                color: .blue
            )
            
            StatisticCard(
                title: "Avg Duration",
                value: String(format: "%.2fs", statistics.averageDuration),
                icon: "clock.fill",
                color: .green
            )
            
            StatisticCard(
                title: "Cache Hit Rate",
                value: "\(statistics.cacheHitRate)%",
                icon: "bolt.fill",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
}

/// Individual statistic card
public struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    public var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

/// Statistics data model
public struct LogStatistics {
    public let totalSessions: Int
    public let averageDuration: TimeInterval
    public let cacheHitRate: Int
    
    public init(totalSessions: Int, averageDuration: TimeInterval, cacheHitRate: Int) {
        self.totalSessions = totalSessions
        self.averageDuration = averageDuration
        self.cacheHitRate = cacheHitRate
    }
}