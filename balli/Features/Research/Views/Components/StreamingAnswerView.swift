//
//  StreamingAnswerView.swift
//  balli
//
//  Smooth streaming view for answer content with markdown rendering
//  SIMPLIFIED: Direct rendering without batching state
//  Swift 6 strict concurrency compliant
//

import SwiftUI

/// View that displays streaming answer content with smooth updates and markdown rendering
/// ARCHITECTURE FIX: Renders content prop DIRECTLY - no intermediate state variable
/// SwiftUI's built-in diffing + animation handles smooth updates automatically
struct StreamingAnswerView: View {
    let content: String
    let isStreaming: Bool
    let sourceCount: Int
    let sources: [ResearchSource]
    let fontSize: CGFloat

    var body: some View {
        MarkdownText(
            content: content,  // ✅ DIRECT BINDING - No intermediate state!
            fontSize: fontSize,
            enableSelection: true,
            sourceCount: sourceCount,
            sources: sources,
            headerFontSize: fontSize * 1.88,  // Proportional header scaling
            fontName: "Manrope"  // Body text uses Manrope
        )
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Streaming Simulation") {
    struct StreamingPreview: View {
        @State private var content = ""
        @State private var isStreaming = true

        let fullText = """
        **Type 2 diabetes** is a chronic condition that affects how your body processes _blood sugar_ (glucose).

        ## Key Management Strategies

        1. **Physical Activity**: Regular exercise helps control weight and blood sugar levels
        2. **Healthy Diet**: Focus on whole grains, fruits, vegetables, and lean proteins
        3. **Blood Sugar Monitoring**: Check levels regularly as recommended
        4. **Medication**: Take prescribed medications consistently

        > Important: Always consult with your healthcare provider before making changes to your diabetes management plan.

        ### Additional Resources

        - [American Diabetes Association](https://diabetes.org)
        - [Mayo Clinic - Type 2 Diabetes](https://mayoclinic.org)

        Research shows that `lifestyle modifications` can significantly improve outcomes.
        """

        var body: some View {
            VStack(spacing: 20) {
                Text("Streaming Answer View Demo")
                    .font(.headline)

                ScrollView {
                    StreamingAnswerView(content: content, isStreaming: isStreaming, sourceCount: 0, sources: [], fontSize: 17)
                        .padding()
                }
                .frame(height: 400)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Text("Length: \(content.count)")
                        .font(.caption)
                    Spacer()
                    Text(isStreaming ? "Streaming..." : "Complete")
                        .font(.caption)
                        .foregroundStyle(isStreaming ? .blue : .green)
                }

                Button(isStreaming ? "Streaming..." : "Start Streaming") {
                    startStreaming()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .padding()
        }

        private func startStreaming() {
            content = ""
            isStreaming = true

            Task {
                // Simulate realistic token-by-token streaming
                for (_, char) in fullText.enumerated() {
                    content.append(char)

                    // Random delay to simulate real network timing
                    let delay = Int.random(in: 10...50)
                    try? await Task.sleep(for: .milliseconds(delay))
                }

                try? await Task.sleep(for: .milliseconds(200))
                isStreaming = false
            }
        }
    }

    return StreamingPreview()
}

#Preview("Fast Streaming") {
    struct FastStreamingPreview: View {
        @State private var content = ""
        @State private var isStreaming = true

        let fastText = "This is a fast streaming test with very rapid token arrival. " +
                      "The batching should smooth out the updates and prevent choppy rendering. " +
                      "Notice how the text appears smoothly despite rapid updates."

        var body: some View {
            VStack(spacing: 20) {
                Text("Fast Streaming Test")
                    .font(.headline)

                StreamingAnswerView(content: content, isStreaming: isStreaming, sourceCount: 0, sources: [], fontSize: 17)
                    .padding()
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Start Fast Streaming") {
                    startFastStreaming()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)
            }
            .padding()
        }

        private func startFastStreaming() {
            content = ""
            isStreaming = true

            Task {
                // Very fast streaming (5-15ms per token)
                for (_, char) in fastText.enumerated() {
                    content.append(char)
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 5...15)))
                }

                isStreaming = false
            }
        }
    }

    return FastStreamingPreview()
}
