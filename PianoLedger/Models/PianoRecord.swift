import Foundation
import SwiftData
import SwiftUI

@Model
final class PianoRecord {
    var id: UUID
    var customerName: String
    var pianoBrand: String      // 珠江, 卡哇伊, Yamaha, etc.
    var pianoModel: String      // UP118, KWIKS-A5SE, etc.
    var serialNumber: String
    var pianoType: String       // 立式, 三角, etc.
    var address: String
    var phone: String
    var photoData: Data?        // Piano photo stored as Data
    var lastTuningDate: Date?
    var nextTuningDate: Date?
    var tuningIntervalMonths: Int  // Default 6 months
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    
    // Computed properties
    var daysUntilNextTuning: Int? {
        guard let nextDate = nextTuningDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day
    }
    
    var tuningStatus: TuningStatus {
        guard let nextDate = nextTuningDate else { return .unknown }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
        if days < 0 {
            return .overdue
        } else if days <= 30 {
            return .dueSoon
        } else {
            return .current
        }
    }
    
    var pianoDisplayName: String {
        var parts: [String] = []
        if !pianoBrand.isEmpty { parts.append(pianoBrand) }
        if !pianoModel.isEmpty { parts.append(pianoModel) }
        if !pianoType.isEmpty { parts.append(pianoType) }
        return parts.joined(separator: " · ")
    }
    
    init(
        customerName: String = "",
        pianoBrand: String = "",
        pianoModel: String = "",
        serialNumber: String = "",
        pianoType: String = "",
        address: String = "",
        phone: String = "",
        photoData: Data? = nil,
        lastTuningDate: Date? = nil,
        nextTuningDate: Date? = nil,
        tuningIntervalMonths: Int = 6,
        notes: String = ""
    ) {
        self.id = UUID()
        self.customerName = customerName
        self.pianoBrand = pianoBrand
        self.pianoModel = pianoModel
        self.serialNumber = serialNumber
        self.pianoType = pianoType
        self.address = address
        self.phone = phone
        self.photoData = photoData
        self.lastTuningDate = lastTuningDate
        self.nextTuningDate = nextTuningDate
        self.tuningIntervalMonths = tuningIntervalMonths
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum TuningStatus: String, CaseIterable {
    case overdue = "已逾期"
    case dueSoon = "即将到期"
    case current = "正常"
    case unknown = "未知"
    
    var color: Color {
        switch self {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .current: return .green
        case .unknown: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .overdue: return "exclamationmark.triangle.fill"
        case .dueSoon: return "clock.fill"
        case .current: return "checkmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// Filter enum for list view
enum FilterType: String, CaseIterable {
    case all = "全部"
    case overdue = "已逾期"
    case dueSoon = "即将到期"
    case neverTuned = "未调过"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .overdue: return "exclamationmark.triangle"
        case .dueSoon: return "clock"
        case .neverTuned: return "pianokeys"
        }
    }
}
