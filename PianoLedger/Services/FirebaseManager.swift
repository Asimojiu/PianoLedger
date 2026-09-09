import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import SwiftUI

// MARK: - App Configuration
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

// MARK: - Firebase Manager
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    let auth = Auth.auth()
    let db = Firestore.firestore()
    let storage = Storage.storage()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    init() {
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    // MARK: - Auth
    func signInWithEmail(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }
    
    func signUpWithEmail(email: String, password: String, name: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        
        // Create user profile in Firestore
        try await db.collection("users").document(result.user.uid).setData([
            "name": name,
            "email": email,
            "role": "technician",
            "createdAt": FieldValue.serverTimestamp()
        ])
        
        // Update display name
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    // MARK: - Piano Records CRUD
    func addPiano(_ piano: PianoRecord) async throws -> String {
        guard let userId = currentUser?.uid else { throw NSError(domain: "Auth", code: 401) }
        
        var data: [String: Any] = [
            "userId": userId,
            "customerName": piano.customerName,
            "brand": piano.pianoBrand,
            "model": piano.pianoModel,
            "serialNumber": piano.serialNumber,
            "type": piano.pianoType,
            "address": piano.address,
            "phone": piano.phone,
            "tuningIntervalMonths": piano.tuningIntervalMonths,
            "notes": piano.notes,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let lastDate = piano.lastTuningDate {
            data["lastTuningDate"] = Timestamp(date: lastDate)
        }
        if let nextDate = piano.nextTuningDate {
            data["nextTuningDate"] = Timestamp(date: nextDate)
        }
        
        let ref = try await db.collection("pianos").addDocument(data: data)
        return ref.documentID
    }
    
    func updatePiano(id: String, piano: PianoRecord) async throws {
        guard currentUser != nil else { throw NSError(domain: "Auth", code: 401) }
        
        var data: [String: Any] = [
            "customerName": piano.customerName,
            "brand": piano.pianoBrand,
            "model": piano.pianoModel,
            "serialNumber": piano.serialNumber,
            "type": piano.pianoType,
            "address": piano.address,
            "phone": piano.phone,
            "tuningIntervalMonths": piano.tuningIntervalMonths,
            "notes": piano.notes,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let lastDate = piano.lastTuningDate {
            data["lastTuningDate"] = Timestamp(date: lastDate)
        }
        if let nextDate = piano.nextTuningDate {
            data["nextTuningDate"] = Timestamp(date: nextDate)
        }
        
        try await db.collection("pianos").document(id).updateData(data)
    }
    
    func deletePiano(id: String) async throws {
        guard currentUser != nil else { throw NSError(domain: "Auth", code: 401) }
        
        // Delete photo from storage if exists
        let doc = try await db.collection("pianos").document(id).getDocument()
        if let photoURL = doc.data()?["photoURL"] as? String {
            try? await storage.reference(forURL: photoURL).delete()
        }
        
        try await db.collection("pianos").document(id).delete()
    }
    
    // MARK: - Photo Upload
    func uploadPhoto(imageData: Data, pianoId: String) async throws -> String {
        guard currentUser != nil else { throw NSError(domain: "Auth", code: 401) }
        
        let ref = storage.reference().child("piano_photos/\(pianoId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
    
    // MARK: - Fetch Records
    func fetchPianos(filter: FilterType = .all) async throws -> [PianoDocument] {
        guard let userId = currentUser?.uid else { throw NSError(domain: "Auth", code: 401) }
        
        var query: Query = db.collection("pianos")
            .whereField("userId", isEqualTo: userId)
        
        switch filter {
        case .overdue:
            query = query.whereField("nextTuningDate", isLessThan: Timestamp(date: Date()))
        case .dueSoon:
            let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            query = query
                .whereField("nextTuningDate", isGreaterThanOrEqualTo: Timestamp(date: Date()))
                .whereField("nextTuningDate", isLessThanOrEqualTo: Timestamp(date: thirtyDaysLater))
        case .neverTuned:
            query = query.whereField("lastTuningDate", isEqualTo: NSNull())
        case .all:
            break
        }
        
        let snapshot = try await query.order(by: "updatedAt", descending: true).getDocuments()
        
        return snapshot.documents.map { doc in
            PianoDocument(id: doc.documentID, data: doc.data())
        }
    }
    
    // MARK: - Real-time Listener
    func listenPianos(filter: FilterType = .all, completion: @escaping ([PianoDocument]) -> Void) -> ListenerRegistration? {
        guard let userId = currentUser?.uid else { return nil }
        
        var query: Query = db.collection("pianos")
            .whereField("userId", isEqualTo: userId)
        
        switch filter {
        case .overdue:
            query = query.whereField("nextTuningDate", isLessThan: Timestamp(date: Date()))
        case .dueSoon:
            let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            query = query
                .whereField("nextTuningDate", isGreaterThanOrEqualTo: Timestamp(date: Date()))
                .whereField("nextTuningDate", isLessThanOrEqualTo: Timestamp(date: thirtyDaysLater))
        case .neverTuned:
            query = query.whereField("lastTuningDate", isEqualTo: NSNull())
        case .all:
            break
        }
        
        return query.addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Error fetching documents: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            let pianos = documents.map { doc in
                PianoDocument(id: doc.documentID, data: doc.data())
            }
            completion(pianos)
        }
    }
}

// MARK: - Piano Document (Firestore representation)
struct PianoDocument: Identifiable {
    let id: String
    let customerName: String
    let brand: String
    let model: String
    let serialNumber: String
    let type: String
    let address: String
    let phone: String
    let photoURL: String?
    let lastTuningDate: Date?
    let nextTuningDate: Date?
    let tuningIntervalMonths: Int
    let notes: String
    let createdAt: Date?
    let updatedAt: Date?
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.customerName = data["customerName"] as? String ?? ""
        self.brand = data["brand"] as? String ?? ""
        self.model = data["model"] as? String ?? ""
        self.serialNumber = data["serialNumber"] as? String ?? ""
        self.type = data["type"] as? String ?? ""
        self.address = data["address"] as? String ?? ""
        self.phone = data["phone"] as? String ?? ""
        self.photoURL = data["photoURL"] as? String
        self.lastTuningDate = (data["lastTuningDate"] as? Timestamp)?.dateValue()
        self.nextTuningDate = (data["nextTuningDate"] as? Timestamp)?.dateValue()
        self.tuningIntervalMonths = data["tuningIntervalMonths"] as? Int ?? 6
        self.notes = data["notes"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
    }
    
    // Computed properties
    var pianoDisplayName: String {
        var parts: [String] = []
        if !brand.isEmpty { parts.append(brand) }
        if !model.isEmpty { parts.append(model) }
        if !type.isEmpty { parts.append(type) }
        return parts.joined(separator: " · ")
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
    
    var daysUntilNextTuning: Int? {
        guard let nextDate = nextTuningDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day
    }
}
