# Facts

Facts is an iOS news app that brings together coverage of the same story from multiple outlets. It provides a concise briefing based on that coverage and lets readers explore the original articles in one place.

[Download Facts on the App Store](https://apps.apple.com/app/id6748583935)

<p align="center">
  <img src="https://github.com/user-attachments/assets/d96a732f-bdbf-42f5-bfee-06984c12d2c8" alt="Facts home feed" width="320">
  <img src="https://github.com/user-attachments/assets/f9d8d019-7dd0-4039-86db-0c71ccf24a06" alt="Facts news detail" width="320">
  <img src="https://github.com/user-attachments/assets/64d0e8ad-8df9-477e-abd1-c880c0f08676" alt="Facts story mode" width="320">
</p>

## Features

- Daily feed organised around stories, with categories and search
- News coverage from outlets in Spain and the U.S.
- Concise briefings based on coverage from multiple outlets
- Story Mode for browsing the day's top stories in a visual, full-screen format
- Saved stories synced with iCloud
- Home Screen widgets, deep links and push notifications
- Premium subscriptions with RevenueCat and StoreKit 2
- On-device story Q&A using Apple Foundation Models on supported devices

## Built with

- SwiftUI and MVVM
- Swift 6 and structured concurrency with `async`/`await`
- SwiftData for local caching and saved stories, with CloudKit sync for saved content
- WidgetKit
- Firebase: Firestore, Remote Config, Cloud Messaging (FCM), Analytics and Crashlytics
- Backend services running on Google Cloud Run, with scheduled jobs via Cloud Scheduler
- RevenueCat and StoreKit 2

## Testing

The project includes a Swift Testing suite covering view models, services, persistence, caching, deep links and widgets.

## License

This project is proprietary and is not open source. See [LICENSE](./LICENSE).
