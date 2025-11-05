//
//  ResearchStreamCallbacksBuilder.swift
//  balli
//
//  Builds streaming search callbacks for MedicalResearchViewModel
//  Eliminates callback hell in performStreamingSearch
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Builds all callbacks for streaming search in a clean, testable structure
/// Eliminates 85+ lines of nested callback hell from MedicalResearchViewModel
@MainActor
final class ResearchStreamCallbacksBuilder {
    // MARK: - Handler References

    private weak var viewModel: MedicalResearchViewModel?

    // MARK: - Initialization

    init(viewModel: MedicalResearchViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Callback Builders

    /// Build all streaming search callbacks
    /// Returns tuple of closures ready to pass to searchService.searchStreaming()
    func buildCallbacks(
        query: String,
        answerId: String
    ) -> (
        onToken: @Sendable (String) -> Void,
        onTierSelected: @Sendable (Int) -> Void,
        onSearchComplete: @Sendable (Int, String) -> Void,
        onSourcesReady: @Sendable ([SourceResponse]) -> Void,
        onComplete: @Sendable (ResearchSearchResponse) -> Void,
        onError: @Sendable (Error) -> Void,
        onPlanningStarted: @Sendable (String, Int) -> Void,
        onPlanningComplete: @Sendable (ResearchPlan, Int) -> Void,
        onRoundStarted: @Sendable (Int, String, Int, Int) -> Void,
        onRoundComplete: @Sendable (Int, [SourceResponse], RoundStatus, Int) -> Void,
        onApiStarted: @Sendable (ResearchAPI, Int, String) -> Void,
        onReflectionStarted: @Sendable (Int, Int) -> Void,
        onReflectionComplete: @Sendable (Int, ResearchReflection, Int) -> Void,
        onSourceSelectionStarted: @Sendable (String, Int) -> Void,
        onSynthesisPreparation: @Sendable (String, Int) -> Void,
        onSynthesisStarted: @Sendable (Int, Int, Int) -> Void
    ) {
        return (
            onToken: { [weak viewModel] token in
                guard let viewModel = viewModel else { return }
                let timestamp = Date()
                print("🔴 [CALLBACK-RECEIVED] Token arrived at \(timestamp.timeIntervalSince1970), length=\(token.count), creating Task")
                Task {
                    let taskStart = Date()
                    print("🟠 [TASK-START] Task executing \(taskStart.timeIntervalSince(timestamp)*1000)ms after callback")
                    await viewModel.handleToken(token, answerId: answerId)
                    let taskEnd = Date()
                    print("🟢 [TASK-END] handleToken completed in \(taskEnd.timeIntervalSince(taskStart)*1000)ms")
                }
            },
            onTierSelected: { [weak viewModel] tier in
                Task { @MainActor in
                    await viewModel?.handleTierSelected(String(tier), answerId: answerId)
                }
            },
            onSearchComplete: { [weak viewModel] count, source in
                Task { @MainActor in
                    await viewModel?.handleSearchComplete(count: count, source: source, answerId: answerId)
                }
            },
            onSourcesReady: { [weak viewModel] sources in
                Task { @MainActor in
                    await viewModel?.handleSourcesReady(sources, answerId: answerId)
                }
            },
            onComplete: { [weak viewModel] response in
                Task { @MainActor in
                    await viewModel?.handleComplete(response, query: query, answerId: answerId)
                }
            },
            onError: { [weak viewModel] error in
                Task { @MainActor in
                    await viewModel?.handleError(error, query: query, answerId: answerId)
                }
            },
            onPlanningStarted: { [weak viewModel] message, sequence in
                Task { @MainActor in
                    await viewModel?.handlePlanningStarted(message: message, sequence: sequence, answerId: answerId)
                }
            },
            onPlanningComplete: { [weak viewModel] plan, sequence in
                Task { @MainActor in
                    await viewModel?.handlePlanningComplete(plan: plan, answerId: answerId)
                }
            },
            onRoundStarted: { [weak viewModel] round, query, estimatedSources, sequence in
                Task { @MainActor in
                    await viewModel?.handleRoundStarted(round: round, query: query, estimatedSources: estimatedSources, sequence: sequence, answerId: answerId)
                }
            },
            onRoundComplete: { [weak viewModel] round, sources, status, sequence in
                Task { @MainActor in
                    await viewModel?.handleRoundComplete(round: round, sources: sources, status: status, sequence: sequence, answerId: answerId)
                }
            },
            onApiStarted: { [weak viewModel] api, count, message in
                Task { @MainActor in
                    await viewModel?.handleApiStarted(api: api.rawValue, message: message, answerId: answerId)
                }
            },
            onReflectionStarted: { [weak viewModel] round, sequence in
                Task { @MainActor in
                    await viewModel?.handleReflectionStarted(round: round, sequence: sequence, answerId: answerId)
                }
            },
            onReflectionComplete: { [weak viewModel] round, reflection, sequence in
                Task { @MainActor in
                    await viewModel?.handleReflectionComplete(round: round, reflection: reflection, sequence: sequence, answerId: answerId)
                }
            },
            onSourceSelectionStarted: { [weak viewModel] message, sequence in
                Task { @MainActor in
                    await viewModel?.handleSourceSelectionStarted(message: message, sequence: sequence, answerId: answerId)
                }
            },
            onSynthesisPreparation: { [weak viewModel] message, sequence in
                Task { @MainActor in
                    await viewModel?.handleSynthesisPreparation(message: message, sequence: sequence, answerId: answerId)
                }
            },
            onSynthesisStarted: { [weak viewModel] totalRounds, totalSources, sequence in
                Task { @MainActor in
                    await viewModel?.handleSynthesisStarted(totalRounds: totalRounds, totalSources: totalSources, sequence: sequence, answerId: answerId)
                }
            }
        )
    }
}
