//
//  CameraDataState.swift
//  balli
//
//  Camera capture and label scanning state management
//

import SwiftUI
import Combine

// MARK: - Camera Data State Manager
@MainActor
final class CameraDataState: ObservableObject {
    static let shared = CameraDataState()

    // MARK: - Published Properties
    @Published var lastCapturedImage: UIImage?
    @Published var lastScanResult: NutritionExtractionResult?

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Camera Methods

    func updateCapturedImage(_ image: UIImage) {
        lastCapturedImage = image
    }

    func updateScanResult(_ result: NutritionExtractionResult) {
        lastScanResult = result
    }

    func clearScanData() {
        lastCapturedImage = nil
        lastScanResult = nil
    }
}

// MARK: - Environment Key
private struct CameraDataStateKey: EnvironmentKey {
    static let defaultValue: CameraDataState? = nil
}

extension EnvironmentValues {
    var cameraDataState: CameraDataState {
        get {
            if let state = self[CameraDataStateKey.self] {
                return state
            }
            return MainActor.assumeIsolated {
                CameraDataState.shared
            }
        }
        set { self[CameraDataStateKey.self] = newValue }
    }
}
