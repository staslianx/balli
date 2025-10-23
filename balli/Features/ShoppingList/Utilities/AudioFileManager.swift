//
//  AudioFileManager.swift
//  balli
//
//  File management functionality for audio recordings
//  Handles file operations, cleanup, and storage optimization
//

import Foundation
import os.log

// MARK: - Audio File Management Actor

actor AudioFileManager {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "AudioFileManager")
    
    // File management configuration
    private let documentsDirectory: URL
    private let maxFileAge: TimeInterval = 3600 // 1 hour
    private let maxDirectorySize: Int64 = 50_000_000 // 50MB
    
    init() {
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logger.info("AudioFileManager initialized")
        
        // Start periodic cleanup task
        Task {
            await performPeriodicCleanup()
        }
    }
    
    // MARK: - File Operations
    
    func generateRecordingURL() async -> URL {
        let timestamp = Date().timeIntervalSince1970
        let filename = "voice_recording_\(timestamp).wav"
        return documentsDirectory.appendingPathComponent(filename)
    }
    
    func saveAudioData(_ data: Data, to url: URL) async throws {
        do {
            try data.write(to: url)
            logger.info("Audio data saved to: \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to save audio data: \(error)")
            throw VoiceRecordingError.recordingFailed("Failed to save audio file: \(error.localizedDescription)")
        }
    }
    
    func loadAudioData(from url: URL) async throws -> Data {
        do {
            let data = try Data(contentsOf: url)
            logger.info("Audio data loaded: \(data.count) bytes from \(url.lastPathComponent)")
            return data
        } catch {
            logger.error("Failed to load audio data from \(url.lastPathComponent): \(error)")
            throw VoiceRecordingError.processingFailed("Failed to load audio file: \(error.localizedDescription)")
        }
    }
    
    func cleanupRecordingFile(at url: URL?) async {
        guard let url = url else { return }
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                logger.info("Cleaned up recording file: \(url.lastPathComponent)")
            }
        } catch {
            logger.error("Failed to cleanup recording file \(url.lastPathComponent): \(error)")
        }
    }
    
    func fileExists(at url: URL) async -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    func getFileSize(at url: URL) async -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            logger.error("Failed to get file size for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    // MARK: - Directory Management
    
    func getAllRecordingFiles() async -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            return contents.filter { url in
                url.pathExtension.lowercased() == "wav" && 
                url.lastPathComponent.hasPrefix("voice_recording_")
            }
        } catch {
            logger.error("Failed to list recording files: \(error)")
            return []
        }
    }
    
    func calculateDirectorySize() async -> Int64 {
        let files = await getAllRecordingFiles()
        var totalSize: Int64 = 0
        
        for file in files {
            if let size = await getFileSize(at: file) {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    // MARK: - Cleanup Operations
    
    func cleanupOldFiles() async {
        let files = await getAllRecordingFiles()
        let now = Date()
        
        for file in files {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    let age = now.timeIntervalSince(creationDate)
                    
                    if age > maxFileAge {
                        try FileManager.default.removeItem(at: file)
                        logger.info("Cleaned up old recording file: \(file.lastPathComponent)")
                    }
                }
            } catch {
                logger.error("Failed to cleanup old file \(file.lastPathComponent): \(error)")
            }
        }
    }
    
    func cleanupLargeDirectory() async {
        let currentSize = await calculateDirectorySize()
        
        guard currentSize > self.maxDirectorySize else { return }
        
        logger.warning("Directory size (\(currentSize) bytes) exceeds limit (\(self.maxDirectorySize) bytes)")
        
        // Get files sorted by creation date (oldest first)
        let files = await getAllRecordingFiles()
        var filesToCleanup: [(URL, Date)] = []
        
        for file in files {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    filesToCleanup.append((file, creationDate))
                }
            } catch {
                logger.error("Failed to get attributes for \(file.lastPathComponent): \(error)")
            }
        }
        
        // Sort by creation date (oldest first)
        filesToCleanup.sort { $0.1 < $1.1 }
        
        // Remove files until we're under the size limit
        var remainingSize = currentSize
        
        for (file, _) in filesToCleanup {
            guard remainingSize > self.maxDirectorySize else { break }
            
            if let fileSize = await getFileSize(at: file) {
                do {
                    try FileManager.default.removeItem(at: file)
                    remainingSize -= fileSize
                    logger.info("Cleaned up large directory file: \(file.lastPathComponent)")
                } catch {
                    logger.error("Failed to cleanup large directory file \(file.lastPathComponent): \(error)")
                }
            }
        }
    }
    
    private func performPeriodicCleanup() async {
        while true {
            do {
                // Sleep for 30 minutes between cleanup cycles
                try await Task.sleep(nanoseconds: 1_800_000_000_000) // 30 minutes
                
                await cleanupOldFiles()
                await cleanupLargeDirectory()
                
                logger.info("Periodic cleanup completed")
            } catch {
                logger.error("Periodic cleanup interrupted: \(error)")
                break
            }
        }
    }
    
    // MARK: - Storage Statistics
    
    func getStorageStatistics() async -> AudioStorageStatistics {
        let files = await getAllRecordingFiles()
        let totalSize = await calculateDirectorySize()
        
        var oldestFile: Date?
        var newestFile: Date?
        
        for file in files {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    if let oldest = oldestFile {
                        if creationDate < oldest {
                            oldestFile = creationDate
                        }
                    } else {
                        oldestFile = creationDate
                    }

                    if let newest = newestFile {
                        if creationDate > newest {
                            newestFile = creationDate
                        }
                    } else {
                        newestFile = creationDate
                    }
                }
            } catch {
                logger.error("Failed to get file attributes: \(error)")
            }
        }
        
        return AudioStorageStatistics(
            fileCount: files.count,
            totalSize: totalSize,
            oldestFileDate: oldestFile,
            newestFileDate: newestFile,
            isOverSizeLimit: totalSize > self.maxDirectorySize
        )
    }
}

// MARK: - Storage Statistics Model

struct AudioStorageStatistics: Sendable {
    let fileCount: Int
    let totalSize: Int64
    let oldestFileDate: Date?
    let newestFileDate: Date?
    let isOverSizeLimit: Bool
}