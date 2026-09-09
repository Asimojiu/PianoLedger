import SwiftUI

struct LoginView: View {
    @StateObject private var firebase = FirebaseManager.shared
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "pianokeys")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("琴档")
                            .font(.system(size: 36, weight: .bold))
                        
                        Text("钢琴调律客户档案")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Form
                    VStack(spacing: 16) {
                        if isSignUp {
                            TextField("姓名", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textContentType(.name)
                        }
                        
                        TextField("邮箱", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("密码", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(isSignUp ? .newPassword : .password)
                    }
                    .padding(.horizontal, 30)
                    
                    // Error message
                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal, 30)
                    }
                    
                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: handleAuth) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isSignUp ? "注册" : "登录")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                        
                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "已有账号？去登录" : "没有账号？去注册")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func handleAuth() {
        isLoading = true
        showError = false
        
        Task {
            do {
                if isSignUp {
                    guard !name.isEmpty else {
                        throw NSError(domain: "Validation", code: 400, userInfo: [NSLocalizedDescriptionKey: "请输入姓名"])
                    }
                    try await firebase.signUpWithEmail(email: email, password: password, name: name)
                } else {
                    try await firebase.signInWithEmail(email: email, password: password)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}
