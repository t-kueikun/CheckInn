//
//  SessionViewModel.swift
//  Staly
//
//  Created by Codex on 2026/02/18.
//

import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit

@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let container: AppContainer
    private var authStateTask: Task<Void, Never>?
    private var currentAppleNonce: String?

    init(container: AppContainer) {
        self.container = container
        self.user = container.auth.currentUser

        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await user in container.auth.authStateDidChange {
                self.user = user
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    func signIn(email: String, password: String) async {
        await performAuthAction {
            _ = try await container.auth.signInWithEmail(email: email, password: password)
        }
    }

    func signUp(email: String, password: String, displayName: String?) async {
        await performAuthAction {
            _ = try await container.auth.signUpWithEmail(email: email, password: password, displayName: displayName)
        }
    }

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        clearError()
    }

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, any Error>) async {
        switch result {
        case .success(let authorization):
            let rawNonce = currentAppleNonce
            currentAppleNonce = nil
            await performAuthAction {
                guard let rawNonce else {
                    throw AuthError.missingAppleNonce
                }
                _ = try await container.auth.signInWithApple(authorization: authorization, rawNonce: rawNonce)
            }
        case .failure(let error):
            currentAppleNonce = nil
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        await performAuthAction {
            try await container.auth.signOut()
        }
    }

    func updateDisplayName(_ displayName: String?) async {
        await performAuthAction {
            _ = try await container.auth.updateDisplayName(displayName)
        }
    }

    var publicUserID: String? {
        guard let user else { return nil }
        let digest = SHA256.hash(data: Data(user.id.utf8))
        let token = digest.prefix(4).map { String(format: "%02X", $0) }.joined()
        return "CHK-\(token)"
    }

    func clearError() {
        errorMessage = nil
    }

    private func performAuthAction(_ action: () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
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
}
