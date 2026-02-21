# FirebaseAuthKit

Firebase Auth의 Google/Apple 로그인 boilerplate를 Swift Package로 추출한 라이브러리.

## 설치

Xcode > File > Add Package Dependencies에서 아래 URL 추가:

```
https://github.com/eraser3031/FirebaseAuthKit.git
```

### 요구사항

- iOS 17+ / macOS 14+
- Firebase 프로젝트 설정 완료 (`GoogleService-Info.plist`)
- Google Sign-In URL scheme 설정

## 사용법

### 기본 설정

```swift
import FirebaseAuthKit
import FirebaseCore

@main
struct MyApp: App {
    @State private var auth = AuthKit()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            if auth.isLoading {
                ProgressView()
            } else if auth.isSignedIn {
                HomeView()
            } else {
                AuthKitView()
            }
        }
        .environment(auth)
        .onOpenURL { url in
            AuthKit.handleOpenURL(url)
        }
    }
}
```

### AuthKitView

Apple 로그인 + Google 로그인 버튼이 포함된 즉시 사용 가능한 뷰.

```swift
AuthKitView()
    .environment(auth)
```

### 직접 구성

버튼을 직접 배치하고 싶다면 `AuthKit`의 메서드를 개별 호출:

```swift
@Environment(AuthKit.self) private var auth

// Apple
SignInWithAppleButton(.signIn) { request in
    auth.handleSignInWithAppleRequest(request)
} onCompletion: { result in
    auth.handleSignInWithAppleCompletion(result)
}

// Google
Button("Google 로그인") {
    auth.signInWithGoogle()
}

// 로그아웃
Button("로그아웃") {
    auth.signOut()
}

// 계정 삭제
Button("계정 삭제") {
    await auth.deleteAccount()
}
```

### 상태 관찰

```swift
auth.isLoading    // Bool - 초기 인증 상태 확인 중
auth.isSignedIn   // Bool - 로그인 여부
auth.user         // Firebase User?
auth.errorMessage // String? - 에러 발생 시 메시지
```

## 구조

| 파일 | 역할 |
|------|------|
| `AuthKit` | `@Observable` 인증 서비스. Apple/Google 로그인, 로그아웃, 계정 삭제 |
| `AuthKitView` | Apple + Google 로그인 버튼과 에러 alert이 포함된 SwiftUI 뷰 |
| `NonceHelper` | nonce 생성 + SHA256 해싱 유틸리티 |
