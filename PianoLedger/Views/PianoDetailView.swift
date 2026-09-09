import SwiftUI

struct PianoDetailView: View {
    let pianoId: String
    @StateObject private var firebase = FirebaseManager.shared
    @State private var piano: PianoDocument?
    @State private var isLoading = true
    @State private var showEditView = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let piano = piano {
                VStack(spacing: 20) {
                    // Photo
                    if let photoURL = piano.photoURL, let url = URL(string: photoURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    ProgressView()
                                )
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "pianokeys")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    Text("暂无照片")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                            .padding(.horizontal)
                    }
                    
                    // Status card
                    StatusCardView(piano: piano)
                        .padding(.horizontal)
                    
                    // Customer info
                    InfoSection(title: "客户信息", icon: "person.fill") {
                        InfoRow(label: "姓名", value: piano.customerName)
                        if !piano.phone.isEmpty {
                            InfoRow(label: "电话", value: piano.phone, isLink: true, linkType: .phone)
                        }
                        if !piano.address.isEmpty {
                            InfoRow(label: "地址", value: piano.address, isLink: true, linkType: .map)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Piano info
                    InfoSection(title: "钢琴信息", icon: "pianokeys") {
                        if !piano.brand.isEmpty {
                            InfoRow(label: "品牌", value: piano.brand)
                        }
                        if !piano.model.isEmpty {
                            InfoRow(label: "型号", value: piano.model)
                        }
                        if !piano.serialNumber.isEmpty {
                            InfoRow(label: "序列号", value: piano.serialNumber)
                        }
                        if !piano.type.isEmpty {
                            InfoRow(label: "类型", value: piano.type)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tuning info
                    InfoSection(title: "调律信息", icon: "wrench.fill") {
                        if let lastDate = piano.lastTuningDate {
                            InfoRow(label: "上次调律", value: formatDate(lastDate))
                        }
                        if let nextDate = piano.nextTuningDate {
                            InfoRow(label: "下次调律", value: formatDate(nextDate))
                        }
                        InfoRow(label: "调律周期", value: "\(piano.tuningIntervalMonths)个月")
                        if let days = piano.daysUntilNextTuning {
                            InfoRow(label: "剩余天数", value: days >= 0 ? "\(days)天" : "逾期\(abs(days))天")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Notes
                    if !piano.notes.isEmpty {
                        InfoSection(title: "备注", icon: "note.text") {
                            Text(piano.notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 30)
                }
            }
        }
        .navigationTitle("钢琴详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showEditView = true }) {
                        Label("编辑", systemImage: "pencil")
                    }
                    
                    Button(action: { showDeleteConfirm = true }) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditView) {
            if let piano = piano {
                AddPianoView(editPiano: piano)
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deletePiano()
            }
        } message: {
            Text("确定要删除这条钢琴档案吗？此操作不可恢复。")
        }
        .task {
            await loadPiano()
        }
    }
    
    private func loadPiano() async {
        isLoading = true
        do {
            let doc = try await firebase.db.collection("pianos").document(pianoId).getDocument()
            if doc.exists {
                piano = PianoDocument(id: doc.documentID, data: doc.data() ?? [:])
            }
        } catch {
            print("Error loading piano: \(error)")
        }
        isLoading = false
    }
    
    private func deletePiano() {
        Task {
            try? await firebase.deletePiano(id: pianoId)
            dismiss()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

// MARK: - Status Card
struct StatusCardView: View {
    let piano: PianoDocument
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(piano.customerName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if !piano.pianoDisplayName.isEmpty {
                    Text(piano.pianoDisplayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            StatusBadge(status: piano.tuningStatus)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Info Section
struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.green)
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Info Row
enum LinkType {
    case phone
    case map
    case none
}

struct InfoRow: View {
    let label: String
    let value: String
    var isLink: Bool = false
    var linkType: LinkType = .none
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            if isLink {
                Button(action: openLink) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .underline()
                }
            } else {
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
    }
    
    private func openLink() {
        switch linkType {
        case .phone:
            if let url = URL(string: "tel://\(value)") {
                UIApplication.shared.open(url)
            }
        case .map:
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            if let url = URL(string: "https://maps.apple.com/?q=\(encoded)") {
                UIApplication.shared.open(url)
            }
        case .none:
            break
        }
    }
}
