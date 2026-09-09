import Foundation
import Vision
import UIKit

// MARK: - OCR Result
struct PianoOCRResult {
    var brand: String = ""
    var model: String = ""
    var serialNumber: String = ""
    var pianoType: String = ""
    var rawText: String = ""
    
    var hasResults: Bool {
        !brand.isEmpty || !model.isEmpty || !serialNumber.isEmpty
    }
}

// MARK: - Piano Brand Database
struct PianoBrandDatabase {
    // Common piano brands (Chinese and English)
    static let brands: [String: [String]] = [
        "珠江": ["珠江", "Pearl River", "pearlriver"],
        "卡哇伊": ["卡哇伊", "KAWAI", "kawai", "Kawai", "河合"],
        "雅马哈": ["雅马哈", "YAMAHA", "yamaha", "Yamaha"],
        "施坦威": ["施坦威", "Steinway", "STEINWAY", "steinway", "斯坦威"],
        "博兰斯勒": ["博兰斯勒", "Blüthner", "Bluthner", "BLUTHNER"],
        "贝希斯坦": ["贝希斯坦", "Bechstein", "BECHSTEIN"],
        "法奇奥里": ["法奇奥里", "Fazioli", "FAZIOLI"],
        "赛乐尔": ["赛乐尔", "Seiler", "SEILER"],
        "英昌": ["英昌", "Young Chang", "YOUNG CHANG"],
        "三益": ["三益", "Samick", "SAMICK"],
        "海伦": ["海伦", "Hailun", "HAILUN"],
        "星海": ["星海", "Xinghai", "XINGHAI"],
        "诺的斯卡": ["诺的斯卡", "Nordiska", "NORDISKA"],
        "哈曼尼": ["哈曼尼", "Harmani", "HARMANI"],
        "嘉德威": ["嘉德威", "Goodway", "GOODWAY"],
        "门德尔松": ["门德尔松", "Mendelssohn", "MENDELSSOHN"],
        "伯恩斯坦": ["伯恩斯坦", "Bernstein", "BERNSTEIN"],
        "威廉世家": ["威廉世家", "William", "WILLIAM"],
        "查伦": ["查伦", "Charlemagne", "CHARLEMAGNE"],
        "罗兰": ["罗兰", "Roland", "ROLAND"],
        "克拉维克": ["克拉维克", "Kurzweil", "KURZWEIL"],
    ]
    
    // Piano type keywords
    static let typeKeywords: [String: String] = [
        "立式": "立式",
        "Upright": "立式",
        "UPRIGHT": "立式",
        "直立": "立式",
        "三角": "三角",
        "Grand": "三角",
        "GRAND": "三角",
        "平台": "三角",
        "大三角": "三角",
        "Baby Grand": "三角",
        "小型三角": "三角",
        "电钢琴": "电钢琴",
        "Digital": "电钢琴",
        "DIGITAL": "电钢琴",
        "数码钢琴": "电钢琴",
        "自动演奏": "自动演奏",
        "Player": "自动演奏",
    ]
    
    // Find brand in text
    static func findBrand(in text: String) -> String? {
        let uppercased = text.uppercased()
        for (canonical, variants) in brands {
            for variant in variants {
                if uppercased.contains(variant.uppercased()) {
                    return canonical
                }
            }
        }
        return nil
    }
    
    // Find piano type in text
    static func findType(in text: String) -> String? {
        for (keyword, type) in typeKeywords {
            if text.uppercased().contains(keyword.uppercased()) {
                return type
            }
        }
        return nil
    }
}

// MARK: - OCR Service
class PianoOCRService {
    
