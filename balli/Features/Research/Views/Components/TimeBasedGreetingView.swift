//
//  TimeBasedGreetingView.swift
//  balli
//
//  Time-based greeting with icon for research welcome screen
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct TimeBasedGreetingView: View {
    @ObservedObject private var userManager = UserProfileSelector.shared
    @State private var currentGreeting = GreetingType.current()

    var body: some View {
        Text("\(currentGreeting.text) \(userManager.currentUserDisplayName)")
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.balliGradient)
            .multilineTextAlignment(.center)
            .onAppear {
                // Update greeting when view appears
                currentGreeting = GreetingType.current()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Update greeting when app becomes active
                currentGreeting = GreetingType.current()
            }
    }
}

// MARK: - Greeting Type

enum GreetingType {
    case morning    // 06:00-12:00
    case afternoon  // 12:00-18:00
    case evening    // 18:00-22:00
    case night      // 22:00-06:00

    var text: String {
        switch self {
        case .morning:
            return "Günaydın"
        case .afternoon:
            return "İyi günler"
        case .evening:
            return "İyi akşamlar"
        case .night:
            return "İyi geceler"
        }
    }

    /// Determines current greeting based on current time
    static func current() -> GreetingType {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6..<12:
            return .morning
        case 12..<18:
            return .afternoon
        case 18..<22:
            return .evening
        default:
            return .night
        }
    }
}

// MARK: - Previews

#Preview("Current Time Greeting") {
    VStack {
        Spacer()
        TimeBasedGreetingView()
        Spacer()
    }
}

#Preview("All Time Periods - Dilara") {
    VStack(spacing: 32) {
        ForEach([GreetingType.morning, .afternoon, .evening, .night], id: \.text) { greeting in
            Text("\(greeting.text) Dilara")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.balliGradient)
        }
    }
    .padding()
}

#Preview("Morning - Serhat") {
    let greeting = GreetingType.morning
    VStack {
        Spacer()
        Text("\(greeting.text) Serhat")
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.balliGradient)
        Spacer()
    }
}

#Preview("In Research View") {
    NavigationStack {
        InformationRetrievalView()
    }
}
