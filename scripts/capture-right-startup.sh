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

# ログ送信先が接続されたことをUSB CDCへDTRで明示する。
/usr/bin/python3 - "$serial" "$output" <<'PY'
import fcntl
import os
import select
import struct
import sys
import termios

serial, output = sys.argv[1:]
fd = os.open(serial, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
previous = termios.tcgetattr(fd)
received = 0
try:
    config = termios.tcgetattr(fd)
    config[0] = config[1] = config[3] = 0
    config[2] = (config[2] & ~(termios.CSIZE | termios.PARENB | termios.CSTOPB)) | termios.CS8 | termios.CLOCAL | termios.CREAD
    config[4] = config[5] = termios.B115200
    config[6][termios.VMIN] = config[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, config)
    fcntl.ioctl(fd, termios.TIOCMBIS, struct.pack('I', termios.TIOCM_DTR))
    with open(output, 'wb') as log:
        while True:
            ready, _, _ = select.select([fd], [], [], 1)
            if not ready:
                continue
            try:
                data = os.read(fd, 65536)
            except BlockingIOError:
                continue
            if not data:
                continue
            log.write(data)
            log.flush()
            received += len(data)
            sys.stdout.buffer.write(data)
            sys.stdout.buffer.flush()
except KeyboardInterrupt:
    pass
except OSError as error:
    print('\nUSBログの読み取りが終了しました: ' + str(error), file=sys.stderr)
finally:
    try:
        termios.tcsetattr(fd, termios.TCSANOW, previous)
    except OSError:
        pass
    os.close(fd)
    print('\n保存先: {} / 取得バイト数: {}'.format(output, received))
    if received == 0:
        print('ログ取得は未成功です。画面の接続先とエラーを担当AIへ共有してください。')
PY
