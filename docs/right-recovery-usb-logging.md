# 右側マイコン交換後のUSBログ診断

## 目的・背景

右側の全キーが反応しない原因を、BLE split接続と右側キーマトリクスのログで切り分けます。設定初期化と左右リセットは実施済みのため、同じ操作を繰り返しません。

正常な構成は `leftball`、診断用構成は `codex/right-recovery-usb-logging` です。診断は `leftball` のコミット `ab38b4c` を起点とします。

確認済みの構成:

- ZMK v0.3では左側がCentral、右側がPeripheralです。役割の逆転は確認されていません。
- 元の右側にはUSBログ用snippetが指定されていません。USB認識やLEDだけではBLE接続・キースキャンの正常動作を確認できません。
- 右側OLEDは未接続ですが表示機能は有効です。今回の診断では設定を維持し、エラーが記録されるか確認します。全キー無反応の原因と断定しません。
- 外部モジュールのうち2件は `main` を参照しています。過去のUF2と今回のソースが一致する保証はありません。Actionsの依存取得ログも保存します。

変更は公式 `zmk-usb-logging` snippet、ZMK DEBUGログ、起動ログ出力の8秒遅延、診断UF2のファイル名です。GPIO・キーマップ・BLE接続設定・トラックボール設定は維持します。左側はStudio用とログ用の別々のCDC ACMインターフェースを持ちます。

構成案は、既存の `build.yaml` と共通confを変更する案と、`config/snippets/` に独自snippetを作る案を比較しました。前者は変更が少なく公式実装を使えるため採用しました。その代わり、このブランチの左右UF2は常にログ有効です。独自snippet案は設定を分離できますが、探索・適用の検証が増えるため採用していません。

公式ソース:

