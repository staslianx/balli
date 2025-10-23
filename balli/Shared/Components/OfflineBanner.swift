//
//  OfflineBanner.swift
//  balli
//
//  Simple offline indicator banner for user feedback
//

import SwiftUI

/// Banner that appears when the app is offline
struct OfflineBanner: View {
    // PERFORMANCE: Direct domain state access (not through AppState delegation)
    @EnvironmentObject private var networkState: NetworkState

    var body: some View {
        if networkState.isOfflineMode {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)

                Text("Offline Mode")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)

                if networkState.pendingOperationsCount > 0 {
                    Text("•")
                        .foregroundStyle(.white.opacity(0.5))

                    Text("\(networkState.pendingOperationsCount) pending")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Text("Viewing cached data")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange.gradient)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(duration: 0.4), value: networkState.isOfflineMode)
        }
    }
}

/// Compact offline indicator for toolbars
struct OfflineIndicator: View {
    // PERFORMANCE: Direct domain state access (not through AppState delegation)
    @EnvironmentObject private var networkState: NetworkState

    var body: some View {
        if networkState.isOfflineMode {
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 10))
                Text("Offline")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: networkState.isOfflineMode)
        }
    }
}

#Preview("Offline Banner - Offline") {
    VStack {
        OfflineBanner()
            .environmentObject({
                let state = NetworkState.shared
                Task { @MainActor in
                    state.isOfflineMode = true
                    state.pendingOperationsCount = 3
                }
                return state
            }())

        Spacer()
    }
}

#Preview("Offline Banner - Online") {
    VStack {
        OfflineBanner()
            .environmentObject({
                let state = NetworkState.shared
                Task { @MainActor in
                    state.isOfflineMode = false
                }
                return state
            }())

        Spacer()
    }
}

#Preview("Offline Indicator") {
    OfflineIndicator()
        .environmentObject({
            let state = NetworkState.shared
            Task { @MainActor in
                state.isOfflineMode = true
            }
            return state
        }())
        .padding()
}
