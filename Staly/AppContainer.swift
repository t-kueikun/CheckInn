//
//  AppContainer.swift
//  Staly
//
//  Created by 西村光篤 on 2026/02/18.
//

import Foundation
import Combine
import AuthenticationServices

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

final class LocalAuthServiceInline {
    private let keychainKey = "LocalAuthService.credentials"
    private let emailAccountsKey = "LocalAuthService.emailAccounts"
    private let appleAccountsKey = "LocalAuthService.appleAccounts"
    private let profilesKey = "LocalAuthService.profiles"

    private struct EmailAccount: Codable {
        var id: String
        var email: String
        var password: String
        var displayName: String?
    }

    private struct AppleAccount: Codable {
        var id: String
        var email: String?
        var displayName: String?
    }

    private struct UserProfile: Codable {
        var id: String
        var email: String?
        var displayName: String?
    }

    private var continuation: AsyncStream<AuthUser?>.Continuation?
    private(set) var currentUser: AuthUser? {
        didSet { continuation?.yield(currentUser) }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: keychainKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
            currentUser = user
        }
    }

    var authStateDidChange: AsyncStream<AuthUser?> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.currentUser)
        }
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthUser {
        guard password.count >= 4 else { throw AuthError.invalidCredentials }
        let normalizedEmail = Self.normalizeEmail(email)
        var accounts = loadEmailAccounts()
        guard let account = accounts[normalizedEmail] else {
            throw AuthError.accountNotFound
        }
        guard account.password == password else {
            throw AuthError.invalidCredentials
        }

        // Keep stored profile stable and refresh email if needed.
        accounts[normalizedEmail]?.email = normalizedEmail
        saveEmailAccounts(accounts)

        let user = mergeAndPersistProfile(
            AuthUser(
                id: account.id,
                email: normalizedEmail,
                displayName: account.displayName
            ),
            preferIncomingDisplayName: false
        )
        try persist(user)
        currentUser = user
        return user
    }

    func signUpWithEmail(email: String, password: String, displayName: String?) async throws -> AuthUser {
        guard password.count >= 4 else { throw AuthError.invalidCredentials }
        let normalizedEmail = Self.normalizeEmail(email)
        guard normalizedEmail.contains("@") else { throw AuthError.invalidCredentials }

        var accounts = loadEmailAccounts()
        guard accounts[normalizedEmail] == nil else {
            throw AuthError.accountAlreadyExists
        }

        let fallbackName = normalizedEmail.components(separatedBy: "@").first
        let normalizedDisplayName = Self.normalizeDisplayName(displayName) ?? fallbackName
        let account = EmailAccount(
            id: Self.generateUserID(prefix: "u"),
            email: normalizedEmail,
            password: password,
            displayName: normalizedDisplayName
        )
        accounts[normalizedEmail] = account
        saveEmailAccounts(accounts)

        let user = mergeAndPersistProfile(
            AuthUser(
                id: account.id,
                email: normalizedEmail,
                displayName: normalizedDisplayName
            ),
            preferIncomingDisplayName: true
        )
        try persist(user)
        currentUser = user
        return user
    }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> AuthUser {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidAppleCredential
        }
        guard let identityToken = appleCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidAppleToken
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        if FirebaseApp.app() != nil {
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: rawNonce,
                fullName: appleCredential.fullName
            )
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            let user = mergeAndPersistProfile(
                AuthUser(
                    id: result.user.uid,
                    email: result.user.email ?? appleCredential.email,
                    displayName: result.user.displayName ?? Self.displayName(from: appleCredential.fullName)
                ),
                preferIncomingDisplayName: true
            )
            try persist(user)
            currentUser = user
            return user
        }
        #endif

        let subject = appleCredential.user
        let incomingName = Self.displayName(from: appleCredential.fullName)
        var appleAccounts = loadAppleAccounts()

        if var existing = appleAccounts[subject] {
            if let email = appleCredential.email {
                existing.email = email
            }
            if let incomingName, !incomingName.isEmpty {
                existing.displayName = incomingName
            }
            appleAccounts[subject] = existing
            saveAppleAccounts(appleAccounts)

            let user = mergeAndPersistProfile(
                AuthUser(
                    id: existing.id,
                    email: existing.email,
                    displayName: existing.displayName
                ),
                preferIncomingDisplayName: true
            )
            try persist(user)
            currentUser = user
            return user
        }

        let account = AppleAccount(
            id: Self.generateUserID(prefix: "a"),
            email: appleCredential.email,
            displayName: incomingName ?? localizedText("Appleユーザー", "Apple User")
        )
        appleAccounts[subject] = account
        saveAppleAccounts(appleAccounts)

        let user = mergeAndPersistProfile(
            AuthUser(
                id: account.id,
                email: account.email,
                displayName: account.displayName
            ),
            preferIncomingDisplayName: true
        )
        try persist(user)
        currentUser = user
        return user
    }

    func updateDisplayName(_ displayName: String?) async throws -> AuthUser {
        guard let existingUser = currentUser else {
            throw AuthError.notAuthenticated
        }

        let normalizedDisplayName = Self.normalizeDisplayName(displayName)
        let updatedUser = AuthUser(
            id: existingUser.id,
            email: existingUser.email,
            displayName: normalizedDisplayName
        )

        updateAccountDisplayName(userID: existingUser.id, displayName: normalizedDisplayName)
        _ = mergeAndPersistProfile(updatedUser, preferIncomingDisplayName: true)
        try persist(updatedUser)
        currentUser = updatedUser
        return updatedUser
    }

    func signOut() async throws {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: keychainKey)
    }

    private func persist(_ user: AuthUser) throws {
        let data = try JSONEncoder().encode(user)
        UserDefaults.standard.set(data, forKey: keychainKey)
    }

    private func loadEmailAccounts() -> [String: EmailAccount] {
        guard let data = UserDefaults.standard.data(forKey: emailAccountsKey),
              let accounts = try? JSONDecoder().decode([String: EmailAccount].self, from: data) else {
            return [:]
        }
        return accounts
    }

    private func saveEmailAccounts(_ accounts: [String: EmailAccount]) {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        UserDefaults.standard.set(data, forKey: emailAccountsKey)
    }

    private func loadAppleAccounts() -> [String: AppleAccount] {
        guard let data = UserDefaults.standard.data(forKey: appleAccountsKey),
              let accounts = try? JSONDecoder().decode([String: AppleAccount].self, from: data) else {
            return [:]
        }
        return accounts
    }

    private func saveAppleAccounts(_ accounts: [String: AppleAccount]) {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        UserDefaults.standard.set(data, forKey: appleAccountsKey)
    }

    private func loadProfiles() -> [String: UserProfile] {
        guard let data = UserDefaults.standard.data(forKey: profilesKey),
              let profiles = try? JSONDecoder().decode([String: UserProfile].self, from: data) else {
            return [:]
        }
        return profiles
    }

    private func saveProfiles(_ profiles: [String: UserProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesKey)
    }

    private func mergeAndPersistProfile(_ incomingUser: AuthUser, preferIncomingDisplayName: Bool) -> AuthUser {
        var profiles = loadProfiles()
        var profile = profiles[incomingUser.id] ?? UserProfile(
            id: incomingUser.id,
            email: incomingUser.email,
            displayName: nil
        )

        if let email = incomingUser.email {
            profile.email = email
        }

        if preferIncomingDisplayName, let name = Self.normalizeDisplayName(incomingUser.displayName) {
            profile.displayName = name
        } else if profile.displayName == nil,
                  let name = Self.normalizeDisplayName(incomingUser.displayName) {
            profile.displayName = name
        }

        let mergedUser = AuthUser(
            id: incomingUser.id,
            email: profile.email ?? incomingUser.email,
            displayName: profile.displayName ?? incomingUser.displayName
        )

        profiles[incomingUser.id] = UserProfile(
            id: mergedUser.id,
            email: mergedUser.email,
            displayName: mergedUser.displayName
        )
        saveProfiles(profiles)
        return mergedUser
    }

    private func updateAccountDisplayName(userID: String, displayName: String?) {
        var emailAccounts = loadEmailAccounts()
        for (key, var account) in emailAccounts where account.id == userID {
            account.displayName = displayName
            emailAccounts[key] = account
        }
        saveEmailAccounts(emailAccounts)

        var appleAccounts = loadAppleAccounts()
        for (key, var account) in appleAccounts where account.id == userID {
            account.displayName = displayName
            appleAccounts[key] = account
        }
        saveAppleAccounts(appleAccounts)
    }

    private static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeDisplayName(_ displayName: String?) -> String? {
        guard let displayName else { return nil }
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func generateUserID(prefix: String) -> String {
        let raw = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "\(prefix)_\(raw.prefix(12))"
    }

    private static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        return [components.givenName, components.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class LocalStaysServiceInline {
    private func key(for userId: String) -> String { "stays_\(userId)" }

    func listStays(for userId: String) async throws -> [Stay] {
        let k = key(for: userId)
        if let data = UserDefaults.standard.data(forKey: k),
           let stays = try? JSONDecoder().decode([Stay].self, from: data) {
            return stays.sorted(by: { $0.checkIn < $1.checkIn })
        }
        return []
    }

    func addStay(_ stay: Stay, for userId: String) async throws {
        var current = try await listStays(for: userId)
        current.append(stay)
        try persist(current, for: userId)
    }

    func upsertStay(_ stay: Stay, for userId: String) async throws {
        var current = try await listStays(for: userId)
        if let index = current.firstIndex(where: { $0.id == stay.id }) {
            current[index] = stay
        } else {
            current.append(stay)
        }
        try persist(current, for: userId)
    }

    func deleteStay(id: String, for userId: String) async throws {
        var current = try await listStays(for: userId)
        current.removeAll { $0.id == id }
        try persist(current, for: userId)
    }

    private func persist(_ stays: [Stay], for userId: String) throws {
        let sorted = stays.sorted(by: { $0.checkIn < $1.checkIn })
        let data = try JSONEncoder().encode(sorted)
        UserDefaults.standard.set(data, forKey: key(for: userId))
    }
}

final class AppContainer: ObservableObject {
    let auth: LocalAuthServiceInline
    let stays: LocalStaysServiceInline

    init() {
        // Use local implementations to ensure the app builds without Firebase or additional files.
        self.auth = LocalAuthServiceInline()
        self.stays = LocalStaysServiceInline()
    }
}
