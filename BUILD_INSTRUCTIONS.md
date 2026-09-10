# JPG 瘦身工具（jpg_slimming）v1.1.2 — 建置說明（少量註解版）

這是一份 Flutter 專案原始碼（註解已精簡），可在**其他電腦**上直接建置 APK。


## 環境需求
- Flutter SDK（stable，建議 3.44.x 或更新，含 Dart 3.12+）
- Android SDK（compileSdk 36 或更新）、Build-Tools 36
- Java 17（JDK 17）
- 已接受 Android SDK Licenses（`flutter doctor --android-licenses`）


## 建置步驟（Windows）
```bat
cd D:\jpg_slimming
flutter pub get          :: 取得依賴（自動產生 android\local.properties）
flutter analyze          :: 靜態檢查（建議）
flutter build apk --debug
flutter build apk --release
```
產出：`build\app\outputs\flutter-apk\app-debug.apk`（Debug）、`app-release.apk`（Release）


## 注意事項
1. 勿手動建立 `android\local.properties`：`flutter pub get` 會依本機 SDK 自動產生。
2. `android\gradle.properties` 已預設 2GB 記憶體限制（低記憶體也能建）。
   若遇 `Cannot access input property 'sourceFiles'`：刪除 `android\.gradle` → `flutter clean` → 重建。
3. 需要網路下載 pub 套件與 Gradle 依賴（首次較久）。
4. Android 13+ 需授予「通知」權限，狀態列通知才會顯示。
5. Release 正式上架需自行設定簽章。


## 功能一覽
- 手動模式：品質（%）＋解析度（%）
- 自動模式（目標容量，預設 10MB）：品質優先、解析度其次，可設下限；跳過下限時品質/解析度交替均衡降級
- 背景自動化：即時／定時／關閉（2x2 方格）
- 狀態列通知：監控中／處理中（進度）／已暫停／已停止
- 處理區塊：分頁（5／10／20 每頁）、停止／暫停·繼續、「是否重新處理」開關（預設關閉）
- 明暗主題、繁中／English 雙語