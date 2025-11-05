//
//  ToastErrorHandler.swift
//  balli
//
//  Bridge between UnifiedError protocol and ToastNotification system
//

import SwiftUI

// MARK: - UnifiedError to Toast Conversion

extension UnifiedError {
    /// Convert error to user-friendly toast notification
    func toToast() -> ToastType {
        // Use localized description or fallback to category-based message
        let message = self.errorDescription ?? self.userFriendlyMessage
        return .error(message)
    }

    /// Generate user-friendly error message in Turkish
    private var userFriendlyMessage: String {
        switch category {
        case .network:
            return "Bağlantı hatası - lütfen internet bağlantınızı kontrol edin"
        case .data:
            return "Veri kaydedilemedi - lütfen tekrar deneyin"
        case .camera:
            return "Kamera hatası - lütfen izinleri kontrol edin"
        case .ai:
            return "AI işlemi başarısız oldu - lütfen tekrar deneyin"
        case .validation:
            return "Geçersiz veri - lütfen kontrol edin"
        case .authentication:
            return "Kimlik doğrulama hatası - lütfen giriş yapın"
        case .system:
            return "Sistem hatası - lütfen uygulamayı yeniden başlatın"
        case .unknown:
            return "Beklenmeyen hata oluştu"
        }
    }
}

// MARK: - Common Error Toast Messages

extension ToastType {
    // MARK: Data Operations
    static func dataSaveFailed(detail: String? = nil) -> ToastType {
        let message = detail ?? "Veri kaydedilemedi"
        return .error(message)
    }

    static func dataLoadFailed(detail: String? = nil) -> ToastType {
        let message = detail ?? "Veri yüklenemedi"
        return .error(message)
    }

    static func dataDeleteFailed(detail: String? = nil) -> ToastType {
        let message = detail ?? "Veri silinemedi"
        return .error(message)
    }

    // MARK: Meal Operations
    static func mealSaveFailed() -> ToastType {
        .error("Öğün kaydedilemedi - lütfen tekrar deneyin")
    }

    static func mealDataIncomplete() -> ToastType {
        .error("Öğün bilgileri eksik - lütfen tamamlayın")
    }

    static func mealSaveSuccess() -> ToastType {
        .success("Öğün kaydedildi")
    }

    // MARK: Glucose/Dexcom Operations
    static func glucoseSyncFailed() -> ToastType {
        .error("Glikoz verisi senkronize edilemedi")
    }

    static func glucoseDataMissing() -> ToastType {
        .error("Glikoz verisi bulunamadı - Dexcom bağlantınızı kontrol edin")
    }

    static func dexcomConnectionFailed() -> ToastType {
        .error("Dexcom bağlantısı başarısız - lütfen ayarları kontrol edin")
    }

    // MARK: Recipe Operations
    static func recipeSaveFailed() -> ToastType {
        .error("Tarif kaydedilemedi")
    }

    static func recipeLoadFailed() -> ToastType {
        .error("Tarif yüklenemedi")
    }

    static func recipeGenerationFailed() -> ToastType {
        .error("Tarif oluşturulamadı - lütfen tekrar deneyin")
    }

    // MARK: Network Operations
    static func networkUnavailable() -> ToastType {
        .error("İnternet bağlantısı yok - lütfen kontrol edin")
    }

    static func apiRequestFailed() -> ToastType {
        .error("İstek başarısız oldu - lütfen tekrar deneyin")
    }

    // MARK: Profile/User Data
    static func profileIncomplete() -> ToastType {
        .error("Profil bilgileriniz eksik - lütfen tamamlayın")
    }

    static func profileUpdateFailed() -> ToastType {
        .error("Profil güncellenemedi")
    }

    // MARK: System Errors
    static func storageUnavailable() -> ToastType {
        .error("Depolama alanına erişilemedi - lütfen yer açın")
    }

    static func initializationFailed() -> ToastType {
        .error("Başlatma hatası - lütfen uygulamayı yeniden başlatın")
    }

    // MARK: Research Operations
    static func researchFailed() -> ToastType {
        .error("Araştırma başarısız oldu - lütfen tekrar deneyin")
    }

    static func researchStorageFailed() -> ToastType {
        .error("Araştırma kaydedilemedi")
    }
}

// MARK: - ViewModel Toast Helper

/// Protocol for ViewModels that need toast notifications
@MainActor
protocol ToastCapable: AnyObject {
    var toastMessage: ToastType? { get set }
}

extension ToastCapable {
    /// Show error toast from UnifiedError
    func showError(_ error: any UnifiedError) {
        toastMessage = error.toToast()
    }

    /// Show error toast from any Error
    func showError(_ error: Error) {
        if let unifiedError = error as? any UnifiedError {
            toastMessage = unifiedError.toToast()
        } else {
            toastMessage = .error(error.localizedDescription)
        }
    }

    /// Show custom error message
    func showError(message: String) {
        toastMessage = .error(message)
    }

    /// Show success message
    func showSuccess(message: String) {
        toastMessage = .success(message)
    }
}

// MARK: - Error Handling Pattern Examples

/*
 EXAMPLE USAGE IN VIEWMODELS:

 class MyViewModel: ObservableObject, ToastCapable {
     @Published var toastMessage: ToastType?

     func saveData() async {
         do {
             try await service.save()
             showSuccess(message: "Kaydedildi")
         } catch let error as UnifiedError {
             showError(error)  // Automatically converts to toast
         } catch {
             showError(error)  // Generic error handling
         }
     }
 }

 EXAMPLE: Replacing force unwrap with toast notification:

 // BEFORE (crashes)
 let value = dangerousOperation()!

 // AFTER (safe with user feedback)
 guard let value = dangerousOperation() else {
     logger.error("Operation failed")
     toastMessage = .dataSaveFailed()
     return
 }
 */
