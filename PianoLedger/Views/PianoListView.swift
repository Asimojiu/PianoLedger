import SwiftUI

struct PianoListView: View {
    @StateObject private var firebase = FirebaseManager.shared
    @State private var pianos: [PianoDocument] = []
    @State private var selectedFilter: FilterType = .all
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var showAddView = false
    @State private var listener: Any?
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    var filteredPianos: [PianoDocument] {
        if searchText.isEmpty {
            return pianos
        }
        return pianos.filter { piano in
            piano.customerName.localizedCaseInsensitiveContains(searchText) ||
            piano.address.localizedCaseInsensitiveContains(searchText) ||
            piano.brand.localizedCaseInsensitiveContains(searchText) ||
            piano.model.localizedCaseInsensitiveContains(searchText) ||
            piano.serialNumber.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats bar
                StatsBarView(pianos: pianos)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                
                // Filter tabs
                FilterTabsView(selectedFilter: $selectedFilter)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // Piano list
                if isLoading {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else if filteredPianos.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(filteredPianos) { piano in
                            NavigationLink(destination: PianoDetailView(pianoId: piano.id)) {
                                PianoRowView(piano: piano)
                            }
                        }
                        .onDelete(perform: deletePianos)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await loadPianos()
                    }
                }
            }
            .navigationTitle("琴档")
            .searchable(text: $searchText, prompt: "搜索姓名、地址、品牌、型号")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddView = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: exportData) {
                            Label("导出 Excel", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(action: signOut) {
                            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddView) {
                AddPianoView()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .onChange(of: selectedFilter) { _ in
                Task { await loadPianos() }
            }
        }
        .task {
            await loadPianos()
            setupListener()
        }
    }
    
    private func loadPianos() async {
        isLoading = true
        do {
            pianos = try await firebase.fetchPianos(filter: selectedFilter)
        } catch {
            print("Error loading pianos: \(error)")
        }
        isLoading = false
    }
    
    private func setupListener() {
        listener = firebase.listenPianos(filter: selectedFilter) { newPianos in
            self.pianos = newPianos
            self.isLoading = false
        }
    }
    
    private func deletePianos(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let piano = filteredPianos[index]
                try? await firebase.deletePiano(id: piano.id)
            }
            await loadPianos()
        }
    }
    
    private func signOut() {
        try? firebase.signOut()
    }
    
    private func exportData() {
        if let url = ExcelExportService.exportAndShare(pianos: pianos) {
            exportURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Stats Bar
struct StatsBarView: View {
    let pianos: [PianoDocument]
    
    var overdueCount: Int {
        pianos.filter { $0.tuningStatus == .overdue }.count
    }
    
    var dueSoonCount: Int {
        pianos.filter { $0.tuningStatus == .dueSoon }.count
    }
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(title: "档案", value: "\(pianos.count)", color: .green)
            StatCard(title: "即将到期", value: "\(dueSoonCount)", color: .orange)
            StatCard(title: "已逾期", value: "\(overdueCount)", color: .red)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Filter Tabs
struct FilterTabsView: View {
    @Binding var selectedFilter: FilterType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.green : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Piano Row
struct PianoRowView: View {
    let piano: PianoDocument
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(piano.customerName.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.primary)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(piano.customerName)
                    .font(.headline)
                
                if !piano.pianoDisplayName.isEmpty {
                    Text(piano.pianoDisplayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if !piano.address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(piano.address)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let nextDate = piano.nextTuningDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("下次 \(formatDate(nextDate))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            StatusBadge(status: piano.tuningStatus)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: TuningStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.rawValue)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .foregroundColor(status.color)
        .cornerRadius(8)
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pianokeys")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("还没有钢琴档案")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击右上角 + 添加第一架钢琴")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
