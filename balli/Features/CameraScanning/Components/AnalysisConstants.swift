//
//  AnalysisConstants.swift
//  balli
//
//  Constants and configuration for AI Analysis
//

import SwiftUI

/// Analysis stage enumeration with Turkish messages
public enum AnalysisStage {
    case preparing
    case analyzing
    case reading
    case sending
    case processing
    case validating
    case completed
    case error
    
    /// Turkish message for each stage
    public var message: String {
        switch self {
        case .preparing: return "İnceliyorum"
        case .analyzing: return "Analiz ediyorum"
        case .reading: return "Sadeleştiriyorum"
        case .sending: return "Etiketini oluşturuyorum"
        case .processing: return "Sağlamasını yapıyorum"
        case .validating: return "Son bi bakıyorum..."
        case .completed: return "Etiketin hazır!"
        case .error: return "Bir hata oluştu"
        }
    }
    
    /// Target progress percentage for each stage
    public var targetProgress: Double {
        switch self {
        case .preparing: return 0.15    // Stage 1: 0-25%
        case .analyzing: return 0.33    // Stage 2: 25-50%
        case .reading: return 0.41      // Stage 3: 50-75%
        case .sending: return 0.64      // Stage 4: 75-100%
        case .processing: return 0.73   // Complete
        case .validating: return 0.92   // Complete
        case .completed: return 1.00    // Complete
        case .error: return 0           // Keep current progress on error
        }
    }
    
    /// Icon for each stage
    public var icon: String {
        switch self {
        case .preparing: return "text.magnifyingglass"
        case .analyzing: return "app.background.dotted"
        case .reading: return "scale.3d"
        case .sending: return "append.page"
        case .processing: return "compass.drawing"
        case .validating: return "character.magnify"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    /// Icon color for each stage
    public var iconColor: Color {
        switch self {
        case .completed: return .green
        case .error: return .red
        default: return AppTheme.primaryPurple
        }
    }
}
