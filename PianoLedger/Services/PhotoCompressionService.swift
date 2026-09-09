import Foundation
import UIKit

// MARK: - Photo Compression Service
class PhotoCompressionService {
    
    // Compression quality presets
    enum CompressionQuality {
        case low       // ~200KB, 800px max dimension
        case medium    // ~500KB, 1200px max dimension  
        case high      // ~1MB, 1920px max dimension
        
        var maxDimension: CGFloat {
            switch self {
            case .low: return 800
            case .medium: return 1200
            case .high: return 1920
            }
        }
        
        var jpegQuality: CGFloat {
            switch self {
            case .low: return 0.5
            case .medium: return 0.7
            case .high: return 0.85
            }
        }
    }
    
    // Compress image
    static func compress(_ image: UIImage, quality: CompressionQuality = .medium) -> Data? {
        // 1. Resize if needed
        let resized = resizeImage(image, maxDimension: quality.maxDimension)
        
        // 2. Compress to JPEG
        guard let data = resized.jpegData(compressionQuality: quality.jpegQuality) else {
            return nil
        }
        
        print("📸 Photo compressed: \(originalSize(image)) → \(formatSize(data.count))")
        return data
    }
    
    // Resize image maintaining aspect ratio
    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // Check if resize is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Resize
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resized ?? image
    }
    
    // Get original size string
    private static func originalSize(_ image: UIImage) -> String {
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            return "unknown"
        }
        return formatSize(data.count)
    }
    
    // Format file size
    static func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.0fKB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1fMB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    // Get compression stats
    static func getCompressionStats(original: Data, compressed: Data) -> String {
        let originalMB = Double(original.count) / (1024.0 * 1024.0)
        let compressedMB = Double(compressed.count) / (1024.0 * 1024.0)
        let savings = (1.0 - compressedMB / originalMB) * 100
        
        return String(format: "%.1fMB → %.1fMB (节省%.0f%%)", originalMB, compressedMB, savings)
    }
}
