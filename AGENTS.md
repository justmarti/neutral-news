# AGENTS.md - NeutralNews (iOS)

## Purpose
This file defines how the AI should work in this repository. The goal is to keep the codebase simple, clean, professional, and aligned with Apple's recommended practices.

## Non-Negotiables
- Prefer the simplest possible solution that is correct, readable, and maintainable.
- Follow Apple's official documentation as the source of truth.
- If anything is unclear, ask for confirmation before coding.
- Keep changes scoped: prefer small, focused edits.
- If a change is large or impacts multiple areas, ask for approval before proceeding.
- No low-quality shortcuts, hacks, or speculative code. Choose clarity over cleverness.
- Use SwiftUI and MVVM in a clean, minimal way. Keep views small and composable.
- Add comments only when they add non-obvious value. Keep comments short, in English, and minimal.

## Project Structure
- App code: `NeutralNews/`
  - `Views/`, `ViewModels/`, `Models/`, `Services/`, `Utils/`, `ViewModifiers/`
- Assets: `NeutralNews/Assets.xcassets`
- App icon: `NeutralNews/AppIcon.icon`
- Info.plist: `NeutralNews/Info.plist`
- Core Data model: `NeutralNews/SavedNews.xcdatamodeld` (mirrored at repo root)
- Tests: `NeutralNewsTests/`
- Xcode project: `NeutralNews.xcodeproj`
- This is a production app; prioritize stability and avoid risky changes without approval.

## Official References (Use Latest)
- Always consult the latest official Apple documentation for any APIs or frameworks used.
- For UI/UX decisions, follow Apple's Human Interface Guidelines.
- For third-party libraries, follow the library's official documentation and recommended usage.

## Swift & SwiftUI Guidelines
- Formatting: standard Xcode formatting (4-space indentation).
- Naming: `UpperCamelCase` for types, `lowerCamelCase` for properties/methods.
- Prefer value types (struct) where appropriate.
- Avoid global state. Favor dependency injection and explicit inputs.
- Keep view models testable and free from UI-specific code.
- SwiftUI Views:
  - Small and composable.
  - Use `@State`, `@Binding`, `@StateObject`, `@ObservedObject`, and `@EnvironmentObject` appropriately.
  - Avoid heavy logic in `body`; move to view models or helper methods.
- Concurrency:
  - Use structured concurrency (`async/await`) as the default.
  - Avoid Combine unless explicitly required.
  - Avoid mixing async patterns unless necessary.

## Platform Compatibility
- Check the project's minimum iOS deployment target before using new APIs.
- If a feature requires a higher iOS version, guard it with `#available` and provide a safe fallback.
- Do not raise the deployment target without explicit approval.

## Sensitive Files
- Do not edit Xcode project files (`*.xcodeproj`, `project.pbxproj`) or UI layout files created by Xcode (`*.storyboard`, `*.xib`) unless explicitly asked.
- Do not edit `.plist` or `.entitlements` files unless explicitly asked.
- If changes are needed in those files, describe the required changes and let the user make them.

## Quality Bar
- Prioritize readability, testability, and long-term maintainability.
- Avoid duplication; extract shared logic thoughtfully.
- If there is a trade-off, choose the option that makes future changes easier.
- Match the existing accessibility level in the app; improve it when touching related UI, but avoid overhauls unless requested.

## Testing
- Prefer Swift Testing in `NeutralNewsTests/` for new tests.
  - Use `@Test` and `#expect`/`#require` where appropriate.
- If existing XCTest tests are present, keep them and extend them consistently.
- When adding tests in areas that already use XCTest, continue using XCTest for that area.
- Add/adjust tests for view models, services, and edge cases when modifying behavior.

## Dependencies & Configuration
- App configuration lives in `NeutralNews/Config.xcconfig` and `NeutralNews/GoogleService-Info.plist`.
- Be cautious with entitlements (`NeutralNews/*.entitlements`) and provisioning changes.

## Data & Persistence
- The app uses SwiftData for cache and Core Data for saved news; be extra careful when modifying related models, migrations, or storage logic.

## Backend & Third-Party Services
- Backend: Google Cloud Run + Cloud Scheduler. A scheduled job generates and stores news in Firebase; the app reads from Firebase.
- Firebase: Firestore, Remote Config, Crashlytics. Be careful with schema, config keys, and logging changes.
- Subscriptions: RevenueCat with StoreKit 2 (RevenueCat for logic, StoreKit 2 for UI). Avoid changes without checking both SDK expectations.

## Local Paths (This Machine)
- If `LOCAL.md` exists, read it for local-only paths or machine-specific notes.
- If a path is missing or invalid, ask the user for the current location.

## Communication
- If requirements are ambiguous, ask a short clarifying question before coding.
- If official documentation is required, request to verify it before implementing.
- After each change, recommend a concise Conventional Commits-style message in English (e.g., `feat: ...`, `fix: ...`, `refactor: ...`, `chore: ...`).
