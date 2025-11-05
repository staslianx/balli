//
//  AIResultUIState.swift
//  balli
//
//  UI state for AI result screen
//

import Foundation

/// Represents the UI state for the AI result screen
struct AIResultUIState: Sendable {
    // MARK: - Edit Mode State

    var isEditing: Bool
    var showEditButton: Bool
    var showSaveButtons: Bool

    // MARK: - Display State

    var showImpactBanner: Bool
    var showingValues: Bool
    var showSlider: Bool  // Controls slider visibility based on state

    // MARK: - Save State

    var isSaving: Bool
    var isSaveInProgress: Bool

    // MARK: - Validation State

    var validationErrors: [String]
    var validationWarnings: [String]

    // MARK: - Animation State

    var valuesAnimationProgress: [String: Bool]

    // MARK: - Initialization

    /// Initialize for read-only mode (after analysis)
    /// Shows label with impact banner WITH slider, checkmark button
    /// Values show adjusted amounts but are tappable to edit base values
    static func readOnly() -> AIResultUIState {
        AIResultUIState(
            isEditing: false,  // ✅ Show adjusted values (slider updates them in real-time)
            showEditButton: false,
            showSaveButtons: false,
            showImpactBanner: true,
            showingValues: true,
            showSlider: true,  // ✅ Show slider immediately after analysis
            isSaving: false,
            isSaveInProgress: false,
            validationErrors: [],
            validationWarnings: [],
            valuesAnimationProgress: [:]
        )
    }

    /// Initialize for edit mode
    /// Shows editable label WITH slider, only checkmark button
    static func editing() -> AIResultUIState {
        AIResultUIState(
            isEditing: true,
            showEditButton: false,
            showSaveButtons: false,
            showImpactBanner: true,
            showingValues: true,
            showSlider: true,  // ✅ Show slider in edit mode
            isSaving: false,
            isSaveInProgress: false,
            validationErrors: [],
            validationWarnings: [],
            valuesAnimationProgress: [:]
        )
    }

    /// Initialize for save-ready mode (after editing)
    /// Shows read-only label WITH slider (final values), pencil + save buttons
    static func saveReady() -> AIResultUIState {
        AIResultUIState(
            isEditing: false,
            showEditButton: false,
            showSaveButtons: true,
            showImpactBanner: true,
            showingValues: true,
            showSlider: true,  // ✅ Keep slider visible to show final portion
            isSaving: false,
            isSaveInProgress: false,
            validationErrors: [],
            validationWarnings: [],
            valuesAnimationProgress: [:]
        )
    }

    /// Initialize for analyzing mode (before results)
    static func analyzing() -> AIResultUIState {
        AIResultUIState(
            isEditing: false,
            showEditButton: false,
            showSaveButtons: false,
            showImpactBanner: false,
            showingValues: false,
            showSlider: false,  // ❌ No slider during analysis
            isSaving: false,
            isSaveInProgress: false,
            validationErrors: [],
            validationWarnings: [],
            valuesAnimationProgress: [:]
        )
    }

    // MARK: - State Transitions

    /// Toggle edit mode based on current state
    mutating func toggleEditMode() {
        if showEditButton && !isEditing {
            // User clicked edit button - enter edit mode
            isEditing = true
            showEditButton = false
            showSaveButtons = false
        } else if isEditing && !showSaveButtons {
            // User clicked done button - exit edit mode and show save buttons
            isEditing = false
            showEditButton = false
            showSaveButtons = true
        } else if showSaveButtons {
            // User clicked edit button again - re-enter edit mode
            isEditing = true
            showSaveButtons = false
        }
    }

    /// Start save operation
    mutating func startSaving() {
        isSaving = true
        isSaveInProgress = true
    }

    /// Complete save operation
    mutating func completeSaving() {
        isSaving = false
        isSaveInProgress = false
    }

    /// Set validation errors
    mutating func setValidationErrors(_ errors: [String], warnings: [String]) {
        validationErrors = errors
        validationWarnings = warnings
    }

    /// Clear validation errors
    mutating func clearValidationErrors() {
        validationErrors = []
        validationWarnings = []
    }
}
