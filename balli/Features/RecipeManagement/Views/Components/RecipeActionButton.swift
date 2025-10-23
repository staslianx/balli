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
    case values
    case shopping
    case timer
    case edit

    var icon: String {
        switch self {
        case .save: return "star"
        case .values: return "checkmark.seal.text.page"
        case .shopping: return "basket"
        case .timer: return "timer"
        case .edit: return "pencil"
        }
    }

    var filledIcon: String {
        switch self {
        case .save: return "star.fill"
        case .values: return "checkmark.seal.text.page.fill"
        case .shopping: return "basket.fill"
        case .timer: return "timer"
        case .edit: return "pencil"
        }
    }

    var label: String {
        switch self {
        case .save: return "Kaydet"
        case .values: return "Değerler"
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
    let onTap: () -> Void

    @State private var isPressed = false

    init(
        action: RecipeAction,
        isActive: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.action = action
        self.isActive = isActive
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: isActive ? action.filledIcon : action.icon)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

                Text(action.label)
                    .font(.sfRounded(14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .recipeGlass(tint: .warm, cornerRadius: 25)
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
    }
}

// MARK: - Action Button Row

/// Row of recipe action buttons
struct RecipeActionRow: View {
    let actions: [RecipeAction]
    let activeStates: [Bool]
    let onTap: (RecipeAction) -> Void

    init(
        actions: [RecipeAction],
        activeStates: [Bool]? = nil,
        onTap: @escaping (RecipeAction) -> Void
    ) {
        self.actions = actions
        self.activeStates = activeStates ?? Array(repeating: false, count: actions.count)
        self.onTap = onTap
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                RecipeActionButton(
                    action: action,
                    isActive: activeStates[safe: index] ?? false,
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
