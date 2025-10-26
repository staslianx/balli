import SwiftUI
import UIKit
import OSLog

struct ResearchResponseActionRow: View {
    enum Feedback: Equatable {
        case positive
        case negative
    }

    let content: String
    var shareSubject: String?
    var onFeedbackSelection: ((Feedback?) -> Void)?

    @State private var selectedFeedback: Feedback? = nil
    @State private var showCopyConfirmation = false

    private var sanitizedContent: String {
        content.replacingOccurrences(of: "▊", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 14) {
                Spacer()

                Button(action: copyContent) {
                    Image(systemName: "doc.on.doc")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(sanitizedContent.isEmpty)
                .accessibilityLabel("Yanıtı kopyala")

                Button {
                    toggleFeedback(.positive)
                } label: {
                    Image(systemName: selectedFeedback == .positive ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedFeedback == .positive ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(selectedFeedback != nil) // Disable after any selection
                .opacity(selectedFeedback != nil && selectedFeedback != .positive ? 0.4 : 1.0)
                .accessibilityLabel("Bu yanıt faydalı")

                Button {
                    toggleFeedback(.negative)
                } label: {
                    Image(systemName: selectedFeedback == .negative ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedFeedback == .negative ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(selectedFeedback != nil) // Disable after any selection
                .opacity(selectedFeedback != nil && selectedFeedback != .negative ? 0.4 : 1.0)
                .accessibilityLabel("Bu yanıt faydasız")

                ShareLink(item: sanitizedContent.isEmpty ? "" : sanitizedContent, subject: shareSubject.map(Text.init)) {
                    Image(systemName: "square.and.arrow.up")
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(sanitizedContent.isEmpty)
                .accessibilityLabel("Yanıtı paylaş")
            }

            if showCopyConfirmation {
                Text("Kopyalandı")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopyConfirmation)
        .animation(.easeInOut(duration: 0.15), value: selectedFeedback)
        .onChange(of: selectedFeedback) { _, newValue in
            onFeedbackSelection?(newValue)
        }
    }

    private func copyContent() {
        guard !sanitizedContent.isEmpty else { return }
        UIPasteboard.general.string = sanitizedContent
        showTransientCopyConfirmation()
    }

    private func toggleFeedback(_ feedback: Feedback) {
        // Only allow selection if nothing is selected yet
        guard selectedFeedback == nil else { return }
        selectedFeedback = feedback
    }

    private func showTransientCopyConfirmation() {
        showCopyConfirmation = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            showCopyConfirmation = false
        }
    }
}

// MARK: - Preview

#Preview {
    let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "research.preview")

    return ResearchResponseActionRow(content: "Örnek araştırma yanıtı içeriği", shareSubject: "Örnek Soru") { selection in
        logger.debug("Feedback selected in preview: \(String(describing: selection))")
    }
    .padding()
}
