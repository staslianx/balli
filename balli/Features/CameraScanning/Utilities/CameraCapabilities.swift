//
//  CameraCapabilities.swift
//  balli
//
//  Camera device discovery and capability management
//

import Foundation
import AVFoundation
import UIKit
import os.log

/// Manages camera device discovery and capabilities
@MainActor
public class CameraCapabilities {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CameraCapabilities")
    
    // MARK: - Properties
    private var discoverySession: AVCaptureDevice.DiscoverySession?
    private var availableDevices: [AVCaptureDevice] = []
    private var configuration: CameraConfiguration?
    private var deviceMap: [CameraZoom: AVCaptureDevice] = [:]
    
    // MARK: - Public Interface
    
    /// Discover available cameras and their capabilities
    public func discoverCameras() throws -> CameraConfiguration {
        logger.info("Starting camera discovery")
        
        // Create discovery session for all camera types
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInTripleCamera
            ],
            mediaType: .video,
            position: .back
        )
        
        self.discoverySession = discoverySession
        self.availableDevices = discoverySession.devices
        
        // Log discovered devices
        for device in availableDevices {
            logger.info("Discovered device: \(device.localizedName), type: \(device.deviceType.rawValue)")
        }
        
        // Determine capabilities
        let hasUltraWide = hasDevice(ofType: .builtInUltraWideCamera)
        let hasWide = hasDevice(ofType: .builtInWideAngleCamera)
        let (hasTelephoto, telephotoZoom) = getTelephotoInfo()
        
        // Determine default camera
        let defaultCamera: AVCaptureDevice.DeviceType = hasWide ? .builtInWideAngleCamera : .builtInDualCamera
        
        // Build configuration
        let supportedZoomLevels = CameraConfiguration.availableZoomLevels(
            hasUltraWide: hasUltraWide,
            hasTelephoto: hasTelephoto,
            telephotoZoom: telephotoZoom
        )
        
        let config = CameraConfiguration(
            hasUltraWide: hasUltraWide,
            hasWide: hasWide,
            hasTelephoto: hasTelephoto,
            telephotoZoomFactor: telephotoZoom,
            supportedZoomLevels: supportedZoomLevels,
            defaultCamera: defaultCamera
        )
        
        self.configuration = config
        
        // Build device map for zoom levels
        buildDeviceMap(config: config)
        
        logger.info("Camera discovery complete. Ultra-wide: \(hasUltraWide), Wide: \(hasWide), Telephoto: \(hasTelephoto) (\(telephotoZoom)x)")
        
        return config
    }
    
    /// Get the camera device for a specific zoom level
    public func device(for zoomLevel: CameraZoom) async -> AVCaptureDevice? {
        // Ensure we have discovered cameras
        if configuration == nil {
            do {
                _ = try discoverCameras()
            } catch {
                logger.error("Failed to discover cameras: \(error)")
                return nil
            }
        }
        
        // Return mapped device or fallback to default
        if let device = deviceMap[zoomLevel] {
            return device
        }
        
        // Fallback to wide angle camera
        return getDevice(ofType: .builtInWideAngleCamera)
    }
    
    /// Get the actual zoom factor to apply for a given zoom level
    public func actualZoomFactor(for zoomLevel: CameraZoom, on device: AVCaptureDevice) -> CGFloat {
        // If we have the exact camera for this zoom level, use 1.0
        if let mappedDevice = deviceMap[zoomLevel], mappedDevice == device {
            return 1.0
        }
        
        // Otherwise, calculate the zoom factor needed
        guard let config = configuration else { return 1.0 }
        
        // Determine base zoom of current device
        let baseZoom: CGFloat
        switch device.deviceType {
        case .builtInUltraWideCamera:
            baseZoom = 0.5
        case .builtInWideAngleCamera:
            baseZoom = 1.0
        case .builtInTelephotoCamera:
            baseZoom = config.telephotoZoomFactor
        default:
            baseZoom = 1.0
        }
        
        // Calculate relative zoom
        let targetZoom = zoomLevel.zoomFactor
        let relativeZoom = targetZoom / baseZoom
        
        // Clamp to device limits
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor
        
        return max(minZoom, min(relativeZoom, maxZoom))
    }
    
    /// Check if a specific camera type is available
    public func hasCamera(type: AVCaptureDevice.DeviceType) -> Bool {
        hasDevice(ofType: type)
    }
    
    /// Get current configuration
    public func getConfiguration() -> CameraConfiguration? {
        configuration
    }
    
    /// Get the best camera for capturing nutrition labels
    public func getBestCameraForScanning() -> AVCaptureDevice? {
        // Prefer triple camera system for highest quality
        if let triple = getDevice(ofType: .builtInTripleCamera) {
            configureForHighQuality(triple)
            return triple
        }
        
        // Try dual wide camera for better quality
        if let dualWide = getDevice(ofType: .builtInDualWideCamera) {
            configureForHighQuality(dualWide)
            return dualWide
        }
        
        // Try dual camera
        if let dual = getDevice(ofType: .builtInDualCamera) {
            configureForHighQuality(dual)
            return dual
        }
        
        // Fallback to wide angle camera
        if let wide = getDevice(ofType: .builtInWideAngleCamera) {
            configureForHighQuality(wide)
            return wide
        }
        
        // Last resort: any available camera
        if let device = availableDevices.first {
            configureForHighQuality(device)
            return device
        }
        
        return nil
    }
    
    /// Configure device for highest quality capture
    private func configureForHighQuality(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // Enable continuous autofocus for sharp images
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            // Enable auto exposure for proper lighting
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // Enable auto white balance
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Enable HDR if available
            if device.activeFormat.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = true
            }
            
            // Set best format for quality
            let formats = device.formats
            let bestFormat = formats.filter { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width >= 1920 && dimensions.height >= 1080
            }.sorted { format1, format2 in
                let dim1 = CMVideoFormatDescriptionGetDimensions(format1.formatDescription)
                let dim2 = CMVideoFormatDescriptionGetDimensions(format2.formatDescription)
                return (dim1.width * dim1.height) > (dim2.width * dim2.height)
            }.first
            
            if let bestFormat = bestFormat {
                device.activeFormat = bestFormat
                let dimensions = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription)
                logger.info("Set camera format to \(dimensions.width)x\(dimensions.height)")
            }
            
            device.unlockForConfiguration()
        } catch {
            logger.error("Failed to configure camera for high quality: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func hasDevice(ofType type: AVCaptureDevice.DeviceType) -> Bool {
        availableDevices.contains { $0.deviceType == type }
    }
    
    private func getDevice(ofType type: AVCaptureDevice.DeviceType) -> AVCaptureDevice? {
        availableDevices.first { $0.deviceType == type }
    }
    
    private func getTelephotoInfo() -> (hasTelephoto: Bool, zoomFactor: CGFloat) {
        guard getDevice(ofType: .builtInTelephotoCamera) != nil else {
            return (false, 2.0)
        }
        
        // Try to determine zoom factor from device
        // Most iPhones have 2x or 3x telephoto
        // Default to 2x for now
        return (true, 2.0)
    }
    
    private func buildDeviceMap(config: CameraConfiguration) {
        deviceMap.removeAll()
        
        // Map zoom levels to actual devices
        for zoomLevel in config.supportedZoomLevels {
            switch zoomLevel {
            case .halfX:
                if let ultraWide = getDevice(ofType: .builtInUltraWideCamera) {
                    deviceMap[.halfX] = ultraWide
                }
                
            case .oneX:
                if let wide = getDevice(ofType: .builtInWideAngleCamera) {
                    deviceMap[.oneX] = wide
                } else if let dual = getDevice(ofType: .builtInDualCamera) {
                    deviceMap[.oneX] = dual
                }
                
            case .twoX:
                if config.telephotoZoomFactor <= 2.0,
                   let telephoto = getDevice(ofType: .builtInTelephotoCamera) {
                    deviceMap[.twoX] = telephoto
                }
                
            case .threeX:
                if config.telephotoZoomFactor >= 3.0,
                   let telephoto = getDevice(ofType: .builtInTelephotoCamera) {
                    deviceMap[.threeX] = telephoto
                }
            }
        }
        
        logger.info("Device map built with \(self.deviceMap.count) entries")
    }
}

