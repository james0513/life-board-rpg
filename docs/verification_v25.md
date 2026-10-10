# v0.25 驗證記錄

日期：2026-10-10
基底：[james0513/life-board-rpg](https://github.com/james0513/life-board-rpg/tree/5b9beaba242ea9e00f6a97e47604e190aeac9e29)
提交：`5b9beaba242ea9e00f6a97e47604e190aeac9e29`

## 已通過

- 原版 76 個 Dart 檔案的語法解析；最終版 `lib/`、`test/` 與兩個獨立驗證工具共 83 個 Dart 檔案的語法解析。
- 最終版全部 `lib/domain/` 與兩個獨立驗證工具的 Dart 靜態分析：無問題。
- 27 個無 Flutter 套件依賴的核心測試：所有 31 職業 ID、每個職業只學一次、天賦傳承只加一次、失敗操作不改原資料、不可變狀態、存檔 v1–v6 遷移與錯誤存檔拒絕。
- 10 組固定亂數種子的腳本化領域模型流程：240 場真實 `BattleSession` 勝利、每次六關完成、1,166 次存檔回讀邊界、7,996 個斷言。流程由學生 → 工程師 → 大導師，通關後轉生到第二世，僅帶入所選智力 +6 心得。
- 六組 EQ、壓力與住宅戰鬥 HP 公式檢查。
- 原專案 14 個 JSON、31 張 PNG、42 個 WAV 可解析，相對 Dart 引用可找到。
- `git diff --check` 無空白錯誤。封裝完成後另檢查 ZIP CRC、檔案清單及基底套用補丁。

這些流程是領域模型的腳本化測試，**不等於實際擲骰走圖、瀏覽器操作或 Flutter Widget 測試**。

## 尚未執行／未通過驗收

- 完整 `flutter pub get`、`flutter analyze`、`flutter test`
- 新增的人生手帳 Widget 與回合控制整合測試的 Flutter 執行
- `flutter build web`、瀏覽器畫面、按鈕操作、音訊時序、手機／Windows 實機與效能驗收

已取得並校驗官方 Flutter 3.47.7／Dart 3.13.5，但 Flutter 套件啟動程序未完成。一次以 CI 模式避免雲端執行個體偵測的正常測試呼叫，最終收到 `automatic approval review was cancelled`，測試並未開始。沒有把語法解析當作 Flutter 編譯通過。

既有 `analysis_options.yaml` 引用 `flutter_lints`，原 `pubspec.yaml` 卻未宣告它。本版加入官方 `flutter_lints: ^6.0.0`（SDK 條件 ^3.8.0）；原 `pubspec.lock` 保留不變，因此首次 `flutter pub get` 需要更新鎖定資料。

## 在原專案確認

先備份專案及舊存檔，再於專案根目錄執行：

```bat
flutter pub get
flutter analyze
flutter test
flutter run -d chrome -t lib/main.dart
```

另有不需 Flutter 套件的驗證方式（需 Dart SDK）：

```bat
dart tools/verify_life_core.dart
dart tools/verify_life_campaign.dart
```

第二個工具會在執行目錄產生 `life_campaign_report.json`；本次結果保存在 `docs/life_campaign_report.json`。

人工驗收重點：舊檔讀取、同一季不重複結算、工作三次學心得、存檔失敗後重試、人生手帳低高度與窄螢幕、轉生取消／確認、轉生後棋子與角色／裝備同步、重整後世代與天賦保留。
