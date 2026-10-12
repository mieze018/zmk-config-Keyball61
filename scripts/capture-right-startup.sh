#!/bin/bash
set -eu
shopt -s nullglob

output="${1:-$HOME/Desktop/keyball-right-startup.log}"
existing=(/dev/cu.usbmodem*)

printf '右側のUSBが外れている状態で開始してください。\n'
printf '待機中です。右側のUSBをMacへ接続してください。\n'

serial=''
while [ -z "$serial" ]; do
    for candidate in /dev/cu.usbmodem*; do
        known=false
        for previous in "${existing[@]-}"; do
            if [ "$candidate" = "$previous" ]; then
                known=true
                break
            fi
        done
        if [ "$known" = false ]; then
            serial="$candidate"
            break
        fi
    done
    if [ -z "$serial" ]; then sleep 0.1; fi
done

printf '接続先: %s\n保存先: %s\n' "$serial" "$output"
printf 'ログ取得中。終了はMac本体のControl+Cです。\n'

# ポートを開いたまま設定し、USB CDCの接続状態を維持する。
exec 3<> "$serial"
saved_settings=$(stty -f "$serial" -g)
finish() {
    stty -f "$serial" "$saved_settings" 2>/dev/null || true
    exec 3>&-
    printf '\nログ取得を終了しました。保存先: %s\n' "$output"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
stty -f "$serial" raw -echo 115200
cat <&3 | tee "$output"
