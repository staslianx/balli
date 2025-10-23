//
//  CameraView.swift
//  balli
//
//  Camera interface for nutrition label scanning
//

import SwiftUI
import AVFoundation

enum CameraPreviewMode {
    case withPermission
    case withoutPermission
    case normal
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var captureFlowManager: CaptureFlowManager
    @StateObject private var permissionManager = SystemPermissionCoordinator.shared
    @State private var navigateToManualEntry = false
    @State private var captureAnimation = false
    @State private var showingPermissionView = false
    @State private var showingProcessingView = false
    @State private var showingResultView = false
    @State private var extractedNutrition: NutritionExtractionResult?
    
    // Preview mode for SwiftUI previews
    private let previewMode: CameraPreviewMode
    
    init(previewMode: CameraPreviewMode = .normal) {
        self.previewMode = previewMode
        let manager = CameraManager()
        self._cameraManager = StateObject(wrappedValue: manager)
        self._captureFlowManager = StateObject(wrappedValue: CaptureFlowManager(cameraManager: manager))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Show permission view if not authorized
                if shouldShowPermissionView {
                    permissionView
                }
                // Show unified AI view (handles both analysis and results)
                else if shouldShowProcessingView || shouldShowResultView {
                    unifiedAIView
                }
                // Show AI preview view when image is captured
                else if shouldShowPreviewView {
                    previewView
                } else {
                    // Camera view content
                    cameraViewContent
                }
            }  // End of main ZStack
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                // Only show camera toolbar when camera is active (not in preview or processing)
                if !captureFlowManager.showingCapturedImage && !showingProcessingView {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToManualEntry) {
                ManualEntryView()
            }
        }
        .lockOrientation(.portrait)
        .onAppear {
            if previewMode == .normal {
                Task {
                    // Check permission first
                    let permissionState = await permissionManager.checkPermission(.camera)
                    if permissionState == .authorized {
                        await cameraManager.prepare()
                    }
                }
            } else {
                // Set mock state for preview
                cameraManager.state = previewMode == .withPermission ? .ready : .permissionDenied
            }
        }
        .onDisappear {
            if previewMode == .normal {
                Task {
                    await cameraManager.stop()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if previewMode == .normal && !captureFlowManager.showingCapturedImage {
                Task {
                    // Re-check permission and restart camera when returning from background
                    let permissionState = await permissionManager.checkPermission(.camera)
                    if permissionState == .authorized {
                        await cameraManager.prepare()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if previewMode == .normal {
                Task {
                    // Stop camera when entering background
                    await cameraManager.stop()
                }
            }
        }
        .onChange(of: captureFlowManager.showingCapturedImage) { _, newValue in
            // Reset processing view when preview state changes
            if !newValue {
                showingProcessingView = false
            }
        }
    }

    // MARK: - Computed Properties

    private var shouldShowPermissionView: Bool {
        !permissionManager.isAuthorized(for: .camera) && permissionManager.status(for: .camera) != .checking
    }

    private var shouldShowResultView: Bool {
        showingResultView && extractedNutrition != nil && captureFlowManager.capturedImage != nil
    }

    private var shouldShowProcessingView: Bool {
        showingProcessingView && captureFlowManager.capturedImage != nil
    }

    private var shouldShowPreviewView: Bool {
        captureFlowManager.showingCapturedImage && captureFlowManager.capturedImage != nil
    }

    @ViewBuilder
    private var permissionView: some View {
        CameraPermissionView(
            permissionManager: permissionManager,
            onPermissionGranted: {
                Task {
                    // Re-check permission state after grant
                    let state = await permissionManager.checkPermission(.camera)
                    if state.isUsable {
                        await cameraManager.prepare()
                    }
                }
            },
            onManualEntry: {
                navigateToManualEntry = true
            }
        )
        .zIndex(3)
    }


    @ViewBuilder
    private var unifiedAIView: some View {
        if let capturedImage = captureFlowManager.capturedImage {
            // Use unified AIResultView for both analysis and results
            if let nutrition = extractedNutrition {
                // Analysis complete - show results
                AIResultView(
                    nutritionResult: nutrition,
                    capturedImage: capturedImage
                )
            } else {
                // Analysis in progress - show analysis state
                AIResultView(
                    capturedImage: capturedImage,
                    captureFlowManager: captureFlowManager
                )
            }
        }
    }

    @ViewBuilder
    private var previewView: some View {
        if let capturedImage = captureFlowManager.capturedImage {
            AIPreviewView(
                capturedImage: capturedImage,
                captureFlowManager: captureFlowManager,
                onUsePhoto: {
                    // User confirmed to use photo - move to processing
                    showingProcessingView = true
                }
            )
            .lockOrientation(.portrait)
            .zIndex(2)  // On top
            .transition(.identity)  // No transition animation
        }
    }

    @ViewBuilder
    private var cameraViewContent: some View {
        ZStack {
            // Camera preview background
            Color.black
                .ignoresSafeArea()

            // Camera preview - only show when session is running
            if previewMode == .normal && cameraManager.isSessionRunning {
                CameraPreviewLayer(cameraManager: cameraManager)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
            }

            cameraOverlayContent
        }
    }

    @ViewBuilder
    private var cameraOverlayContent: some View {
        VStack(spacing: 0) {
            // Loading and error states
            if shouldShowLoadingIndicator {
                loadingIndicator
            } else if shouldShowErrorState {
                errorStateView
            } else if shouldShowMockPreview {
                mockPreviewContent
            }

            Spacer()

            // Camera UI overlay
            cameraUIOverlay

            // Error banner
            if let error = cameraManager.error {
                errorBanner(error: error)
            }
        }
    }

    // MARK: - Camera State Computed Properties

    private var shouldShowLoadingIndicator: Bool {
        previewMode == .normal && !cameraManager.isSessionRunning && cameraManager.state == .preparingSession
    }

    private var shouldShowErrorState: Bool {
        cameraManager.state == .permissionDenied || cameraManager.state == .thermallyThrottled
    }

    private var shouldShowMockPreview: Bool {
        previewMode != .normal
    }

    // MARK: - Camera UI Components

    @ViewBuilder
    private var loadingIndicator: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Kamera hazırlanıyor...")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, ResponsiveDesign.Spacing.small)
        }
    }

    @ViewBuilder
    private var errorStateView: some View {
        if cameraManager.state == .permissionDenied {
            VStack {
                Image(systemName: "camera.slash")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(60), weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Text("Kamera İzni Gerekli")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        } else if cameraManager.state == .thermallyThrottled {
            VStack {
                Image(systemName: "thermometer")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(60), weight: .regular, design: .rounded))
                    .foregroundColor(.orange.opacity(0.7))
                Text("Cihaz Çok Sıcak")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var mockPreviewContent: some View {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.8),
                Color.gray.opacity(0.4),
                Color.gray.opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            VStack {
                Image(systemName: "camera")
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(60), weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Text("Kamera Önizlemesi")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        )
    }

    @ViewBuilder
    private var cameraUIOverlay: some View {
        VStack {
            Spacer(minLength: ResponsiveDesign.height(50))

            // Central viewfinder rectangle - bigger and centered
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.modal)
                .stroke(Color.white, lineWidth: ResponsiveDesign.height(4))
                .frame(width: ResponsiveDesign.Components.foodLabelWidth, height: ResponsiveDesign.Components.foodLabelHeight)

            Spacer(minLength: ResponsiveDesign.height(50))

            // Bottom controls
            cameraControlButtons
        }
    }

    @ViewBuilder
    private var cameraControlButtons: some View {
        HStack {
            // Manual button (on the left)
            Button(action: { navigateToManualEntry = true }) {
                Image(systemName: "hand.rays.fill")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .toolbarCircularGlass(size: ResponsiveDesign.Components.smallButtonSize)
            .disabled(captureFlowManager.isCapturing)
            .padding(.leading, ResponsiveDesign.height(60))

            Spacer()

            // Capture button (centered)
            Button(action: {
                captureAnimation = true
                Task {
                    await captureFlowManager.startCapture()
                    captureAnimation = false
                }
            }) {
                Circle()
                    .stroke(captureFlowManager.isCapturing ? Color.gray : Color.white, lineWidth: ResponsiveDesign.height(3))
            }
            .toolbarCircularGlass(size: ResponsiveDesign.Components.captureButtonSize)
            .disabled(captureFlowManager.isCapturing || !cameraManager.state.canCapture)

            Spacer()

            // Camera switcher button (on the right)
            Button(action: {
                Task {
                    await cameraManager.switchZoom()
                }
            }) {
                Text(cameraManager.currentZoom.rawValue)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .toolbarCircularGlass(size: ResponsiveDesign.Components.smallButtonSize)
            .disabled(captureFlowManager.isCapturing || cameraManager.availableZoomLevels.count <= 1)
            .padding(.trailing, ResponsiveDesign.height(60))
        }
        .padding(.bottom, ResponsiveDesign.height(30))
    }

    @ViewBuilder
    private func errorBanner(error: CameraError) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text(error.localizedDescription)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button("Kapat") {
                    cameraManager.error = nil
                }
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white)
            }
            .padding()
            .background(Color.red.opacity(0.8))
            .cornerRadius(ResponsiveDesign.CornerRadius.small)
            .padding(.horizontal)
            Spacer()
        }
    }
}

#Preview("Camera with Permission") {
    CameraView(previewMode: .withPermission)
}

#Preview("Camera without Permission") {
    CameraView(previewMode: .withoutPermission)
}
