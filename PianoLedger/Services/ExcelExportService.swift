import Foundation
import SwiftUI

// MARK: - Excel Export Service
class ExcelExportService {
    
    // Export pianos to CSV format
    static func exportToCSV(pianos: [PianoDocument]) -> String {
        var csv = "客户姓名,品牌,型号,序列号,类型,电话,地址,上次调律,下次调律,调律周期(月),状态,备注\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for piano in pianos {
            let lastTuning = piano.lastTuningDate.map { dateFormatter.string(from: $0) } ?? ""
            let nextTuning = piano.nextTuningDate.map { dateFormatter.string(from: $0) } ?? ""
            
            // Escape CSV fields
            let name = escapeCSV(piano.customerName)
            let brand = escapeCSV(piano.brand)
            let model = escapeCSV(piano.model)
            let serial = escapeCSV(piano.serialNumber)
            let type = escapeCSV(piano.type)
            let phone = escapeCSV(piano.phone)
            let address = escapeCSV(piano.address)
            let notes = escapeCSV(piano.notes)
            let status = piano.tuningStatus.rawValue
            
            csv += "\(name),\(brand),\(model),\(serial),\(type),\(phone),\(address),\(lastTuning),\(nextTuning),\(piano.tuningIntervalMonths),\(status),\(notes)\n"
        }
        
        return csv
    }
    
    // Escape CSV special characters
    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    // Save CSV to file
    static func saveCSVFile(content: String, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(filename).csv")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving CSV: \(error)")
            return nil
        }
    }
    
    // Export with sharing
    static func exportAndShare(pianos: [PianoDocument]) -> URL? {
        let csv = exportToCSV(pianos: pianos)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "琴档_导出_\(dateFormatter.string(from: Date()))"
        return saveCSVFile(content: csv, filename: filename)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
