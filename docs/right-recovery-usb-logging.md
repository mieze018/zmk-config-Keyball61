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
7. `Ctrl-A`、続いて `\`、確認に `y` を入力してscreenを終了します。保存したログを担当AIへ共有します。

最初に必要な実機操作はここまでです。ログの内容に応じて次へ進みます。

### 3. 左側ログが必要な場合

右側ログでBLE接続を判断できない場合、左側にも診断UF2を書き込みます。左右のUSBポートを抜き差ししてパスを特定します。左側はStudio用とログ用の2ポートを持つため、テキストログを出力するポートを選びます。Studioとの同時接続は避けます。

左側ログを開いた状態で右側を通電し、スキャン・接続・サービス探索・購読・キー通知・切断理由を保存します。MacへのBLE HID接続ログと、右側Peripheralへの接続ログを区別します。

## ログの読み方

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
