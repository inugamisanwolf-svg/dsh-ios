# DSH — iPhone ネイティブクライアント

DeepSeek Harness の Web UI をそのまま 1 個の iOS アプリに閉じ込めたもの。Safari を開かない、ホーム画面のアイコンから起動して、独立した Cookie 空間で動く。

- **SwiftUI + WKWebView**、iOS 16.0+
- 初回だけ `?token=...` 付き URL を貼る → 以降は 30 日 Cookie で素通り
- pull-to-refresh / 戻るスワイプ / 401 検知で再トークン要求 / ホスト到達不可のエラーカード
- 外部リンクは Safari に投げる、`window.open` は同一 WebView 内で処理
- ローカルネットワーク（LAN の PC）と Tailscale の両対応（ATS は緩めてある）

## ビルド（Mac 不要 / GitHub Actions）

`.github/workflows/ios-build.yml` が `xcodegen` でプロジェクトを生成し、**署名なし IPA** を作って artifact に上げる。

```bash
# 一度だけ
gh repo create dsh-ios --public --source=. --remote=origin --push

# ビルド（push で自動、または手動）
gh workflow run ios-build
gh run watch
gh run download -n DSHMobile-unsigned-ipa      # -> DSHMobile-unsigned.ipa
```

公開リポジトリにしているのは、**public リポジトリの macOS ランナーは無料枠を消費しない**から（private だと macOS は 1 分 = 10 分換算で喰う）。private にしたいなら `gh repo edit --visibility private --accept-visibility-change-consequences`。

## インストール（Windows から / 署名）

IPA は署名なしなので、自分の Apple ID で署名して入れる。

### 方法 A: Sideloadly（一番ラク）

1. https://sideloadly.io/ をインストール（iTunes か Apple Devices アプリが必要）
2. iPhone を USB 接続 → Sideloadly にデバイスが出る
3. `DSHMobile-unsigned.ipa` をドラッグ、**Apple ID** を入れて Start
4. iPhone: 設定 → 一般 → VPN とデバイス管理 → デベロッパアプリ → 自分の Apple ID を**信頼**
5. 設定 → プライバシーとセキュリティ → **デベロッパモード**を ON（iOS 16+）→ 再起動

### 方法 B: MobAI（`ios-builder` 併用時）

`builder ios build --unsigned` → MobAI が USB 越しに再署名して直接インストール。

### 方法 C: 有料 Apple Developer（$99/年）

証明書が 1 年持つ。無料 Apple ID は **7 日で失効**（再署名が必要）、同時 3 アプリまで。常用するなら課金が正解。

## 初回接続

PC 側で:

```powershell
dsh --profile web --host 192.168.0.200 --port 59714 --no-open
# 出力: dsh web: http://192.168.0.200:59714/?token=XXXX
```

アプリを開く → その URL を丸ごと貼る → 接続。Host が token を HttpOnly Cookie（30日）に交換して `./` に 303 する。以降は `http://192.168.0.200:59714` だけで繋がる。

- Cookie が切れた / 別端末 → 401 を検知してトークン入力シートが出る。新しい `?token=` を貼る。
- ホストを止めた / 別 Wi-Fi → エラーカード（再試行 / 接続設定）。
- 外出先 → PC 側を `--host 100.99.81.43`（Tailscale IP）で立てて、アプリの接続先をそれに変える。

## 構成

```
project.yml                     XcodeGen 定義（bundle id: dev.inugami.dshmobile）
Resources/Info.plist            ATS / ローカルネットワーク許可 / ダーク固定
Resources/Assets.xcassets       AppIcon（tools/make_icon.py で生成）
Sources/DSHMobileApp.swift      @main
Sources/AppModel.swift          接続先の保存・トークン・エラー状態
Sources/RootView.swift          初回セットアップ or WebView
Sources/ConnectView.swift       ホスト入力 / 設定シート
Sources/WebContainer.swift      WebView + 歯車 + エラーオーバーレイ
Sources/WebView.swift           WKWebView（Cookie 永続 / refresh / 401 / 外部リンク）
```

## 既知の制約

- WKWebView なので通知・バックグラウンド実行は無い（チャット UI 用途では不要）。
- 無料 Apple ID 署名は 7 日で切れる → 期限が来たら Sideloadly で再署名。
- アイコンは単一 1024px（Xcode 14+ の single-size 形式）。
- HTTP 平文接続（LAN 内）。TLS にしたければ Host を `--tls-cert/--tls-key` で立てて、接続先を `https://...` にする。