- [v0.3 USBログsnippet](https://github.com/zmkfirmware/zmk/tree/v0.3/app/snippets/zmk-usb-logging)
- [v0.3 ログKconfig](https://github.com/zmkfirmware/zmk/blob/v0.3/app/Kconfig)
- [Centralの接続ログ](https://github.com/zmkfirmware/zmk/blob/v0.3/app/src/split/bluetooth/central.c)
- [Peripheralの接続ログ](https://github.com/zmkfirmware/zmk/blob/v0.3/app/src/split/bluetooth/peripheral.c)
- [GPIOマトリクスのログ](https://github.com/zmkfirmware/zmk/blob/v0.3/app/module/drivers/kscan/kscan_gpio_matrix.c)

## 操作手順

### 確認済みのビルド結果（2026-10-12）

[Actions run 38204254401](https://github.com/mieze018/zmk-config-Keyball61/actions/runs/38204254401) は左右・settings_reset・成果物統合の全ジョブが成功しました。対象ソースは診断コミット `aea145c3539f4d2a3d92fb48101a89a4bd28d97d` です。

| 項目 | 左側 | 右側 |
|---|---|---|
| USBログ / CDC ACM / UART console | 有効 | 有効 |
| ZMKログレベル | DEBUG（4） | DEBUG（4） |
| 起動ログ出力遅延 / バッファ | 8000ms / 8192バイト | 8000ms / 8192バイト |
| splitの役割 | Central | Peripheral |
| Studio / PMW3610 / pointing / USB HID / BLE | 有効 | USBログとBLEが有効。USB HIDは無効 |
| Devicetreeのconsole | ログ用CDCノード | ログ用CDCノード |
| Studio用CDC | ログ用とは別ノード | なし |
| UF2ファイルサイズ | 893952バイト | 627200バイト |

右側のDevicetreeはrowが4・5・6・7・8、colが21・20・19・18・15・14・16で、元の設定と一致しました。両UF2の全ブロックについてマジック値・連番・総ブロック数・アドレスの連続性・nRF52840 family IDを検証しました。両UF2にGPIO初期化・キーイベント・切断・認証エラーの文字列、左側UF2にsplitサービス探索・購読の文字列を確認しました。

SHA-256:

- 右側: `486ee7008bbf46386d85dabcc68e132825368b7e2bf0cfe104d0c572a1a6b3a7`
- 左側: `b423f77acdaacfe4b6222d634728a4788a07a13c1f532599d92dd652e3b8ad70`

依存取得ログで確認したリビジョン:

- ZMK: `edf5c08`（v0.3）
- Zephyr: `dacab487`（v3.5.0+zmk-fixes）
- zmk-pmw3610-driver: `9c44206`
- zmk-pointing-acceleration: `0da8f97`
- zmk-scroll-snap: `62a669c`

右側のKconfig警告は、共通設定のUSB HIDとCentral専用バッテリー取得・代理通知がPeripheralでは無効になるという内容でした。USBログ用CDCは有効です。ほかに上流コードの非推奨設定とコンパイラ警告が記録されていますが、ビルドは成功しています。

未確認なのは実機のUSBシリアル認識・BLE接続・キー入力・左側の各機能です。ビルドとUF2の検証だけでは断線・無線故障・動作正常を確定できません。

### 1. ビルドの確認

診断ブランチのBuild ZMK Firmwareが成功したことを確認します。ActionsログのKconfigとDevicetreeで次を確認します。

- 左右: `CONFIG_ZMK_USB_LOGGING=y`、`CONFIG_ZMK_LOG_LEVEL=4`、`CONFIG_USB_CDC_ACM=y`、`CONFIG_UART_CONSOLE=y`。
- 左右: `CONFIG_LOG_PROCESS_THREAD_STARTUP_DELAY_MS=8000`。
- 左側のみ: `CONFIG_ZMK_SPLIT_ROLE_CENTRAL=y`、`CONFIG_ZMK_STUDIO=y`、Studio用CDCノード。
- 右側: Peripheral、期待したrow/col GPIO、ログ用CDCノードと `zephyr,console` の参照。

成果物 `firmware` のZIPをUTF-8対応ツールで展開します。診断UF2は `keyball61_right-usb-diagnostic.uf2` と `keyball61_left-usb-diagnostic.uf2` です。`settings_reset` は今回は書き込みません。

### 2. 最初は右側だけを書き込む

1. 左側は正常なファームウェアのまま通電します。
2. 右側だけをダブルリセットでUF2ブートローダーへ移行します。
3. 右側のUF2ストレージへ `keyball61_right-usb-diagnostic.uf2` をコピーします。
4. 右側をUSBでMacへ接続したまま、次のコマンドでシリアルポートを探します。

```sh
find /dev -maxdepth 1 -name 'cu.usbmodem*' -print
```

5. 表示された右側のパスを指定し、ログをファイルへ保存します。以下の `XXXXX` は実際のパスへ置き換えます。

```sh
script -q ~/Desktop/keyball-right-usb.log screen /dev/cu.usbmodemXXXXX 115200
```

6. 接続直後のログを保存し、右側の異なる行・列から数キーを押します。約30秒記録します。
7. ログを表示しているMacのターミナルを選び、**Mac本体のキーボード**で以下を入力します。右側Keyballのキーを使う操作ではありません。ログ閲覧用のscreenを終了して、保存ファイルを閉じるための操作です。
   - Controlを押しながらAを押し、両方を離します。
   - 次にバックスラッシュ（`\`）を入力します。
   - 終了確認が表示されたら `y` を入力します。
   - Desktopに保存された `keyball-right-usb.log` を担当AIへ共有します。

最初に必要な実機操作はここまでです。ログの内容に応じて次へ進みます。

### 3. 左側ログが必要な場合

右側ログでBLE接続を判断できない場合、左側にも診断UF2を書き込みます。左右のUSBポートを抜き差ししてパスを特定します。左側はStudio用とログ用の2ポートを持つため、テキストログを出力するポートを選びます。Studioとの同時接続は避けます。

左側ログを開いた状態で右側を通電し、スキャン・接続・サービス探索・購読・キー通知・切断理由を保存します。MacへのBLE HID接続ログと、右側Peripheralへの接続ログを区別します。

左側の診断UF2を書き込んだ後も、文字入力とトラックボールが動くことを実機で確認済みです。

左側をUSB接続したまま、Macのターミナルで次を実行します。

```sh
bash /Users/nakataayu/Documents/GitHub/zmk-config-Keyball61/scripts/capture-left-usb.sh
```

「ログ取得を開始しました」と表示されてから右側をUSBで通電します。すでに右側が通電中なら右側を1回だけリセットします。30秒待ち、Mac本体のControl+Cで終了します。保存先はDesktopの `keyball-left-usb.log` です。

この診断ビルドの左側はUSB data interface 1がStudio、4がログです。スクリプトはMacのUSB情報から製品名 `Keyball61` とinterface 4を照合し、実行時のポートを選びます。指定の構成に限定する代わりに、ユーザーが2ポートを試す手数を減らします。ログ用ポートを1つに特定できない場合はファイルを上書きせず終了します。

USBポート名は抜き差しや接続するUSBハブ・ポートによって変わるため、以前の `/dev/cu.usbmodem...` を固定して使わないでください。固定したポートが存在しなかった実行では `keyball-left-usb.log` は0バイトで、ログ取得は失敗していました。

## ログの読み方

実機から受け取った結果: 右側USBログ取得は成功しました。ディスプレイ初期化失敗・I2Cエラーが記録され、右側の全キーを押してもログは変化しませんでした。GPIO初期化のログは未確認のため、断線やGPIO故障はまだ確定していません。

その後 `keyball-right-startup.log` を取得し、入力5本・出力7本すべてのGPIO設定APIが成功したことを確認しました。Bluetoothコントローラーの初期化とIdentityの設定も記録されています。OLED初期化失敗は引き続き記録されています。GPIO設定成功はPCB・コンスルーの導通を保証せず、BLE接続成立もこのログでは確認できません。次は左側の診断UF2でCentral側の接続・探索・購読ログを取得します。

左側ログの取得後、右側のIdentityと一致するアドレスについて次を確認しました。

- 起動後03:37.339: BLEリンクが成立しました。
- 03:37.350: splitサービスを発見しました。
- 03:37.356および03:37.730: `pairing failed (peer reason 0x3)`。右側が認証要件エラーを返しました。
- `Security failed ... level 1 err 4`: 暗号化されていないレベル1のまま、要求されたセキュリティレベルへ到達できませんでした。
- キー状態の購読を開始した後に `[UNSUBSCRIBED]` が記録され、キー状態通知は記録されていません。

エラーの意味は、今回のZephyrリビジョン [conn.h](https://github.com/zmkfirmware/zephyr/blob/dacab4875df7/include/zephyr/bluetooth/conn.h) の `BT_SECURITY_ERR_AUTH_REQUIREMENT` と、[smp.h](https://github.com/zmkfirmware/zephyr/blob/dacab4875df7/subsys/bluetooth/host/smp.h) の `BT_SMP_ERR_AUTH_REQUIREMENTS=0x03` で照合しました。[smp.c](https://github.com/zmkfirmware/zephyr/blob/dacab4875df7/subsys/bluetooth/host/smp.c) には、保存済み鍵の更新拒否・認証方式やSecure Connectionsの要件不一致など複数の失敗経路があります。このログだけで保存済み鍵の不一致を断定しません。

別アドレスの `SKIPPING FOR ROLE 1` を伴う接続・切断はMac側のHID経路と区別します。`Failed to release peripheral slot (-22)` だけを右側の失敗として扱いません。

次の実機操作は、左側を通電したまま右側の起動ログを取得することです。前回の右側ログには含まれなかった、実際の左右ペアリング時に右側が拒否した側のログを確認します。右側のログ取得が始まった後はキー押下を追加し、認証失敗と右側キースキャン無反応を別々に調査します。両側の設定初期化は繰り返しません。

右側の再取得ではファイルが0バイトでしたが、担当AIが右側のUSB CDCをDTR（Mac側で読み取り準備ができたことを伝える信号）を明示して開くと1156バイトを読み取れました。右側にも `Security failed ... level 1 err 4` が2回記録されていました。これ以上同じ条件の再取得を依頼せず、右側のペアリング処理（SMP）をDEBUGへ変更し、ログバッファを32768バイトへ拡大します。GPIOや認証条件は変更しません。詳細ログには鍵情報が含まれうるため、公開せずこの診断の範囲で扱います。

追加の診断UF2は `keyball61_right-pairing-diagnostic.uf2` です。右側ログ取得スクリプトもDTRを明示する方式へ修正し、終了時に取得バイト数を表示します。0バイトは成功扱いにしません。左側は現在の診断UF2と電源を維持します。右側ログを取得するときは右側をMacへUSB接続し、左側は充電器またはバッテリーによる通電でも構いません。

追加診断の [Actions run 38253959004](https://github.com/mieze018/zmk-config-Keyball61/actions/runs/38253959004) の右側ビルドは成功しました。ソースは `70b5c02` です。最終KconfigのSMPログレベル4・ZMKログレベル4・32768バイトのバッファ・USBログ有効を確認しました。Secure Connections限定の認証条件は維持され、未認証鍵の上書きとパスキー入力は無効のままです。UF2の全ブロック構造・連番・総ブロック数・nRF52840 family IDと、ペアリング要求のDEBUGログ文字列を検証しました。

- UF2: 631296バイト
- SHA-256: `f204026df2fbe6544a8b38edc33e472ba48dc285271c49a7b40b91acd9e897c9`
- 実機の次の操作: 右側だけに追加診断UF2を書き込み、書き込み完了を共有します。左側は書き換えません。

### 起動直後のログを取得する

目的は、前回のログに含まれていないGPIO初期化の成功・失敗を確認することです。`scripts/` の独立スクリプトと手順書へのコマンド埋め込みを比較し、コピーするコマンドが短くなる独立スクリプトを採用しました。その代わり管理ファイルが1つ増えます。

1. 既存のscreenを終了し、右側のUSBをMacから外します。バッテリー接続中ならUSBを外すだけでは右側は再起動しません。
2. Macのターミナルで以下を実行します。

```sh
bash /Users/nakataayu/Documents/GitHub/zmk-config-Keyball61/scripts/capture-right-startup.sh
```

3. 「待機中です」と表示されたら、右側のUSBをMacへ接続します。バッテリー接続中の場合は、**USB接続の直前**に右側のリセットを1回だけ押し、すぐUSBを接続します。ダブルリセットはブートローダーへ移行するため使いません。
4. スクリプトは開始時に存在しなかったUSBシリアルポートを100ms間隔で探し、自動でログ取得を始めます。この間に別のUSBシリアル機器を接続しないでください。
5. 約15秒待ち、Mac本体のControl+Cで終了します。保存先はDesktopの `keyball-right-startup.log` です。

USB切断やリセットで記録が終了する場合は、その時点までのログを担当AIへ共有します。8秒遅延と自動接続でも起動ログの取得は保証できません。初期化ログが含まれるかを確認してから、次の診断を決めます。スクリプトは `bash -n` で構文を確認済みです。USB CDCからの実機取得は未確認です。

| ログ | 確認できること | 確認できないこと |
|---|---|---|
| `Configured pin ... for input/output` | GPIOの設定APIが成功した | PCB・コンスルーの導通 |
| `Sending event at r,c state on/off` | 右側がそのキーの押下・解放を検出した | 左側への配送成功 |
| Centralの `Connected` | BLEリンクが成立した | split通知の購読成功 |
| `Found split service`・`[SUBSCRIBED]` | splitサービスを発見し通知を購読した | 全キーの導通 |
| Centralの `[NOTIFICATION]` | 右側からキー状態通知を受信した | 全キーが正常か |
| `Disconnected`・`Security failed` | 切断理由や認証エラー | エラーの根本原因。前後のログが必要 |

右側でキーイベントが記録されるのに左側へ通知されなければBLE経路を調査します。BLE購読まで成功しても右側のキーイベントが記録されなければGPIO・マトリクス経路を調査します。APIが成功しても配線の断線はログだけでは検出できません。

## 注意点

- 実機への書き込みと物理操作はユーザー自身が実施します。
- 起動ログの8秒遅延はシリアルを開く時間を確保するためです。バッファは有限で、全起動ログの保存を保証しません。
- DEBUGログは消費電力と処理負荷を増やします。USB給電で診断し、診断後は保存してある正常なUF2へ戻します。
- 左側のUSB HID・BLE HID・トラックボールの設定は維持しますが、診断ファームウェアでの実機動作は書き込み後に確認します。
- ボンド情報を削除する設定は追加していません。リセットUF2の再書き込みはログで必要性を確認してから判断します。
- ログのBLEアドレス等は診断情報です。公開する場合は共有範囲を確認してください。

## トラブルシューティング

| 状況 | 次の操作 |
|---|---|
| `cu.usbmodem` が増えない | UF2ストレージが消え通常起動したか、正しい右側診断UF2か、USBケーブルが通信対応か確認します |
| 左側で文字ログが読めない | Studio用ポートを閉じ、もう1つのCDCポートを試します |
| `screen` がポート使用中と表示する | Studio・他のシリアルモニターを終了します |
| 起動ログを取り逃した | まず通電中のキーイベントと接続ログを保存します。再起動後はポートを開き直し、8秒以内の接続を試します |
| OLED/I2Cエラーが記録された | 前後のGPIO・BLE・キーイベントも保存します。OLEDエラーだけで原因を断定しません |
| ログにキーイベントが存在しない | GPIO初期化ログとBLEログを共有します。配線変更は原因を絞ってから判断します |
