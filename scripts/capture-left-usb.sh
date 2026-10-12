#!/bin/bash
set -euo pipefail

# この診断ビルドではStudioのdata interfaceが1、ログのdata interfaceが4。
# USB再接続で変わるポート名を、MacのUSB情報から毎回取得する。
serial=$(/usr/bin/python3 - <<'PY'
import plistlib
import subprocess
import sys

try:
    root = plistlib.loads(subprocess.check_output(['ioreg', '-a', '-l', '-p', 'IOService']))
except (subprocess.CalledProcessError, OSError, plistlib.InvalidFileException) as error:
    print('MacのUSB情報を取得できませんでした: ' + str(error), file=sys.stderr)
    sys.exit(1)
ports = []

def walk(node, product=None, interface=None):
    if not isinstance(node, dict):
        return
    if node.get('IOObjectClass') == 'IOUSBHostDevice':
        product = node.get('USB Product Name')
        interface = None
    if node.get('IOObjectClass') == 'IOUSBHostInterface':
        interface = node.get('bInterfaceNumber')
    port = node.get('IOCalloutDevice', '')
    if product == 'Keyball61' and interface == 4 and port.startswith('/dev/cu.usbmodem'):
        ports.append(port)
    for child in node.get('IORegistryEntryChildren', []):
        walk(child, product, interface)

if isinstance(root, list):
    for node in root:
        walk(node)
else:
    walk(root)
if len(ports) != 1:
    print('左側のログ用ポートを1つに特定できません。左側のUSB接続と診断UF2を確認してください。', file=sys.stderr)
    sys.exit(1)
print(ports[0])
PY
)

printf '左側のログ用ポート: %s\n' "$serial"
if [ "${1:-}" = '--detect-only' ]; then exit 0; fi
output="$HOME/Desktop/keyball-left-usb.log"

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
printf 'ログ取得を開始しました。右側を通電し、30秒待ってMac本体のControl+Cで終了してください。\n'
cat <&3 | tee "$output"
