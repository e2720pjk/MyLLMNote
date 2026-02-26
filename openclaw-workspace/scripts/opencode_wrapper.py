#!/usr/bin/env python3
"""
OpenCode 執行包裝器 - 使用 pty 模式運行 opencode run

修復輸出問題：使用 os.write 直接寫入 master_fd
"""
import pty
import os
import subprocess
import sys
import select

def run_opencode(message: str, cwd: str = None, output_file: str = None) -> str:
    """使用 pty 模式執行 opencode run"""
    # 建立偽終端主從設備
    master_fd, slave_fd = pty.openpty()

    try:
        # 構建命令
        cmd = ["opencode", "run", message]

        # 執行命令，將 stdin/stdout/stdout 重定向到偽終端
        proc = subprocess.Popen(
            cmd,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            cwd=cwd,
            text=False  # 使用 bytes
        )

        # 關閉 Slave FD（子進程已複製）
        os.close(slave_fd)

        # 讀取輸出
        output = []
        while True:
            # 使用 select 檢查是否有數據可讀
            r, w, x = select.select([master_fd], [], [], 0.1)
            
            if master_fd in r:
                try:
                    # 從 Master FD 讀取
                    data = os.read(master_fd, 4096)
                    if not data:
                        break
                    # 解碼並輸出
                    text = data.decode('utf-8', errors='ignore')
                    output.append(text)
                    # 實時輸出到 stdout
                    sys.stdout.write(text)
                    sys.stdout.flush()
                except OSError:
                    break
            
            # 檢查進程是否結束
            if proc.poll() is not None:
                # 再嘗試讀取一次殘留數據
                try:
                    data = os.read(master_fd, 4096)
                    if data:
                        text = data.decode('utf-8', errors='ignore')
                        output.append(text)
                        sys.stdout.write(text)
                        sys.stdout.flush()
                except OSError:
                    pass
                break

        # 等待進程結束
        proc.wait()
        result = ''.join(output)

        # 如果指定輸出檔案，寫入
        if output_file:
            with open(output_file, 'w') as f:
                f.write(result)

        return result

    finally:
        # 關閉 Master FD
        os.close(master_fd)


if __name__ == "__main__":
    # 用法: python3 opencode_wrapper.py [working_directory]
    #       （訊息從 stdin 讀取）

    # 從 stdin 讀取訊息（支持多行）
    message = sys.stdin.read()

    if not message:
        print("錯誤: 請提供訊息（通過 stdin 或參數）", file=sys.stderr)
        sys.exit(1)

    cwd = sys.argv[1] if len(sys.argv) > 1 else None

    # 執行
    result = run_opencode(message, cwd)
