//
//  AppLanguage.swift
//  CheckInn
//
//  Created by Codex on 2026/02/18.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese
    case english

    static let storageKey = "checkinn.appLanguage"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .japanese:
            return Locale(identifier: "ja")
        case .english:
            return Locale(identifier: "en")
        }
    }

    var isJapanese: Bool {
        switch self {
        case .japanese:
            return true
        case .english:
            return false
        case .system:
            return Locale.autoupdatingCurrent.identifier.lowercased().hasPrefix("ja")
        }
    }

    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        return AppLanguage(rawValue: raw ?? AppLanguage.system.rawValue) ?? .system
    }
}

func localizedText(_ japanese: String, _ english: String) -> String {
    AppLanguage.current.isJapanese ? japanese : english
}
