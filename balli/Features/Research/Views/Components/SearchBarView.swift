//
//  SearchBarView.swift
//  balli
//
//  Liquid Glass search input box for research view
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import PhotosUI

struct SearchBarView: View {
    @Binding var searchQuery: String
    @Binding var attachedImage: UIImage?
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let isSearching: Bool
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool
    @State private var showCamera = false
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    private func handleSubmit() {
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            isInputFocused = false // Dismiss keyboard
            onSubmit()
            // Clear the input box so user can type next question
            // CONCURRENCY FIX: Use Task.sleep for Swift 6 compliance
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                searchQuery = ""
            }
        }
    }

    private func handleStopOrSend() {
        if isSearching {
            onCancel()
        } else {
            handleSubmit()
        }
    }

    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            // Image attachment preview (if present)
            if let image = attachedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            attachedImage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.top, ResponsiveDesign.Spacing.medium)
                .transition(.scale.combined(with: .opacity))
            }

            // Text area at the top
            // ULTRA PERFORMANCE FIX: Minimal TextField configuration for instant keyboard response
            TextField("balli'ye sor", text: $searchQuery, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .lineLimit(1...6)
                // Remove heavy design font modifier
                .font(.system(size: 17))
                .foregroundColor(.primary)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.top, ResponsiveDesign.Spacing.medium)
                .submitLabel(.send)
                .onSubmit {
                    handleSubmit()
                }
                // CRITICAL: Disable autocorrection for faster typing
                .autocorrectionDisabled(true)
                // Optimize keyboard for faster response
                .keyboardType(.default)
                // Swipe down gesture to dismiss keyboard
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            // Only dismiss if dragging downward
                            if value.translation.height > 0 {
                                isInputFocused = false
                            }
                        }
                )

            // Send/Stop button at the bottom
            HStack {
                // Attachment button on the left
                Menu {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Fotoğraf Çek", systemImage: "camera")
                    }

                    Button {
                        showPhotosPicker = true
                    } label: {
                        Label("Fotoğraf Seç", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .disabled(isSearching)
                .padding(.leading, ResponsiveDesign.height(6))

                Spacer()

                Button(action: handleStopOrSend) {
                    if isSearching {
                        // Stop button (red) during streaming
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(36), weight: .regular, design: .rounded))
                            .foregroundColor(.red)
                    } else {
                        // Send button (purple) when idle
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(36), weight: .regular, design: .rounded))
                            .foregroundColor(searchQuery.isEmpty ? Color(.systemGray3) : AppTheme.primaryPurple)
                    }
                }
                .disabled(!isSearching && searchQuery.trimmingCharacters(in: .whitespaces).isEmpty && attachedImage == nil)
                .padding(.trailing, ResponsiveDesign.height(6))
            }
            .padding(.bottom, ResponsiveDesign.Spacing.xSmall)
        }
        .background(.clear)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        // CRITICAL FIX: Only animate button color change, not entire view
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearching)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: attachedImage)
        .sheet(isPresented: $showCamera) {
            CameraCapturePicker(selectedImage: $attachedImage)
                .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        attachedImage = uiImage
                    }
                }
            }
        }
    }
}

// MARK: - Camera Capture Picker

/// UIKit wrapper for camera capture
struct CameraCapturePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapturePicker

        init(_ parent: CameraCapturePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Comprehensive Previews

#Preview("Empty State") {
    @Previewable @State var image: UIImage? = nil

    SearchBarView(
        searchQuery: .constant(""),
        attachedImage: $image,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
}

#Preview("With Text") {
    @Previewable @State var query = "What are the best foods for Type 1 diabetes?"
    @Previewable @State var image: UIImage? = nil

    SearchBarView(
        searchQuery: $query,
        attachedImage: $image,
        onSubmit: { print("Search submitted: \(query)") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
}

#Preview("With Image Attachment") {
    @Previewable @State var query = "What food is this?"
    @Previewable @State var image: UIImage? = {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }()

    SearchBarView(
        searchQuery: $query,
        attachedImage: $image,
        onSubmit: { print("Search submitted with image") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
}

#Preview("Searching (Stop Button)") {
    @Previewable @State var query = "Loading response..."
    @Previewable @State var image: UIImage? = nil

    SearchBarView(
        searchQuery: $query,
        attachedImage: $image,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: true
    )
    .previewWithPadding()
}

#Preview("Long Multiline Query") {
    @Previewable @State var query = "Can you explain the detailed mechanisms of how different types of exercise affect blood glucose levels in people with Type 1 diabetes, including both aerobic and resistance training?"
    @Previewable @State var image: UIImage? = nil

    SearchBarView(
        searchQuery: $query,
        attachedImage: $image,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
}

#Preview("Dark Mode") {
    @Previewable @State var query = "How does insulin work?"
    @Previewable @State var image: UIImage? = nil

    SearchBarView(
        searchQuery: $query,
        attachedImage: $image,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    @Previewable @State var query = "Carb counting tips"
    @Previewable @State var image: UIImage? = nil

    SearchBarView(
        searchQuery: $query,
        attachedImage: $image,
        onSubmit: { print("Search submitted") },
        onCancel: { print("Search cancelled") },
        isSearching: false
    )
    .previewWithPadding()
    .preferredColorScheme(.light)
}

#Preview("Interactive State") {
    @Previewable @State var query = ""
    @Previewable @State var image: UIImage? = nil

    VStack(spacing: 20) {
        Text("Tap to type, press send button to submit")
            .font(.caption)
            .foregroundStyle(.secondary)

        SearchBarView(
            searchQuery: $query,
            attachedImage: $image,
            onSubmit: {
                query = ""
            },
            onCancel: { },
            isSearching: false
        )
    }
    .previewWithPadding()
}
