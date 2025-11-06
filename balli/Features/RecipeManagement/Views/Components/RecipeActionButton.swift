//
//  RecipeActionButton.swift
//  balli
//
//  Reusable glass button with icon and label for recipe actions
//  Used for Cook, Save, Share, and other recipe operations
//

import SwiftUI

/// Action type for recipe detail buttons
enum RecipeAction {
    case save
    case favorite
    case values
    case notes
    case shopping
    case timer
    case edit

    var icon: String {
        switch self {
        case .save: return "star"
        case .favorite: return "star"
        case .values: return "checkmark.seal.text.page"
        case .notes: return "note.text"
        case .shopping: return "basket"
        case .timer: return "timer"
        case .edit: return "pencil"
        }
    }

    var filledIcon: String {
        switch self {
        case .save: return "star.fill"
        case .favorite: return "star.fill"
        case .values: return "checkmark.seal.text.page.fill"
        case .notes: return "note.text"
        case .shopping: return "basket.fill"
        case .timer: return "timer"
        case .edit: return "pencil"
        }
    }

    var label: String {
        switch self {
        case .save: return "Kaydet"
        case .favorite: return "Favorile"
        case .values: return "Değerler"
        case .notes: return "Notlarım"
        case .shopping: return "Alışveriş"
        case .timer: return "Timer"
        case .edit: return "Edit"
        }
    }
}

/// Glass-styled action button with icon and label
struct RecipeActionButton: View {
    let action: RecipeAction
    let isActive: Bool
    let isLoading: Bool
    let isCompleted: Bool  // NEW: Show checkmark when calculation completes
    let progress: Int  // NEW: Progress percentage (0-100) for loading state
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var pulseOpacity: Double = 1.0

    // Button background with purple tint
    private var buttonBackground: Color {
        AppTheme.primaryPurple.opacity(0.2)
    }

    init(
        action: RecipeAction,
        isActive: Bool = false,
        isLoading: Bool = false,
        isCompleted: Bool = false,  // NEW
        progress: Int = 0,  // NEW
        onTap: @escaping () -> Void
    ) {
        self.action = action
        self.isActive = isActive
        self.isLoading = isLoading
        self.isCompleted = isCompleted
        self.progress = progress
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(isLoading ? pulseOpacity : 1.0)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .upUp.byLayer), options: .nonRepeating))

                // Show percentage if loading and action is .values, otherwise show label
                if isLoading && action == .values {
                    Text("%\(progress)")
                        .font(.sfRounded(14, weight: .semiBold))
                        .foregroundColor(.primary)
                        .opacity(pulseOpacity)
                        .contentTransition(.numericText(value: Double(progress)))
                } else {
                    Text(action.label)
                        .font(.sfRounded(14, weight: .medium))
                        .foregroundColor(.primary)
                        .opacity(isLoading ? pulseOpacity : 1.0)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(buttonBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 25, style: .continuous)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .onAppear {
            if isLoading {
                startPulseAnimation()
            }
        }
        .onChange(of: isLoading) { oldValue, newValue in
            if newValue {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            pulseOpacity = 0.3
        }
    }

    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseOpacity = 1.0
        }
    }

    // MARK: - Computed Properties

    /// Returns checkmark when completed, otherwise the action's icon
    private var iconName: String {
        if isCompleted {
            return "checkmark.circle.fill"
        }
        return isActive ? action.filledIcon : action.icon
    }
}

// MARK: - Action Button Row

/// Row of recipe action buttons
struct RecipeActionRow: View {
    let actions: [RecipeAction]
    let activeStates: [Bool]
    let loadingStates: [Bool]
    let completedStates: [Bool]
    let progressStates: [Int]  // NEW: Progress percentages
    let onTap: (RecipeAction) -> Void

    init(
        actions: [RecipeAction],
        activeStates: [Bool]? = nil,
        loadingStates: [Bool]? = nil,
        completedStates: [Bool]? = nil,
        progressStates: [Int]? = nil,  // NEW
        onTap: @escaping (RecipeAction) -> Void
    ) {
        self.actions = actions
        self.activeStates = activeStates ?? Array(repeating: false, count: actions.count)
        self.loadingStates = loadingStates ?? Array(repeating: false, count: actions.count)
        self.completedStates = completedStates ?? Array(repeating: false, count: actions.count)
        self.progressStates = progressStates ?? Array(repeating: 0, count: actions.count)  // NEW
        self.onTap = onTap
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                RecipeActionButton(
                    action: action,
                    isActive: activeStates[safe: index] ?? false,
                    isLoading: loadingStates[safe: index] ?? false,
                    isCompleted: completedStates[safe: index] ?? false,
                    progress: progressStates[safe: index] ?? 0,  // NEW
                    onTap: { onTap(action) }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Recipe Action Buttons") {
    ZStack {
        // Warm background to simulate recipe image
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.9, blue: 0.6),
                Color(red: 1.0, green: 0.85, blue: 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 32) {
            // Single buttons
            VStack(spacing: 16) {
                Text("Individual Buttons")
                    .font(.headline)

                HStack(spacing: 12) {
                    RecipeActionButton(action: .save, isActive: true) {
                        print("Save tapped")
                    }

                    RecipeActionButton(action: .values, isActive: false) {
                        print("Values tapped")
                    }

                    RecipeActionButton(action: .shopping, isActive: false) {
                        print("Shopping tapped")
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)

            // Action row
            VStack(spacing: 16) {
                Text("Action Row")
                    .font(.headline)

                RecipeActionRow(
                    actions: [.save, .values, .shopping],
                    activeStates: [true, false, false]
                ) { action in
                    print("\(action.label) tapped")
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)

            Spacer()
        }
        .padding()
    }
}

#Preview("All Actions") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach([RecipeAction.save, .values, .shopping, .timer, .edit], id: \.label) { action in
                HStack {
                    RecipeActionButton(action: action, isActive: false) {
                        print("\(action.label) tapped")
                    }
                    .frame(width: 100)

                    RecipeActionButton(action: action, isActive: true) {
                        print("\(action.label) active tapped")
                    }
                    .frame(width: 100)
                }
            }
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
