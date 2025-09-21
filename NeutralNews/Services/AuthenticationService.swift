//
//  AuthenticationService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/20/25.
//

import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
@Observable
final class AuthenticationService {
    static let shared = AuthenticationService()

    var currentUser: User?
    var isAuthenticated = false
    var isLoading = false

    private var currentNonce: String?

    private init() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.currentUser = User(from: user)
                    self?.isAuthenticated = true
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }

    func signInWithApple() async throws {
        guard let request = createAppleIDRequest() else {
            throw AuthError.appleSignInFailed
        }

        isLoading = true
        let nonce = currentNonce

        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                let controller = ASAuthorizationController(authorizationRequests: [request])
                let delegate = AppleSignInDelegate(continuation: continuation, currentNonce: nonce)

                delegate.setController(controller)
                controller.delegate = delegate
                controller.presentationContextProvider = delegate

                // Add a fallback timer to prevent continuation leaks
                Task {
                    try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    delegate.timeoutIfNeeded()
                }

                controller.performRequests()
            }

            guard let validNonce = nonce else {
                isLoading = false
                throw AuthError.appleSignInFailed
            }

            let credential = OAuthProvider.credential(
                providerID: .apple,
                idToken: result.identityToken,
                rawNonce: validNonce
            )

            try await Auth.auth().signIn(with: credential)

            if let user = currentUser {
                try await UserService.shared.createOrUpdateUser(user)
            }

            isLoading = false
        } catch {
            isLoading = false
            throw error
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }

    private func createAppleIDRequest() -> ASAuthorizationAppleIDRequest? {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        return request
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

enum AuthError: Error, LocalizedError {
    case appleSignInFailed
    case invalidCredentials
    case networkError
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .appleSignInFailed:
            return "Failed to sign in with Apple"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError:
            return "Network error occurred"
        case .userCancelled:
            return "Sign in was cancelled"
        }
    }
}

struct AppleSignInResult {
    let identityToken: String
    let authorizationCode: String
}

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<AppleSignInResult, Error>
    private let currentNonce: String?
    private var controller: ASAuthorizationController?
    private var isCompleted = false

    init(continuation: CheckedContinuation<AppleSignInResult, Error>, currentNonce: String?) {
        self.continuation = continuation
        self.currentNonce = currentNonce
    }

    func setController(_ controller: ASAuthorizationController) {
        self.controller = controller
    }

    func timeoutIfNeeded() {
        guard !isCompleted else { return }
        isCompleted = true
        print("🚫 Apple Sign In timed out - resuming with network error")
        continuation.resume(throwing: AuthError.networkError)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !isCompleted else { return }
        isCompleted = true

        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let _ = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8),
                  let authorizationCode = appleIDCredential.authorizationCode,
                  let authCodeString = String(data: authorizationCode, encoding: .utf8) else {
                continuation.resume(throwing: AuthError.appleSignInFailed)
                return
            }

            let result = AppleSignInResult(
                identityToken: idTokenString,
                authorizationCode: authCodeString
            )
            continuation.resume(returning: result)
        } else {
            continuation.resume(throwing: AuthError.appleSignInFailed)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard !isCompleted else { return }
        isCompleted = true

        print("🚫 Sign in failed with error: \(error)")
        print("🚫 About to resume continuation with error")
        if let authError = error as? ASAuthorizationError {
            print("🚫 ASAuthorizationError code: \(authError.code.rawValue)")
            switch authError.code {
            case .canceled:
                print("🚫 User cancelled - resuming with userCancelled error")
                continuation.resume(throwing: AuthError.userCancelled)
            case .failed:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            case .invalidResponse:
                continuation.resume(throwing: AuthError.invalidCredentials)
            case .notHandled:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            case .unknown:
                continuation.resume(throwing: AuthError.networkError)
            case .notInteractive:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            case .matchedExcludedCredential:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            case .credentialImport:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            case .credentialExport:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            case .deviceNotConfiguredForPasskeyCreation:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            case .preferSignInWithApple:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            @unknown default:
                continuation.resume(throwing: AuthError.appleSignInFailed)
            }
        } else {
            continuation.resume(throwing: error)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
