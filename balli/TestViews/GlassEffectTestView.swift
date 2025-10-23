//
//  GlassEffectTestView.swift
//  balli
//
//  Test view for verifying iOS 26 Liquid Glass dimming animations
//

import SwiftUI

struct GlassEffectTestView: View {
    @State private var textInput1 = ""
    @State private var textInput2 = ""
    @FocusState private var isInput1Focused: Bool
    @FocusState private var isInput2Focused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Test Case 1: Original problematic implementation
                    VStack(alignment: .leading) {
                        Text("Test 1: Original (Problematic)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack {
                            TextField("Type here", text: $textInput1)
                                .textFieldStyle(.plain)
                                .focused($isInput1Focused)
                                .padding()
                        }
                        .glassEffect(
                            .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(radius: 3)
                    }

                    // Test Case 2: Fixed implementation
                    VStack(alignment: .leading) {
                        Text("Test 2: Fixed (Smooth Dimming)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack {
                            TextField("Type here", text: $textInput2)
                                .textFieldStyle(.plain)
                                .focused($isInput2Focused)
                                .padding()
                        }
                        .glassEffect(
                            isInput2Focused ? .regular : .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .animation(.interactiveSpring(duration: 0.3, extraBounce: 0.05), value: isInput2Focused)
                        .shadow(radius: 3)
                    }

                    // Test Case 3: Working example without TextField
                    VStack(alignment: .leading) {
                        Text("Test 3: Button (Always Works)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: {}) {
                            Text("Tap and Hold Me")
                                .padding()
                                .frame(maxWidth: .infinity)
                        }
                        .glassEffect(
                            .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .shadow(radius: 3)
                    }

                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Testing Instructions:")
                            .font(.headline)
                        Text("1. Tap and hold each container")
                        Text("2. Release to see dimming animation")
                        Text("3. Test 1 should dim abruptly")
                        Text("4. Test 2 should dim smoothly")
                        Text("5. Test 3 always dims smoothly")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Glass Effect Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    GlassEffectTestView()
}