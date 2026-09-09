# 琴档 (Piano Ledger)

钢琴调律客户档案管理 iOS App

## 功能特点

- 📸 **拍照识别** - 拍摄钢琴照片，自动识别品牌、型号、序列号
- 📋 **客户档案** - 完整的钢琴档案管理
- 🔍 **智能搜索** - 按姓名、地址、品牌、型号搜索
- 🏷️ **状态筛选** - 全部、已逾期、即将到期、未调过
- ☁️ **云端同步** - Firebase 后端，多设备实时同步
- 📊 **数据统计** - 档案数、逾期数、即将到期数

## 技术栈

- **前端**: SwiftUI (iOS 17+)
- **后端**: Firebase
  - Firebase Auth (邮箱登录)
  - Firestore (数据库)
  - Firebase Storage (照片存储)
- **OCR**: Apple Vision 框架 (设备端识别，无需网络)

## 快速开始

### 1. 创建 Firebase 项目

1. 访问 [Firebase Console](https://console.firebase.google.com/)
2. 创建新项目，名称如 "PianoLedger"
3. 启用以下服务：
   - **Authentication** → 启用 Email/Password
   - **Firestore Database** → 创建数据库
   - **Storage** → 启用存储

### 2. 下载配置文件

1. 在 Firebase Console → 项目设置 → iOS 应用
2. 添加 iOS 应用，Bundle ID: `com.flowpiano.pianoledger`
3. 下载 `GoogleService-Info.plist`
4. 替换项目中的占位文件：`PianoLedger/GoogleService-Info.plist`

### 3. 安装依赖

在 Xcode 中：

1. 打开 `PianoLedger.xcodeproj`
2. 文件 → 添加包依赖
3. 输入：`https://github.com/firebase/firebase-ios-sdk`
4. 选择以下产品：
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage
5. 等待安装完成

### 4. 配置 Firestore 安全规则

在 Firebase Console → Firestore → 规则，粘贴：

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 用户只能读写自己的数据
    match /pianos/{pianoId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
    }
    
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. 配置 Storage 安全规则

在 Firebase Console → Storage → 规则，粘贴：

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /piano_photos/{photoId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### 6. 运行项目

1. 选择 iPhone 模拟器或真机
2. 按 ⌘R 运行
3. 注册账号开始使用

## 数据结构

### Firestore 集合

```
pianos/
  ├── userId: string (用户ID)
  ├── customerName: string
  ├── brand: string (品牌)
  ├── model: string (型号)
  ├── serialNumber: string (序列号)
  ├── type: string (类型：立式/三角)
  ├── address: string
  ├── phone: string
  ├── photoURL: string (照片URL)
  ├── lastTuningDate: timestamp
  ├── nextTuningDate: timestamp
  ├── tuningIntervalMonths: number
  ├── notes: string
  ├── createdAt: timestamp
  └── updatedAt: timestamp

users/
  ├── name: string
  ├── email: string
  ├── role: string (technician/admin)
  └── createdAt: timestamp
```

## OCR 识别支持的品牌

珠江、卡哇伊(KAWAI)、雅马哈(YAMAHA)、施坦威(Steinway)、博兰斯勒、贝希斯坦、法奇奥里、赛乐尔、英昌、三益、海伦、星海、诺的斯卡、哈曼尼、嘉德威、门德尔松、伯恩斯坦、威廉世家、查伦、罗兰、克拉维克

## 项目结构

```
PianoLedger/
├── PianoLedgerApp.swift     # App 入口
├── Info.plist               # 配置文件
├── GoogleService-Info.plist # Firebase 配置
├── Models/
│   └── PianoRecord.swift    # 数据模型
├── Views/
│   ├── LoginView.swift      # 登录页
│   ├── PianoListView.swift  # 钢琴列表
│   ├── PianoDetailView.swift # 钢琴详情
│   ├── AddPianoView.swift   # 添加/编辑钢琴
│   └── CameraView.swift     # 相机
└── Services/
    ├── FirebaseManager.swift # Firebase 服务
    └── PianoOCRService.swift # OCR 识别服务
```

## 免费额度

Firebase 免费额度（Spark 计划）：
- Authentication: 无限
- Firestore: 1GB 存储 + 5万次读/天 + 2万次写/天
- Storage: 5GB + 1GB 下载/天

足够支持几十个调音师同时使用。

## 后续功能（可选）

- [ ] 数据导出 Excel
- [ ] 调律提醒推送
- [ ] 多语言支持
- [ ] Web 管理后台
- [ ] 客户评价系统
- [ ] 收入统计

## 支持

如有问题，请联系开发团队。
