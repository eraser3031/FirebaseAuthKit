import SwiftUI
import AuthenticationServices

public struct AuthKitView: View {
    @Environment(AuthKit.self) private var auth

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                auth.handleSignInWithAppleRequest(request)
            } onCompletion: { result in
                auth.handleSignInWithAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)

            Button {
                auth.signInWithGoogle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .medium))
                    Text("Sign in with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.background)
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.5), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
        .alert("Sign In Error", isPresented: showingError) {
            Button("OK") { auth.errorMessage = nil }
        } message: {
            Text(auth.errorMessage ?? "")
        }
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { auth.errorMessage != nil },
            set: { if !$0 { auth.errorMessage = nil } }
        )
    }
}
