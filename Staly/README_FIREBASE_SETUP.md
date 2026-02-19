# Firebase & Sign in with Apple Setup for Staly

This app runs out-of-the-box with local services. Follow the steps below to switch to Firebase in production.

## 1) Firebase Project
- Create a Firebase project.
- Add an iOS app (bundle ID must match your app).
- Download GoogleService-Info.plist and add it to the Xcode project (top-level, target included).
- Add dependencies via Swift Package Manager or CocoaPods:
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseFirestoreSwift

## 2) Sign in with Apple
- In Apple Developer portal, enable Sign in with Apple for your App ID.
- In Xcode target Signing & Capabilities, add "Sign In with Apple" capability.
- For Firebase Apple auth, configure OAuth provider:
  - In Firebase Console > Authentication > Sign-in method, enable Apple.
  - Configure Services ID and redirect URLs per Firebase docs.

## 3) URL Types & Reversed Client ID
- In Xcode target > Info > URL Types, add your reversed client ID from GoogleService-Info.plist under URL Schemes.

## 4) Update FirebaseAuthService Apple Sign-in
- Implement `signInWithApple(presentationAnchor:)` using AppleSignInHelper to obtain (idToken, nonce), then sign in with Firebase:

```swift
let helper = AppleSignInHelper()
let (idToken, rawNonce) = try await helper.start(anchor: anchor)
let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idToken, rawNonce: rawNonce)
let result = try await Auth.auth().signIn(with: credential)
return AuthUser(id: result.user.uid, email: result.user.email, displayName: result.user.displayName)
