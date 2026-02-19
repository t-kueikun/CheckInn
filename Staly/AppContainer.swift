//
//  AppContainer.swift
//  Staly
//
//  Created by 西村光篤 on 2026/02/18.
//

import Foundation

final class AppContainer: ObservableObject {
    let auth: AuthService
    let stays: StaysService

    init() {
        // Default to local implementations so the app runs immediately.
        // If Firebase SDKs are linked, the conditional branches will use them instead.
        #if canImport(FirebaseAuth)
        self.auth = FirebaseAuthService()
        #else
        self.auth = LocalAuthService()
        #endif

        #if canImport(FirebaseFirestore)
        self.stays = FirestoreStaysService()
        #else
        self.stays = LocalStaysService()
        #endif
    }
}
