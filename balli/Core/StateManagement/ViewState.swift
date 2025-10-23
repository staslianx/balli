//
//  ViewState.swift
//  balli
//
//  Clean enum-based state management pattern for ViewModels
//  PERFORMANCE: Eliminates scattered @Published properties and clarifies state transitions
//

import Foundation

/// Generic state wrapper for ViewModel data loading and error handling
/// Replaces scattered loading/error/data @Published properties with single enum
public enum ViewState<T> {
    /// Initial state - no data loaded yet
    case idle

    /// Loading state - request in progress
    case loading

    /// Success state with loaded data
    case loaded(T)

    /// Error state with failure information
    case error(Error)
}

// MARK: - Convenience Properties

public extension ViewState {
    /// Returns true if currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Returns true if loaded successfully
    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    /// Returns true if in error state
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// Returns the loaded data if available
    var data: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }

    /// Returns the error if in error state
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Equatable Conformance

extension ViewState: Equatable where T: Equatable {
    public static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.loaded(let lhsValue), .loaded(let rhsValue)):
            return lhsValue == rhsValue
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Common ViewState Type Aliases

/// ViewState for arrays of items
public typealias ListState<T> = ViewState<[T]>

/// ViewState for optional single items
public typealias ItemState<T> = ViewState<T?>

/// ViewState for void/completion operations
public typealias OperationState = ViewState<Void>