// MARK: - Device Extensions
extension AVCaptureDevice.DeviceType {
    /// Human-readable name for the device type
    var displayName: String {
        switch self {
        case .builtInWideAngleCamera:
            return "Geniş Açı"
        case .builtInUltraWideCamera:
            return "Ultra Geniş Açı"
        case .builtInTelephotoCamera:
            return "Telefoto"
        case .builtInDualCamera:
            return "Çift Kamera"
        case .builtInDualWideCamera:
            return "Çift Geniş Açı"
        case .builtInTripleCamera:
            return "Üçlü Kamera"
        default:
            return "Kamera"
        }
    }
}

// MARK: - Device Helpers
extension CameraCapabilities {
    /// Get a user-friendly description of camera capabilities
    public func capabilityDescription() -> String {
        guard let config = configuration else {
            return "Kamera bilgisi yok"
        }
        
        var components: [String] = []
        
        if config.hasUltraWide {
            components.append("0.5x Ultra Geniş")
        }
        
        if config.hasWide {
            components.append("1x Geniş")
        }
        
        if config.hasTelephoto {
            let zoom = Int(config.telephotoZoomFactor)
            components.append("\(zoom)x Telefoto")
        }
        
        return components.joined(separator: ", ")
    }
    
    /// Check if device supports a specific zoom level
    public func supportsZoomLevel(_ zoomLevel: CameraZoom) async -> Bool {
        guard let config = configuration else { return false }
        return config.supportedZoomLevels.contains(zoomLevel)
    }
}