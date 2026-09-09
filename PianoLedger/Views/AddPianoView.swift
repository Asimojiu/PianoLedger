import SwiftUI
import PhotosUI

struct AddPianoView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var firebase = FirebaseManager.shared
    
    // Form fields
    @State private var customerName = ""
    @State private var pianoBrand = ""
    @State private var pianoModel = ""
    @State private var serialNumber = ""
    @State private var pianoType = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var tuningIntervalMonths = 6
    @State private var lastTuningDate = Date()
    @State private var hasLastTuningDate = false
    
    // Photo & OCR
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var photoData: Data?           // Original data
    @State private var compressedPhotoData: Data? // Compressed for upload
    @State private var compressionInfo: String?
    @State private var showCamera = false
    @State private var isProcessingOCR = false
    @State private var ocrResult: PianoOCRResult?
    @State private var showOCRResult = false
    
    // UI state
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Edit mode
    var editPiano: PianoDocument?
    
    var isEditing: Bool { editPiano != nil }
    
    var body: some View {
        NavigationView {
            Form {
                // Photo section
                Section {
                    HStack(spacing: 16) {
                        // Photo preview
                        if let image = photoImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "camera")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(spacing: 10) {
                            // Camera button
                            Button(action: { showCamera = true }) {
                                Label("拍照识别", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            // Photo picker
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("从相册选择", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    if isProcessingOCR {
                        HStack {
                            ProgressView()
                            Text("正在识别琴的信息...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Compression info
                    if let info = compressionInfo {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                            Text("已压缩: \(info)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("钢琴照片")
                } footer: {
                    Text("拍照或选择照片，自动识别琴的型号、序列号等信息")
                }
                
                // Customer info
                Section("客户信息") {
                    TextField("姓名", text: $customerName)
                    TextField("电话", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("地址", text: $address)
                }
                
                // Piano info
                Section("钢琴信息") {
                    HStack {
                        TextField("品牌", text: $pianoBrand)
                        if !pianoBrand.isEmpty {
                            Button(action: { pianoBrand = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("型号", text: $pianoModel)
                        if !pianoModel.isEmpty {
                            Button(action: { pianoModel = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("序列号", text: $serialNumber)
                        if !serialNumber.isEmpty {
                            Button(action: { serialNumber = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Picker("类型", selection: $pianoType) {
                        Text("请选择").tag("")
                        Text("立式").tag("立式")
                        Text("三角").tag("三角")
                        Text("电钢琴").tag("电钢琴")
                        Text("自动演奏").tag("自动演奏")
                    }
                }
                
                // Tuning info
                Section("调律信息") {
                    Toggle("上次调律日期", isOn: $hasLastTuningDate)
                    
                    if hasLastTuningDate {
                        DatePicker("上次调律", selection: $lastTuningDate, displayedComponents: .date)
                    }
                    
                    Stepper("调律周期: \(tuningIntervalMonths)个月", value: $tuningIntervalMonths, in: 1...24)
                    
                    if hasLastTuningDate {
                        let nextDate = Calendar.current.date(byAdding: .month, value: tuningIntervalMonths, to: lastTuningDate)!
                        HStack {
                            Text("下次调律")
                            Spacer()
                            Text(formatDate(nextDate))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Notes
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(isEditing ? "编辑钢琴" : "添加钢琴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: savePiano) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(customerName.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $photoImage, onCapture: processPhoto)
            }
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photoImage = image
                        photoData = data
                        
                        // Compress immediately
                        if let compressed = PhotoCompressionService.compress(image, quality: .medium) {
                            compressedPhotoData = compressed
                            compressionInfo = PhotoCompressionService.getCompressionStats(
                                original: data,
                                compressed: compressed
                            )
                        }
                        
                        processPhoto()
                    }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let piano = editPiano {
                    loadPianoData(piano)
                }
            }
        }
    }
    
    private func processPhoto() {
        guard let image = photoImage else { return }
        
        // Compress photo immediately
        if let compressed = PhotoCompressionService.compress(image, quality: .medium) {
            compressedPhotoData = compressed
            
            // Calculate compression stats
            if let originalData = image.jpegData(compressionQuality: 1.0) {
                compressionInfo = PhotoCompressionService.getCompressionStats(
                    original: originalData,
                    compressed: compressed
                )
            }
        }
        
        // Run OCR
        isProcessingOCR = true
        
        PianoOCRService.recognizePianoInfo(from: image) { result in
            isProcessingOCR = false
            
            if result.hasResults {
                ocrResult = result
                
                // Auto-fill fields if empty
                if pianoBrand.isEmpty && !result.brand.isEmpty {
                    pianoBrand = result.brand
                }
                if pianoModel.isEmpty && !result.model.isEmpty {
                    pianoModel = result.model
                }
                if serialNumber.isEmpty && !result.serialNumber.isEmpty {
                    serialNumber = result.serialNumber
                }
                if pianoType.isEmpty && !result.pianoType.isEmpty {
                    pianoType = result.pianoType
                }
                
                showOCRResult = true
            }
        }
    }
    
    private func savePiano() {
        isSaving = true
        
        Task {
            do {
                var piano = PianoRecord(
                    customerName: customerName,
                    pianoBrand: pianoBrand,
                    pianoModel: pianoModel,
                    serialNumber: serialNumber,
                    pianoType: pianoType,
                    address: address,
                    phone: phone,
                    lastTuningDate: hasLastTuningDate ? lastTuningDate : nil,
                    nextTuningDate: hasLastTuningDate ? 
                        Calendar.current.date(byAdding: .month, value: tuningIntervalMonths, to: lastTuningDate) : nil,
                    tuningIntervalMonths: tuningIntervalMonths,
                    notes: notes
                )
                
                // Upload photo if exists (use compressed version)
                let uploadData = compressedPhotoData ?? photoData
                if let data = uploadData {
                    if let editId = editPiano?.id {
                        let photoURL = try await firebase.uploadPhoto(imageData: data, pianoId: editId)
                        piano.photoURL = photoURL
                    }
                }
                
                if let editId = editPiano?.id {
                    try await firebase.updatePiano(id: editId, piano: piano)
                } else {
                    let newId = try await firebase.addPiano(piano)
                    if let data = uploadData {
                        _ = try await firebase.uploadPhoto(imageData: data, pianoId: newId)
                    }
                }
                
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isSaving = false
            }
        }
    }
    
    private func loadPianoData(_ piano: PianoDocument) {
        customerName = piano.customerName
        pianoBrand = piano.brand
        pianoModel = piano.model
        serialNumber = piano.serialNumber
        pianoType = piano.type
        address = piano.address
        phone = piano.phone
        notes = piano.notes
        tuningIntervalMonths = piano.tuningIntervalMonths
        
        if let lastDate = piano.lastTuningDate {
            hasLastTuningDate = true
            lastTuningDate = lastDate
        }
        
        // Load photo if URL exists
        if let photoURL = piano.photoURL {
            Task {
                if let url = URL(string: photoURL),
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    photoImage = image
                    photoData = data
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}
