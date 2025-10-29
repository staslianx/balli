//
//  CurveWarningLevel.swift
//  balli
//
//  Warning levels for insulin-glucose curve mismatch
//  Determines when to show warnings and their severity
//

import SwiftUI

/// Warning level for insulin-glucose curve mismatch
enum CurveWarningLevel: Sendable {
    case none       // No warning needed (good alignment)
    case info       // Informational (slight mismatch, manageable)
    case warning    // Caution needed (moderate mismatch)
    case danger     // High risk (severe mismatch)

    /// Background color with appropriate opacity for the warning level
    var backgroundColor: Color {
        switch self {
        case .none:
            return .clear
        case .info:
            return Color.blue.opacity(0.1)
        case .warning:
            return Color.yellow.opacity(0.15)
        case .danger:
            return Color.red.opacity(0.15)
        }
    }

    /// Border color for the warning card
    var borderColor: Color {
        switch self {
        case .none:
            return .clear
        case .info:
            return .blue
        case .warning:
            return .yellow
        case .danger:
            return .red
        }
    }

    /// SF Symbol icon name for the warning
    var iconName: String {
        switch self {
        case .none:
            return ""
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .danger:
            return "exclamationmark.octagon.fill"
        }
    }

    /// Turkish title for the warning card
    var title: String {
        switch self {
        case .none:
            return ""
        case .info:
            return "Bilgilendirme"
        case .warning:
            return "Dikkat"
        case .danger:
            return "Yüksek Yağ Uyarısı"
        }
    }

    /// Get warning message based on mismatch, fat, and protein values
    func getMessage(mismatchMinutes: Int, fatGrams: Double, proteinGrams: Double) -> String {
        let mismatchHours = Double(mismatchMinutes) / 60.0

        switch self {
        case .none:
            return ""

        case .info:
            if mismatchMinutes < 30 {
                return "✅ İYİ DENGE: İnsülin ve glikoz neredeyse eşleşiyor!"
            } else {
                let peakTime = 75 + mismatchMinutes  // NovoRapid peak + mismatch
                return "ℹ️ Hafif uyumsuzluk var. Normal dozlama yeterli, ama \(peakTime) dakika sonra kontrol et."
            }

        case .warning:
            if proteinGrams > 30 {
                return "⚠️ Yüksek Protein (\(String(format: "%.0f", proteinGrams))g): 2-3 saat sonra gecikmeli yükseliş olabilir."
            } else if fatGrams > 20 && fatGrams <= 30 {
                return "⚠️ Orta Yağ (\(String(format: "%.0f", fatGrams))g): İnsülin bittiğinde hafif yükseliş beklenebilir."
            } else {
                return "⚠️ Orta Seviye Uyumsuzluk: \(String(format: "%.1f", mismatchHours)) saat sonra glikoz kontrol et."
            }

        case .danger:
            if fatGrams > 40 {
                return "⚠️ ÇOK YÜKSEK YAĞ (\(String(format: "%.0f", fatGrams))g): Split doz veya 2. düzeltme dozu gerekebilir!"
            } else if mismatchMinutes > 120 {
                return "⚠️ ÇOK GEÇ ETKİ: Glikoz yükselmesi insülin etkisinden \(String(format: "%.1f", mismatchHours)) saat sonra başlayacak!"
            } else {
                return "⚠️ YÜKSEK YAĞ UYARISI: İnsülin etkisi erken biter, glikoz 3-4 saat sonra hala yüksek olacak!"
            }
        }
    }

    /// Get actionable recommendations based on warning level
    func getRecommendations(mismatchMinutes: Int, fatGrams: Double) -> [String] {
        let mismatchHours = Int(mismatchMinutes / 60)

        switch self {
        case .none:
            return []

        case .info:
            return [
                "Normal dozlama yeterli",
                "2 saat sonra rutin kontrol yap"
            ]

        case .warning:
            return [
                "\(max(2, mismatchHours)) saat sonra glikoz kontrol et",
                "Hafif düzeltme dozu hazır tut",
                "Bir dahaki sefere daha düşük yağlı alternatif dene"
            ]

        case .danger:
            if mismatchMinutes > 240 {
                // Extreme mismatch (>4 hours)
                return [
                    "Bu tarifte çok dikkatli ol - doktora danış",
                    "İnsülin pompası dual-wave dozu düşün",
                    "Manuel: %70 şimdi + %30 2 saat sonra",
                    "Geceye kadar (6+ saat) glikoz takip et"
                ]
            } else {
                return [
                    "2 saat sonra glikoz ölç (insülin pik sırasında)",
                    "\(max(3, mismatchHours)) saat sonra tekrar kontrol et (glikoz piki)",
                    "Gerekirse düzeltme dozu yap",
                    "Alternatif: Split doz düşün (insülin pompası kullanıyorsan)"
                ]
            }
        }
    }

    /// Determine warning level based on mismatch, fat, and glycemic load
    /// - Parameters:
    ///   - mismatchMinutes: Absolute difference between insulin and glucose peak times
    ///   - fatGrams: Total fat in grams (per serving)
    ///   - glycemicLoad: Glycemic load (per serving)
    /// - Returns: Appropriate warning level
    static func determine(mismatchMinutes: Int, fatGrams: Double, glycemicLoad: Double) -> CurveWarningLevel {
        // Priority 1: Very high fat (>30g) = always show danger
        if fatGrams > 30 {
            return .danger
        }

        // Priority 2: High mismatch (>120 min) = danger regardless of fat
        if mismatchMinutes > 120 {
            return .danger
        }

        // Priority 3: Moderate mismatch (60-120 min) + high GL = warning
        if mismatchMinutes > 60 && glycemicLoad > 15 {
            return .warning
        }

        // Priority 4: Moderate mismatch (60-120 min) + low GL = info
        if mismatchMinutes > 60 {
            return .info
        }

        // Priority 5: Small mismatch (30-60 min) + very high fat (20-30g) = warning
        if mismatchMinutes > 30 && fatGrams > 20 {
            return .warning
        }

        // No warning needed - good alignment
        return .none
    }
}
