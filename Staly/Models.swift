//
//  Models.swift
//  Staly
//
//  Created by Codex on 2026/02/18.
//

import Foundation

struct AuthUser: Codable, Equatable, Identifiable {
    let id: String
    let email: String?
    let displayName: String?
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case accountNotFound
    case accountAlreadyExists
    case notAuthenticated
    case missingAppleNonce
    case invalidAppleCredential
    case invalidAppleToken

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return localizedText(
                "メールアドレスまたはパスワードが不正です。",
                "The email address or password is invalid."
            )
        case .accountNotFound:
            return localizedText(
                "アカウントが見つかりません。新規登録してください。",
                "Account not found. Please create a new account."
            )
        case .accountAlreadyExists:
            return localizedText(
                "このメールアドレスはすでに登録されています。",
                "This email address is already registered."
            )
        case .notAuthenticated:
            return localizedText(
                "ログイン状態が見つかりません。",
                "No active session was found."
            )
        case .missingAppleNonce:
            return localizedText(
                "Appleサインインの内部状態が失われました。再度お試しください。",
                "Apple sign-in internal state was lost. Please try again."
            )
        case .invalidAppleCredential:
            return localizedText(
                "Appleサインインの認証情報を取得できませんでした。",
                "Could not retrieve Apple sign-in credentials."
            )
        case .invalidAppleToken:
            return localizedText(
                "AppleのIDトークンを取得できませんでした。",
                "Could not retrieve Apple ID token."
            )
        }
    }
}

struct Stay: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var city: String?
    var checkIn: Date
    var checkOut: Date?
    var note: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        city: String? = nil,
        checkIn: Date,
        checkOut: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.city = city
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.note = note
    }
}
