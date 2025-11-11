//
//  AIPreviewView.swift
//  balli
//
//  Preview captured photo with retake/use options
//

import SwiftUI

struct AIPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // The captured image to preview
    let capturedImage: UIImage
    
    // Flow manager reference
    @ObservedObject var captureFlowManager: CaptureFlowManager
    
    // Callback when user confirms to use the photo
    let onUsePhoto: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6)
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    Spacer(minLength: ResponsiveDesign.height(50))
                    
                    // Photo container
                    photoLabelView
                    
                    Spacer(minLength: ResponsiveDesign.height(50))
                    
                    // Two-button layout
                    HStack(spacing: 60) {
                        // Tekrar Çek button (retake) - transparent like edit button
                        Button(action: handleRetake) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.primaryPurple)
                                .frame(width: ResponsiveDesign.height(72), height: ResponsiveDesign.height(72))
                                .background(
                                    Circle()
                                        .fill(.clear)
                                        .glassEffect(.regular.interactive(), in: Circle())
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    AppTheme.primaryPurple.opacity(0.15),
                                                    AppTheme.primaryPurple.opacity(0.05)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                        }

                        // Kullan button (use) - filled purple with light purple checkmark - SAME SIZE as retake
                        Button(action: handleUse) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                        }
                        .buttonStyle(.balliBordered(size: ResponsiveDesign.height(72)))
                    }
                    .padding(.bottom, ResponsiveDesign.height(12))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                }
            }
        }
    }
    
    private var photoLabelView: some View {
        ZStack {
            // Container
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.modal)
                .fill(Color(.systemBackground))
                .frame(width: ResponsiveDesign.Components.foodLabelWidth, height: ResponsiveDesign.Components.foodLabelHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.modal)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: ResponsiveDesign.height(10), x: 0, y: ResponsiveDesign.height(4))
                .overlay(
                    // Clean preview image without any processing indicators
                    Image(uiImage: capturedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: ResponsiveDesign.Components.foodLabelWidth,
                            height: ResponsiveDesign.Components.foodLabelHeight
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.modal))
                )
        }
    }
    
    private func handleRetake() {
        captureFlowManager.clearCapturedImage()
        dismiss()
    }
    
    private func handleUse() {
        onUsePhoto()  // Callback to parent to proceed to processing
    }
}

// MARK: - Preview
#Preview {
    // PREVIEW FIX: Wrap in NavigationStack to support toolbar and dismiss environment
    // Use StateObject to create CaptureFlowManager within preview context safely
    struct PreviewContainer: View {
        @StateObject private var cameraManager = CameraManager()
        @StateObject private var captureFlowManager: CaptureFlowManager

        init() {
            let camera = CameraManager()
            _cameraManager = StateObject(wrappedValue: camera)
            _captureFlowManager = StateObject(wrappedValue: CaptureFlowManager(cameraManager: camera))
        }

        var body: some View {
            NavigationStack {
                AIPreviewView(
                    capturedImage: UIImage(systemName: "photo.fill") ?? UIImage(),
                    captureFlowManager: captureFlowManager,
                    onUsePhoto: { print("Use photo tapped") }
                )
            }
        }
    }

    return PreviewContainer()
}