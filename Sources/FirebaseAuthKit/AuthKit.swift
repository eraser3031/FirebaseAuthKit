import Foundation
import Observation
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Observable
public final class AuthKit {
    public var isLoading = true
    public var isSignedIn = false
    public var user: User?
    public var errorMessage: String?

    private var handle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    public init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.user = user
            self.isSignedIn = user != nil
            self.isLoading = false
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Open URL (Google Sign In callback)

    public static func handleOpenURL(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Apple Sign In

    public func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = NonceHelper.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceHelper.sha256(nonce)
    }

    public func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let nonce = currentNonce
            else {
                errorMessage = "Apple Sign In failed: invalid credentials."
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            Auth.auth().signIn(with: credential) { [weak self] _, error in
                if let error {
                    self?.errorMessage = error.localizedDescription
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Google Sign In

    public func signInWithGoogle() {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else {
            errorMessage = "Cannot find root view controller."
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            self?.handleGoogleSignInResult(result: result, error: error)
        }
        #elseif os(macOS)
        guard let window = NSApplication.shared.keyWindow else {
            errorMessage = "Cannot find key window."
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: window) { [weak self] result, error in
            self?.handleGoogleSignInResult(result: result, error: error)
        }
        #endif
    }

    private func handleGoogleSignInResult(result: GIDSignInResult?, error: Error?) {
        if let error {
            errorMessage = error.localizedDescription
            return
        }

        guard let user = result?.user,
              let idToken = user.idToken?.tokenString
        else {
            errorMessage = "Google Sign In failed: missing token."
            return
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: user.accessToken.tokenString
        )

        Auth.auth().signIn(with: credential) { [weak self] _, error in
            if let error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Sign Out

    public func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    public func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.delete()
        } catch let error as NSError {
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                await reauthenticateAndDelete()
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reauthenticateAndDelete() async {
        guard let user = Auth.auth().currentUser,
              let providerID = user.providerData.first?.providerID
        else {
            errorMessage = "Could not determine sign-in provider for re-authentication."
            return
        }

        do {
            if providerID == "apple.com" {
                errorMessage = "Please sign in again with Apple, then retry account deletion."
                try Auth.auth().signOut()
                return
            } else if providerID == "google.com" {
                #if os(iOS)
                guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let presenting = await windowScene.windows.first?.rootViewController
                else {
                    errorMessage = "Cannot find root view controller."
                    return
                }
                #elseif os(macOS)
                guard let presenting = await NSApplication.shared.keyWindow else {
                    errorMessage = "Cannot find key window."
                    return
                }
                #endif

                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
                guard let idToken = result.user.idToken?.tokenString else {
                    errorMessage = "Google re-authentication failed."
                    return
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                try await user.reauthenticate(with: credential)
            }

            try await user.delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
