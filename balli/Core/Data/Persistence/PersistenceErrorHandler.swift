//
//  PersistenceErrorHandler.swift
//  balli
//
//  Handles Core Data save errors with smart retry logic and user notifications
//

import CoreData
import OSLog
import Foundation

/// Handles Core Data save operations with retry logic and error classification
actor PersistenceErrorHandler {

    // MARK: - Constants

    private enum Constants {
        static let maxRetries = 3
        static let retryDelays: [UInt64] = [
            100_000_000,   // 100ms
            500_000_000,   // 500ms
            1_000_000_000  // 1s
        ]
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli.diabetes", category: "persistence.error")

    // MARK: - Public API

    /// Save context with automatic retry for transient errors
    /// - Parameter context: The managed object context to save
    /// - Throws: PersistenceError if save fails after all retries
    func saveWithRetry(context: NSManagedObjectContext) async throws {
        var attempt = 0
        var lastError: Error?

        while attempt < Constants.maxRetries {
            do {
                // Attempt save using continuation
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    context.perform {
                        do {
                            if context.hasChanges {
                                try context.save()
                            }
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }

                // Success - post notification
                await postSuccessNotification()

                if attempt > 0 {
                    logger.info("✅ Save succeeded after \(attempt) retries")
                }

                return

            } catch {
                lastError = error
                attempt += 1

                let shouldRetry = self.shouldRetryError(error)

                if shouldRetry && attempt < Constants.maxRetries {
                    // Log retry attempt
                    logger.warning("⚠️ Save failed (attempt \(attempt)/\(Constants.maxRetries)): \(error.localizedDescription)")

                    // Wait before retry with exponential backoff
                    let delayIndex = min(attempt - 1, Constants.retryDelays.count - 1)
                    try? await Task.sleep(nanoseconds: Constants.retryDelays[delayIndex])

                } else {
                    // Don't retry - fail immediately
                    break
                }
            }
        }

        // All retries exhausted or fatal error - notify and throw
        let finalError = classifyError(lastError!)
        logger.error("❌ Save failed after \(attempt) attempts: \(finalError.localizedDescription)")

        await postFailureNotification(error: finalError)

        throw finalError
    }

    // MARK: - Error Classification

    /// Determine if error should be retried
    private func shouldRetryError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Check for transient Core Data errors
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSPersistentStoreSaveConflictsError,
                 NSPersistentStoreTimeoutError,
                 NSManagedObjectMergeError:
                return true
            default:
                break
            }
        }

        // Check for SQLite transient errors
        if nsError.domain == NSSQLiteErrorDomain {
            switch nsError.code {
            case 5:  // SQLITE_BUSY - database locked
                return true
            default:
                break
            }
        }

        return false
    }

    /// Classify error into persistence error type
    private func classifyError(_ error: Error) -> PersistenceError {
        // Wrap all errors as saveFailed with the underlying error
        return .saveFailed(error)
    }

    // MARK: - Notifications

    private func postSuccessNotification() async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .persistenceSaveSuccess,
                object: nil
            )
        }
    }

    private func postFailureNotification(error: PersistenceError) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .persistenceSaveFailure,
                object: nil,
                userInfo: ["error": error]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when Core Data save succeeds
    static let persistenceSaveSuccess = Notification.Name("persistenceSaveSuccess")

    /// Posted when Core Data save fails after all retries
    static let persistenceSaveFailure = Notification.Name("persistenceSaveFailure")
}
