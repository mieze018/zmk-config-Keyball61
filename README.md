This keeb created by a group of people who loves keyball.

Special Thanks to: <br>
PCB: _[yangxing844](https://github.com/yangxing844)_ <br>
Case: _[delock](https://github.com/delock)_ <br>
Firmware: _[Amos698](https://github.com/Amos698)_ <br>

# Memo

- left ball (mirrored)
- micro controller: NRF52840
- trackball sensor: PMW3610
- COROPIT

## トラックボール関連の設定

### auto mouse layer switching の設定

input processors で行う

- スクロールレイヤー、スナイプレイヤーなどのトラックボールの挙動を変えるレイヤーの設定
- トラックボールを動かしたら自動的にマウススレイヤーをアクティブにする設定

- [trackball_listener](./config/boards/shields/keyball61/keyball61_left.overlay#133)
- [zip_temp_layer](config/keyball61.keymap#L13)

#### マウスキーの設定 （それ以外のキーを押してマウスレイヤーの自動解除）
- [excluded-positions](config/boards/shields/keyball61/keyball61_left.overlay#L133)

### マウスポインター加速度の設定

- [&pointer_accel](config/boards/shields/keyball61/keyball61_left.overlay#L141)

### デバウンスの設定

- [config/keyball61.conf](config/keyball61.conf)
- https://zmk.dev/docs/features/debouncing


## レイヤーを追加した後変更すべき点

デバイスごとのレイヤーはベースレイヤーの後に、ほかの特殊レイヤーの前に追加する必要がある。（transparentが正しく機能するため）

- マウスレイヤー番号
	- [&zip_temp_layer](config/boards/shields/keyball61/keyball61_left.overlay#L141) 
	- [&zip_temp_layer](config/keyball61.keymap#L13)
- スクロールレイヤー番号 [trackball_listener.scroll.layers](config/boards/shields/keyball61/keyball61_left.overlay#L151)
- 既存のレイヤー切り替えキーの切り替え先レイヤー番号


# keymap drawer

<img src="keymap-drawer/keyball61.svg" >
