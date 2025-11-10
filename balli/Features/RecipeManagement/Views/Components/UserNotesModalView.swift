//
//  UserNotesModalView.swift
//  balli
//
//  Modal view for users to add personal notes to recipes
//

import SwiftUI

/// Modal sheet for editing user notes on a recipe
struct UserNotesModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var notes: String
    let onSave: (String) -> Void

    @State private var editedNotes: String
    @FocusState private var isTextFieldFocused: Bool

    init(notes: Binding<String>, onSave: @escaping (String) -> Void) {
        self._notes = notes
        self.onSave = onSave
        self._editedNotes = State(initialValue: notes.wrappedValue)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Text Editor
                    TextEditor(text: $editedNotes)
                        .font(.sfRounded(16, weight: .regular))
                        .padding(16)
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.systemBackground))
                                .recipeGlass(tint: .warm, cornerRadius: 20)
                        )
                        .overlay(
                            Group {
                                if editedNotes.isEmpty {
                                    Text("Tarifle ilgili notlarınız...")
                                        .font(.sfRounded(16, weight: .regular))
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 24)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                        .focused($isTextFieldFocused)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .frame(minHeight: 400)

                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .navigationTitle("Notlarım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                    .font(.sfRounded(16, weight: .medium))
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        notes = editedNotes
                        onSave(editedNotes)
                        dismiss()
                    }
                    .font(.sfRounded(16, weight: .semiBold))
                    .foregroundColor(ThemeColors.primaryPurple)
                }
            }
        }
        .onAppear {
            // Focus text field when view appears
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(500))
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Empty Notes") {
    UserNotesModalView(notes: .constant("")) { newNotes in
    }
}

#Preview("Existing Notes") {
    UserNotesModalView(notes: .constant("Bu tarifi daha önce denedim, çok güzel oldu. Bir sonraki sefere biraz daha az şeker koyacağım.")) { newNotes in
    }
}