    // Main OCR function
    static func recognizePianoInfo(from image: UIImage, completion: @escaping (PianoOCRResult) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(PianoOCRResult())
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(PianoOCRResult())
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let fullText = recognizedStrings.joined(separator: "\n")
            let result = parsePianoText(fullText)
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
        
        // Configure for better recognition
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US", "en-GB"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                DispatchQueue.main.async {
                    completion(PianoOCRResult())
                }
            }
        }
    }
    
    // Parse extracted text to find piano information
    static func parsePianoText(_ text: String) -> PianoOCRResult {
        var result = PianoOCRResult()
        result.rawText = text
        
        let lines = text.components(separatedBy: .newlines)
        
        // 1. Find brand
        if let brand = PianoBrandDatabase.findBrand(in: text) {
            result.brand = brand
        }
        
        // 2. Find piano type
        if let type = PianoBrandDatabase.findType(in: text) {
            result.pianoType = type
        }
        
        // 3. Find serial number (usually alphanumeric, 5-10 chars)
        result.serialNumber = extractSerialNumber(from: lines)
        
        // 4. Find model number (usually contains letters and numbers)
        result.model = extractModelNumber(from: lines, brand: result.brand)
        
        return result
    }
    
    // Extract serial number
    static func extractSerialNumber(from lines: [String]) -> String {
        // Common serial number patterns
        let patterns = [
            // Serial number label followed by number
            #"(?i)(?:serial\s*(?:no\.?|number)?|s/?n|序列号|编号)[\s:：]*([A-Z0-9]{4,12})"#,
            #"(?i)(?:ser\.?\s*no\.?)[\s:：]*([A-Z0-9]{4,12})"#,
            // Standalone number sequence (4-10 digits)
            #"\b(\d{5,10})\b"#,
            // Letter + number combination
            #"\b([A-Z]\d{4,8})\b"#,
        ]
        
        let fullText = lines.joined(separator: " ")
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: fullText, range: NSRange(fullText.startIndex..., in: fullText)),
               let range = Range(match.range(at: 1), in: fullText) {
                let serial = String(fullText[range]).trimmingCharacters(in: .whitespaces)
                // Validate: should be 4-12 characters, mostly alphanumeric
                if serial.count >= 4 && serial.count <= 12 {
                    return serial
                }
            }
        }
        
        return ""
    }
    
    // Extract model number
    static func extractModelNumber(from lines: [String], brand: String) -> String {
        let fullText = lines.joined(separator: " ")
        
        // Common model patterns
        let patterns = [
            // Model label followed by value
            #"(?i)(?:model|型号|琴型号)[\s:：]*([A-Za-z0-9][\w\-]{2,15})"#,
            #"(?i)(?:type|类型)[\s:：]*([A-Za-z0-9][\w\-]{2,15})"#,
            // Brand-specific patterns
            #"\b(UP\d{2,3}[A-Z]?)\b"#,        // Yamaha UP118, UP125, etc.
            #"\b(US\d{2,3}[A-Z]?)\b"#,        // Yamaha US50, US60, etc.
            #"\b(B\d{2,3}[A-Z]?)\b"#,         // Kawai B200, B300, etc.
            #"\b(K\d{2,3}[A-Z]?)\b"#,         // Kawai K300, K500, etc.
            #"\b(G\d{1,2}[A-Z]?)\b"#,         // Grand pianos G1, G2, etc.
            #"\b(U\d{1,2}[A-Z]?)\b"#,         // Upright U1, U2, U3, etc.
            #"\b([A-Z]{1,3}\d{2,4}[A-Z]?)\b"#, // Generic: letters + numbers
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: fullText, range: NSRange(fullText.startIndex..., in: fullText)),
               let range = Range(match.range(at: 1), in: fullText) {
                let model = String(fullText[range]).trimmingCharacters(in: .whitespaces)
                // Make sure it's not the brand name itself
                if model.uppercased() != brand.uppercased() && model.count >= 3 {
                    return model
                }
            }
        }
        
        // Fallback: look for any alphanumeric sequence that looks like a model
        let fallbackPattern = #"\b([A-Z]{1,4}[\-]?\d{2,5}[A-Z]?)\b"#
        if let regex = try? NSRegularExpression(pattern: fallbackPattern, options: []),
           let match = regex.firstMatch(in: fullText, range: NSRange(fullText.startIndex..., in: fullText)),
           let range = Range(match.range(at: 1), in: fullText) {
            return String(fullText[range])
        }
        
        return ""
    }
}
