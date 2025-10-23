//
//  HealthKitTypes.swift
//  balli
//
//  Shared types for HealthKit services
//  Swift 6 strict concurrency compliant
//

import Foundation
import HealthKit

// MARK: - HealthKit Errors

enum HealthKitError: LocalizedError, Sendable {
    case notAvailable
    case notAuthorized
    case authorizationFailed(Error)
    case queryFailed(Error)
    case readOnlyMode
    case invalidData
    case alreadyLoading
    case debounced(remainingTime: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Sağlık verileri bu cihazda kullanılamıyor. iPhone veya iPad gereklidir."

        case .notAuthorized:
            return "Sağlık verilerine erişim izni yok. Ayarlar > Sağlık > Veri Erişimi > balli'den izinleri etkinleştirin."

        case .authorizationFailed(let error):
            // Check for specific error types
            if let hkError = error as NSError?, hkError.domain == HKErrorDomain {
                switch HKError.Code(rawValue: hkError.code) {
                case .errorAuthorizationDenied:
                    return "Sağlık izni reddedildi. Ayarlar'dan izinleri etkinleştirin."
                case .errorAuthorizationNotDetermined:
                    return "Sağlık izni belirlenmedi. Lütfen izin verin."
                default:
                    return "Sağlık izni alınamadı. Lütfen Ayarlar'dan izinleri kontrol edin."
                }
            }
            return "Sağlık izni alınamadı. Lütfen Ayarlar'dan izinleri kontrol edin."

        case .queryFailed(let error):
            // Check for specific HealthKit error types
            if let hkError = error as NSError?, hkError.domain == HKErrorDomain {
                switch HKError.Code(rawValue: hkError.code) {
                case .errorDatabaseInaccessible:
                    return "Sağlık veritabanına erişilemiyor. Lütfen daha sonra tekrar deneyin."
                case .errorNoData:
                    return "Bu tarih aralığında sağlık verisi bulunamadı."
                case .errorAuthorizationDenied:
                    return "Sağlık verilerine erişim reddedildi. Ayarlar'dan izinleri kontrol edin."
                default:
                    return "Sağlık verileri yüklenemedi. Lütfen tekrar deneyin."
                }
            }
            return "Sağlık verileri yüklenemedi. Lütfen tekrar deneyin."

        case .readOnlyMode:
            return "Sağlık verileri salt okunur modda. Veri yazılamıyor."

        case .invalidData:
            return "Geçersiz sağlık verisi formatı. Lütfen destek ile iletişime geçin."

        case .alreadyLoading:
            return "Veriler yükleniyor..."

        case .debounced(let remainingTime):
            return "Çok fazla istek gönderildi. Lütfen \(String(format: "%.0f", remainingTime)) saniye bekleyin."
        }
    }

    var failureReason: String? {
        switch self {
        case .notAvailable:
            return "Bu cihaz HealthKit'i desteklemiyor"
        case .notAuthorized:
            return "Kullanıcı izin vermedi"
        case .authorizationFailed:
            return "İzin alma işlemi başarısız"
        case .queryFailed:
            return "Veri sorgusu başarısız"
        case .readOnlyMode:
            return "Yazma izni yok"
        case .invalidData:
            return "Veri formatı hatalı"
        case .alreadyLoading:
            return "Önceki yükleme devam ediyor"
        case .debounced:
            return "İstek limiti aşıldı"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAvailable:
            return "iPhone veya iPad kullanın."
        case .notAuthorized:
            return "Ayarlar > Sağlık > Veri Erişimi > balli'den gerekli izinleri verin."
        case .authorizationFailed:
            return "Uygulamayı yeniden başlatıp tekrar deneyin. Sorun devam ederse Ayarlar'dan izinleri kontrol edin."
        case .queryFailed:
            return "İnternet bağlantınızı kontrol edin ve tekrar deneyin."
        case .readOnlyMode:
            return "Ayarlar'dan yazma izni verin."
        case .invalidData:
            return "Sorununuz devam ederse destek ile iletişime geçin."
        case .alreadyLoading:
            return "Önceki yükleme tamamlanana kadar bekleyin."
        case .debounced:
            return "Birkaç saniye bekleyin ve tekrar deneyin."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let glucoseDataUpdated = Notification.Name("glucoseDataUpdated")
    static let nutritionDataUpdated = Notification.Name("nutritionDataUpdated")
}

// MARK: - Statistics Types

struct GlucoseStatistics: Sendable {
    let average: Double
    let min: Double
    let max: Double
    let standardDeviation: Double
    let timeInRange: Double // Percentage
    let readingCount: Int
    let dateInterval: DateInterval
}

struct GlucosePattern: Sendable {
    let mealTime: Date
    let preMealAverage: Double?
    let postMealPeak: Double?
    let glucoseRise: Double?
    let readingsAnalyzed: Int
}
