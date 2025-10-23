//
//  CaptureReviewView.swift
//  balli
//
//  View for reviewing captured images before AI processing
//

import SwiftUI

struct CaptureReviewView: View {
    @ObservedObject var captureFlowManager: CaptureFlowManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var navigateToManualEntry = false
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .navigationDestination(isPresented: $navigateToManualEntry) {
                    ManualEntryView()
                }
                .alert("Hata", isPresented: $showingError) {
                    Button("Tamam", role: .cancel) { }
                } message: {
                    Text(captureFlowManager.currentError?.localizedDescription ?? "Bilinmeyen hata")
                }
                .onChange(of: captureFlowManager.currentError) { _, error in
                    showingError = error != nil
                }
        }
        .lockOrientation(.portrait)
    }
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            if let session = captureFlowManager.currentSession {
                VStack(spacing: 0) {
                    // Image preview
                    imagePreviewSection(session: session)
                    
                    // Bottom controls
                    bottomControlsSection(session: session)
                }
            } else {
                noSessionView
            }
        }
    }
    
    @ViewBuilder
    private func imagePreviewSection(session: CaptureSession) -> some View {
        if let image = captureFlowManager.capturedImage {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .overlay(
                        // Processing overlay
                        Group {
                            if captureFlowManager.isAnalyzing {
                                ProcessingOverlay(
                                    state: session.state,
                                    progress: captureFlowManager.processingProgress
                                )
                            }
                        }
                    )
            }
        }
    }
    
    @ViewBuilder
    private func bottomControlsSection(session: CaptureSession) -> some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            // State indicator
                            HStack {
                                stateIndicator(for: session.state)
                                Spacer()
                                if let duration = session.processingDuration {
                                    Text("\(String(format: "%.1f", duration))s")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal)
                            
                            // Action buttons
                            if !captureFlowManager.isAnalyzing {
                                HStack(spacing: ResponsiveDesign.Spacing.medium) {
                                    // Retry button
                                    Button(action: {
                                        Task {
                                            captureFlowManager.clearCapturedImage()
                                            dismiss()
                                        }
                                    }) {
                                        Label("Tekrar Çek", systemImage: "arrow.clockwise")
                                            .font(.system(size: 17, weight: .regular, design: .rounded))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                    
                                    // Manual entry button
                                    Button(action: {
                                        navigateToManualEntry = true
                                    }) {
                                        Label("Manuel Giriş", systemImage: "keyboard")
                                            .font(.system(size: 17, weight: .regular, design: .rounded))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                }
                                .padding(.horizontal)
                                
                                // Process/Use button
                                if session.state == .captured {
                                    Button(action: {
                                        Task {
                                            await captureFlowManager.confirmAndProcess()
                                        }
                                    }) {
                                        Label("İşlemeye Devam Et", systemImage: "wand.and.stars")
                                            .font(.system(size: 17, weight: .regular, design: .rounded))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    .padding(.horizontal)
                                } else if session.state == .completed {
                                    Button(action: {
                                        // Note: Food entry navigation with AI data could be implemented here
                                        dismiss()
                                    }) {
                                        Label("Kullan", systemImage: "checkmark.circle.fill")
                                            .font(.system(size: 17, weight: .regular, design: .rounded))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    .tint(.green)
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Error retry
                            if session.state == .failed && session.canRetry {
                                Button(action: {
                                    Task {
                                        await captureFlowManager.retryCapture(session)
                                    }
                                }) {
                                    Label("Tekrar Dene", systemImage: "arrow.clockwise")
                                        .font(.system(size: 17, weight: .regular, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(.orange)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                        .background(Color.black.opacity(0.8))
    }
    
    @ViewBuilder
    private var noSessionView: some View {
        VStack {
            Image(systemName: "photo.slash")
                .font(.system(size: ResponsiveDesign.Font.scaledSize(60), weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Text("Görüntü bulunamadı")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if !captureFlowManager.isAnalyzing {
                Button("İptal") {
                    Task {
                        await captureFlowManager.cancelCapture()
                    }
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        
        ToolbarItem(placement: .principal) {
            Text("Fotoğraf İnceleme")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func stateIndicator(for state: CaptureFlowState) -> some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            switch state {
            case .idle:
                Image(systemName: "circle")
                    .foregroundColor(.white.opacity(0.5))
                Text("Hazır")
                    .foregroundColor(.white.opacity(0.5))
                
            case .capturing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                Text("Çekiliyor...")
                    .foregroundColor(.white)
                
            case .captured:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Çekildi")
                    .foregroundColor(.white)
                
            case .optimizing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
                Text("Optimize ediliyor...")
                    .foregroundColor(.white)
                
            case .processingAI:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    .scaleEffect(0.8)
                Text("AI işleniyor...")
                    .foregroundColor(.white)
                
            case .waitingForNetwork:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
                Text("Bağlantı bekleniyor...")
                    .foregroundColor(.white)
                
            case .completed:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("Tamamlandı")
                    .foregroundColor(.white)
                
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Başarısız")
                    .foregroundColor(.white)
                
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                Text("İptal edildi")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .font(.system(size: 12, weight: .regular, design: .rounded))
    }
}

// MARK: - Processing Overlay
struct ProcessingOverlay: View {
    let state: CaptureFlowState
    let progress: Double
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: ResponsiveDesign.Spacing.medium) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.primaryPurple, AppTheme.lightPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // State text
                Text(stateText(for: state))
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    private func stateText(for state: CaptureFlowState) -> String {
        switch state {
        case .optimizing:
            return "Görüntü optimize ediliyor..."
        case .processingAI:
            return "Besin değerleri analiz ediliyor..."
        case .waitingForNetwork:
            return "İnternet bağlantısı bekleniyor..."
        default:
            return "İşleniyor..."
        }
    }
}

#Preview {
    CaptureReviewView(captureFlowManager: {
        let manager = CaptureFlowManager(cameraManager: CameraManager())
        manager.capturedImage = UIImage(systemName: "photo")
        return manager
    }())
}