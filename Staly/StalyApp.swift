//
//  StalyApp.swift
//  Staly
//
//  Created by 西村光篤 on 2026/02/18.
//

import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct CheckInnApp: App {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @StateObject private var container: AppContainer
    @StateObject private var session: SessionViewModel

    init() {
        // Configure Firebase if the SDK is added to the project
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif

        let container = AppContainer()
        _container = StateObject(wrappedValue: container)
        _session = StateObject(wrappedValue: SessionViewModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(session)
                .environment(\.locale, appLanguage.locale)
        }
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }
}
