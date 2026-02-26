# NotebookLM CLI 技術深入分析報告

**詳細研究版** | 2026-02-05 | Sisyphus (OhMyOpenCode)

---

## 文檔說明

本文檔是 NotebookLM CLI 認證機制的**技術深度分析**，補充 `results.md` 摘要版。
重點提供源碼級別的技術細節、實現示例和故障排除指南。

---

## 一、認證機制技術深度分析

### 1.1 Chrome DevTools Protocol (CDP) 實現詳解

#### **WebSocket 連接建立**

```python
# 源碼位置: src/nlm/utils/cdp.py:27-56
# 複製自: https://github.com/jacob-bd/notebooklm-mcp-cli

async def launch_chrome_with_debugging(headless=False, port=9222):
    """
    啟動 Chrome 並開啟遠端除錯端口

    Args:
        headless: 是否無頭模式
        port: 調試端口（默認 9222，衝突時自動掃描 9222-9231）

    Returns:
        subprocess.Process: Chrome 進程對象
    """
    # 構建 Chrome 啟動命令
    chrome_cmd = [
        'google-chrome',  # 或 chromium, chromium-browser
        '--remote-debugging-port', str(port),
        '--remote-allow-origins=*',  # 允許遠程 WebSocket 連接
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-default-apps',
        '--disable-popup-blocking',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
    ]

    if headless:
        chrome_cmd.extend([
            '--headless',
            '--disable-gpu',
            '--no-sandbox'
        ])

    # 使用 Chrome profile 隔離
    profile_path = expanduser('~/.nlm/chrome-profile')
    chrome_cmd.extend(['--user-data-dir', profile_path])

    # 啟動 Chrome
    process = subprocess.Popen(
        chrome_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    # 等待 Chrome 啟動
    await asyncio.sleep(3)

    # 驗證 WebSocket 端點可訪問
    ws_url = f'ws://localhost:{port}/devtools/page'
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f'http://localhost:{port}/json') as resp:
                if resp.status == 200:
                    tabs = await resp.json()
                    if not tabs:
                        raise RuntimeError("Chrome 啟動後無法獲取標籤頁"
    except Exception as e:
        process.terminate()
        raise RuntimeError(f"Chrome 啟動失敗: {e}")

    return process
```

#### **JSON-RPC 通訊協議**

```python
# CDP JSON-RPC 請求/響應格式
# 源碼位置: src/nlm/utils/cdp.py:242-277

async def execute_cdp_command(ws_url, method, params=None, session_id=None):
    """
    執行 CDP 命令

    Args:
        ws_url: WebSocket URL (ws://localhost:9222/devtools/page/...)
        method: CDP 方法名（如 "Network.getCookies"）
        params: 方法參數
        session_id: 目標會話 ID（如有）

    Returns:
        dict: CDP 響應結果

    請求格式:
    {
        "id": 1,
        "method": "Network.getCookies",
        "params": {"urls": ["https://notebooklm.google.com/"]},
        "sessionId": "C54B..."  # 可選
    }

    響應格式:
    {
        "id": 1,
        "result": {
            "cookies": [...]
        }
    }
    """
    # 構建請求
    request = {
        "id": str(uuid.uuid4()),
        "method": method
    }
    if params:
        request["params"] = params
    if session_id:
        request["sessionId"] = session_id

    async with websockets.connect(ws_url) as ws:
        # 發送請求
        await ws.send(json.dumps(request))

        # 接收響應
        response = await ws.recv()
        result = json.loads(response)

        # 檢查錯誤
        if "error" in result:
            raise RuntimeError(f"CDP 錯誤: {result['error']}")

        return result["result"]
```

#### **Cookie 提取完整流程**

```python
# 源碼位置: src/nlm/utils/cdp.py:350-477
# 繁化後的實現

async def extract_cookies_via_cdp(headless=False, profile_name="default"):
    """
    完整的 CDP cookie 提取流程

    1. 啟動 Chrome 並開啟遠端除錯
    2. 導航至 NotebookLM
    3. 等待頁面完全加載
    4. 提取 cookies (CDP Network.getCookies)
    5. 提取 CSRF token (從 HTML)
    6. 提取 Session ID (從 cookies)
    7. 保存至配置檔

    Args:
        headless: 是否無頭模式
        profile_name: 配置檔名稱

    Returns:
        AuthProfile: 包含所有認證信息的對象
    """
    from datetime import datetime

    # === Step 1: 啟動 Chrome ===
    port = await find_available_port(9222, 9231)
    chrome_process = await launch_chrome_with_debugging(headless, port)

    try:
        # === Step 2: 建立 WebSocket 連接 ===
        ws_url = await get_page_websocket_url(port)
        session_id = await get_page_id(port)  # 獲取當前頁面會話 ID

        # === Step 3: 導航至 NotebookLM ===
        notebooklm_url = "https://notebooklm.google.com"
        await execute_cdp_command(
            ws_url, "Page.navigate", {"url": notebooklm_url}
        )

        # 等待頁面加載（等待 network idle）
        await execute_cdp_command(
            ws_url, "Page.loadEventFired", wait=True
        )

        # === Step 4: 提取 Cookies ===
        cookies_result = await execute_cdp_command(
            ws_url, "Network.getCookies",
            {"urls": [notebooklm_url]},
            session_id=session_id
        )
        cookies = cookies_result["cookies"]

        # 轉換為字典格式
        cookie_dict = {c['name']: c['value'] for c in cookies}

        # === Step 5: 提取 CSRF Token (SNlM0e) ===
        html_result = await execute_cdp_command(
            ws_url, "DOM.getDocument", {}, session_id=session_id
        )

        # 獲取 HTML 內容
        html_content = await get_page_html_source(ws_url, session_id)

        # 使用正則表達式提取 CSRF token
        csrf_pattern = r'name="SNlM0e"\s+value="([^"]+)"'
        csrf_match = re.search(csrf_pattern, html_content)
        csrf_token = csrf_match.group(1) if csrf_match else ""

        # === Step 6: 提取 Session ID (FdrFJe) ===
        session_id_cookie = cookie_dict.get("FdrFJe", "")
        session_id = urllib.parse.unquote(session_id_cookie)

        # === Step 7: 構建 AuthProfile ===
        # 獲取登入用戶的 email (從頁面提取或提示用戶)
        email = await extract_user_email(ws_url, session_id)

        profile = AuthProfile(
            name=profile_name,
            cookies=cookie_dict,
            csrf_token=csrf_token,
            session_id=session_id,
            email=email,
            created_at=datetime.utcnow().isoformat() + "Z",
            last_validated=datetime.utcnow().isoformat() + "Z"
        )

        # === Step 8: 驗證認證 ===
        # 嘗試調用 API 驗證 cookie 有效性
        if not await validate_cookies(cookie_dict, csrf_token, session_id):
            raise RuntimeError("Cookie 驗證失敗，請確認已完全登入")

        # === Step 9: 保存到磁盤 ===
        profile_dir = expanduser(f'~/.nlm/profiles/{profile_name}')
        os.makedirs(profile_dir, exist_ok=True)

        profile_path = os.path.join(profile_dir, 'credentials.json')
        with open(profile_path, 'w') as f:
            f.write(profile.to_json())

        print(f"✅ 認證成功保存至: {profile_path}")

        return profile

    finally:
        # 關閉 Chrome
        chrome_process.terminate()
        await chrome_process.wait()
```

---

### 1.2 AuthManager 配置檔管理

```python
# 源碼位置: src/nlm/core/auth.py
# 配置檔管理和序列化/反序列化

from dataclasses import dataclass, asdict
from typing import Dict, Optional
import json
from datetime import datetime

@dataclass
class AuthProfile:
    """
    NotebookLM 認證配置檔數據結構
    """
    name: str
    cookies: Dict[str, str]
    csrf_token: str
    session_id: str
    email: Optional[str] = None
    created_at: Optional[str] = None
    last_validated: Optional[str] = None

    def to_json(self) -> str:
        """序列化為 JSON"""
        return json.dumps(asdict(self), indent=2)

    @classmethod
    def from_json(cls, json_str: str) -> 'AuthProfile':
        """從 JSON 反序列化"""
        data = json.loads(json_str)
        return cls(**data)

    def is_expired(self, minutes: int = 20) -> bool:
        """檢查是否過期（基於 last_validated）"""
        if not self.last_validated:
            return True

        try:
            last_valid = datetime.fromisoformat(self.last_validated)
            now = datetime.utcnow()
            delta = (now - last_valid).total_seconds()
            return delta > (minutes * 60)
        except:
            return True


class AuthManager:
    """
    配置檔管理器
    管理多個 Google 帳號的認證狀態
    """

    def __init__(self, base_path: str = None):
        self.base_path = base_path or expanduser('~/.nlm/profiles')
        os.makedirs(self.base_path, exist_ok=True)

    def save_profile(self, profile: AuthProfile):
        """保存配置檔"""
        profile_dir = os.path.join(self.base_path, profile.name)
        os.makedirs(profile_dir, exist_ok=True)

        profile_path = os.path.join(profile_dir, 'credentials.json')
        with open(profile_path, 'w') as f:
            f.write(profile.to_json())

        # 設置嚴格權限
        os.chmod(profile_path, 0o600)

    def load_profile(self, profile_name: str = "default") -> AuthProfile:
        """加載配置檔"""
        profile_path = os.path.join(
            self.base_path, profile_name, 'credentials.json'
        )

        if not os.path.exists(profile_path):
            raise FileNotFoundError(
                f"配置檔 '{profile_name}' 不存在，請先運行 nlm login"
            )

        with open(profile_path, 'r') as f:
            return AuthProfile.from_json(f.read())

    def list_profiles(self) -> list:
        """列出所有配置檔"""
        profiles = []
        for name in os.listdir(self.base_path):
            profile_path = os.path.join(self.base_path, name, 'credentials.json')
            if os.path.exists(profile_path):
                profile = self.load_profile(name)
                profiles.append({
                    'name': name,
                    'email': profile.email,
                    'created_at': profile.created_at,
                    'last_validated': profile.last_validated
                })

        return profiles

    def delete_profile(self, profile_name: str):
        """刪除配置檔"""
        import shutil
        profile_dir = os.path.join(self.base_path, profile_name)
        if os.path.exists(profile_dir):
            shutil.rmtree(profile_dir)

    def validate_profile(self, profile_name: str = "default") -> bool:
        """驗證配置檔是否仍然有效"""
        try:
            profile = self.load_profile(profile_name)

            # 檢查時間戳
            if profile.is_expired(20):
                return False

            # API 驗證
            return validate_cookies(
                profile.cookies,
                profile.csrf_token,
                profile.session_id
            )
        except:
            return False
```

---

### 1.3 三層恢復機制完整實現

```python
# 源碼位置: src/nlm/core/auth_refresh.py
# 三層恢復机制的完整實現

from typing import Optional
from src.nlm.core.auth import AuthProfile, AuthManager
from src.nlm.utils.cdp import extract_cookies_via_cdp


class AuthRefreshManager:
    """
    NotebookLM 三層認證恢復管理器
    """

    def __init__(self, profile_name: str = "default"):
        self.profile_name = profile_name
        self.auth_manager = AuthManager()
        self.logger = self._setup_logger()

    def _setup_logger(self):
        """設置日誌記錄"""
        import logging
        logging.basicConfig(level=logging.INFO)
        return logging.getLogger(__name__)

    async def refresh_if_needed(self, error: Exception) -> bool:
        """
        根據錯誤觸發恢復

        Args:
            error: HTTP 錯誤 (401/403)

        Returns:
            bool: 恢復是否成功
        """
        # 檢查是否為認證錯誤
        if not self._is_auth_error(error):
            return False

        self.logger.warning("認證錯證錯誤，嘗試恢復...")

        # === Layer 1: CSRF Token 刷新 (最快) ===
        if await self._refresh_csrf_token():
            self.logger.info("✅ Layer 1: CSRF token 刷新成功")
            return True
        self.logger.warning("❌ Layer 1: CSRF token 刷新失敗")

        # === Layer 2: 配置檔重載 (最快) ===
        if await self._reload_profile():
            self.logger.info("✅ Layer 2: 配置檔重載成功")
            return True
        self.logger.warning("❌ Layer 2: 配置檔重載失敗")

        # === Layer 3: Headless Chrome 重新認證 (最慢) ===
        if await self._headless_reauth():
            self.logger.info("✅ Layer 3: Headless 重新認證成功")
            return True
        self.logger.warning("❌ Layer 3: Headless 重新認證失敗")

        # 所有層級都失敗
        self.logger.error(
            "所有恢復層級都失敗，請手動運行 nlm login"
        )
        return False

    def _is_auth_error(self, error: Exception) -> bool:
        """判斷是否為認證錯誤"""
        error_str = str(error).lower()
        return any(keyword in error_str
                   for keyword in ['401', '403', 'unauthorized', 'forbidden'])

    # ========================================
    # Layer 1: CSRF Token 刷新實現
    # ========================================
    async def _refresh_csrf_token(self) -> bool:
        """
        Layer 1: 刷新 CSRF Token

        方法:
        1. 向 notebooklm.google.com 發送 GET 請求
        2. 從 HTML 中解析新的 CSRF token (SNlM0e)
        3. 更新配置檔

        時間: ~1 秒
        成功率: 高（常見場景）
        """
        import aiohttp

        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    'https://notebooklm.google.com/'
                ) as resp:
                    if resp.status != 200:
                        return False

                    html = await resp.text()

                    # 提取新的 CSRF token
                    csrf_pattern = r'name="SNlM0e"\s+value="([^"]+)"'
                    csrf_match = re.search(csrf_pattern, html)
                    new_csrf_token = csrf_match.group(1) if csrf_match else ""

                    if not new_csrf_token:
                        return False

                    # 更新配置檔
                    profile = self.auth_manager.load_profile(self.profile_name)
                    profile.csrf_token = new_csrf_token
                    profile.last_validated = datetime.utcnow().isoformat() + "Z"

                    self.auth_manager.save_profile(profile)

                    return True

        except Exception as e:
            self.logger.error(f"Layer 1 錯誤: {e}")
            return False

    # ========================================
    # Layer 2: 配置檔重載實現
    # ========================================
    async def _reload_profile(self) -> bool:
        """
        Layer 2: 從磁盤重載配置檔

        使用場景:
        - 多個 CLI 實例運行，手動執行 nlm login 更新了配置檔
        - 配置檔在運行過程中被其他進程修改

        時間: 即時
        成功率: 中（條件觸發）
        """
        try:
            # 嘗試從磁盤重新加載
            new_profile = self.auth_manager.load_profile(self.profile_name)

            # 比較時間戳，確實是更新的
            if new_profile.last_validated and (
                datetime.fromisoformat(new_profile.last_validated) >
                datetime.now()
            ):
                # 更新當前使用的 profile
                # (在實際實現中，這會更新 NotebookLMClient 的內部狀態)
                return True

            return False

        except Exception as e:
            self.logger.error(f"Layer 2 錯誤: {e}")
            return False

    # ========================================
    # Layer 3: Headless Chrome 重新認證實現
    # ========================================
    async def _headless_reauth(self) -> bool:
        """
        Layer 3: 使用 Headless Chrome 重新認證

        方法:
        1. 檢查配置檔是否被鎖定（是否有 Chrome 實例正在使用）
        2. 啟動 Chrome (headless=True)，使用保存的 profile
        3. 憑藉保存的登入信息（Chrome 記住用戶帳號），自動完成登入
        4. 提取新的 cookies 和 tokens
        5. 更新配置檔

        前提條件:
        - Chrome profile 必須有保存的 Google 登入信息
        - 配置檔當前未被鎖定

        時間: ~5-10 秒
        成功率: 低（條件依賴）
        """
        try:
            # 檢查配置檔是否被鎖定
            lock_file = os.path.join(
                expanduser('~/.nlm/chrome-profile'),
                'SingletonLock'
            )

            if os.path.exists(lock_file):
                self.logger.warning(
                    "配置檔被鎖定，無法執行 Headless 重新認證。"
                    "請關閉所有 Chrome 視窗後重試。"
                )
                return False

            # 執行 Headless 重新認證
            profile = await extract_cookies_via_cdp(
                headless=True,
                profile_name=self.profile_name
            )

            return True

        except Exception as e:
            self.logger.error(f"Layer 3 錯誤: {e}")
            return False


# 使用示例
async def main():
    manager = AuthRefreshManager(profile_name="default")

    try:
        # 嘗試調用 API（可能會拋出 401 錯誤）
        result = await some_api_call()
        print(result)
    except Exception as e:
        # 觸發恢復
        success = await manager.refresh_if_needed(e)

        if success:
            # 恢復成功，重試
            result = await some_api_call()
            print(result)
        else:
            print("恢復失敗，請手動運行 nlm login")
```

---

## 二、Playwright 集成的技術實現

### 2.1 Playwright 提取 NLM 格式 Cookies

```python
"""
使用 Playwright 為 nlm 準備認證狀態

注意: 仍需首次人工登入，此腳本無法實現完全無人值守
"""

import asyncio
import json
import os
import urllib.parse
from datetime import datetime
from playwright.async_api import async_playwright


async def authenticate_with_playwright():
    """
    使用 Playwright 完成 Google 登入並導出為 nlm 格式

    流程:
    1. 啟動 Chromium（使用指定路徑）
    2. 導航至 NotebookLM
    3. 等待用戶完成 Google 登入
    4. 提取 cookies
    5. 提取 CSRF token 和 session_id
    6. 轉換為 nlm credentials.json 格式
    7. 保存到 ~/.nlm/profiles/default/credentials.json
    """
    async with async_playwright() as p:
        # 1. 啟動 Chromium
        browser = await p.chromium.launch(
            executable_path='/usr/bin/chromium',  # 指定 Chromium 路徑
            headless=False  # 首次需要 visible，人工登入
        )

        # 2. 創建新的上下文（不共享 cookies）
        context = await browser.new_context(
            # 可選: 使用特定 Chrome profile
            # user_data_dir='/path/to/chrome/profile'
        )

        page = await context.new_page()

        # 3. 導航至 NotebookLM
        await page.goto('https://notebooklm.google.com/')

        print("=== 請在瀏覽器中完成 Google 登入 ===")
        print("登入完成後，腳本將自動繼續...")
        print("（您可以關閉此提示，腳本會自動檢測）")

        # 4. 等待登入完成
        # 檢測方法 A: 等待 URL 變化至 NotebookLM 主頁
        try:
            await page.wait_for_url(
                'https://notebooklm.google.com/',
                timeout=120000  # 2 分鐘超時
            )
        except:
            print("⚠️ 未檢測到登入完成，嘗試繼續...")

        # 檢測方法 B: 等待特定元素出現
        try:
            await page.wait_for_selector(
                '[data-test-id="notebook-grid"]',  # NotebookLM 主頁元素
                timeout=30000
            )
            print("✅ 檢測到登入成功")
        except:
            print("⚠️ 無法確認登入登入狀態，嘗試繼續提取 cookies...")

        # 5. 提取 Cookies
        cookies = await context.cookies()
        cookie_dict = {c['name']: c['value'] for c in cookies}

        print(f"提取到 {len(cookies)} 個 cookies")

        # 6. 提取 CSRF Token (SNlM0e)
        csrf_token = await page.evaluate('''() => {
            const input = document.querySelector('input[name="SNlM0e"]');
            return input ? input.value : null;
        }''')

        if not csrf_token:
            print("⚠️ 未能提取 CSRF token，可能頁面結構有變化")

        # 7. 提取 Session ID (FdrFJe)
        session_id_encoded = cookie_dict.get('FdrFJe', '')
        session_id = urllib.parse.unquote(session_id_encoded) if session_id_encoded else ''

        print(f"CSRF Token: {csrf_token[:20]}..." if csrf_token else "CSRF Token: (無)")
        print(f"Session ID: {session_id[:20]}..." if session_id else "Session ID: (無)")

        # 8. 提取 Email 地址
        email = await page.evaluate('''() => {
            // 嘗試多種可能的元素選擇器
            const selectors = [
                '[data-email]',
                '[aria-label*="account"]',
                'title'  // 頁面標題中可能包含 email
            ];

            for (const selector of selectors) {
                const element = document.querySelector(selector);
                if (element) {
                    const email = element.getAttribute('data-email') ||
                                  element.textContent ||
                                  element.getAttribute('aria-label');
                    if (email && email.includes('@')) {
                        return email;
                    }
                }
            }

            // 如果沒找到，提示用戶
            return null;
        }''')

        if not email:
            print("⚠️ 未能自動提取 email，請手動輸入:")
            email = input("請輸入您的 Google 帳號 email: ").strip()

        # 9. 構建 NLM credentials.json 格式
        nlm_creds = {
            "name": "default",
            "cookies": cookie_dict,
            "csrf_token": csrf_token,
            "session_id": session_id,
            "email": email,
            "created_at": datetime.utcnow().isoformat() + "Z",
            "last_validated": datetime.utcnow().isoformat() + "Z"
        }

        # 10. 保存到 ~/.nlm/profiles/default/credentials.json
        profile_dir = os.path.expanduser('~/.nlm/profiles/default')
        os.makedirs(profile_dir, exist_ok=True)

        creds_path = os.path.join(profile_dir, 'credentials.json')
        with open(creds_path, 'w') as f:
            json.dump(nlm_creds, f, indent=2)

        # 設置權限
        os.chmod(creds_path, 0o600)

        print(f"\n{'='*60}")
        print(f"✅ 認證數據已保存至: {creds_path}")
        print(f"{'='*60}")
        print(f"\n您現在可以使用 nlm CLI:")
        print(f"  nlm notebook list")
        print(f"  nlm login --check")
        print(f"\n注意: Cookie 有效期約 2-4 週")
        print(f"過期後需要重新執行此腳本")

        await browser.close()


# 運行腳本
if __name__ == '__main__':
    asyncio.run(authenticate_with_playwright())
```

---

### 2.2 從 NLM 格式轉換為 Playwright storageState

```python
"""
將 nlm credentials.json 轉換為 Playwright storageState 格式

使用場景:
- 您已使用 nlm login 認證過
- 想使用 Playwright 已認證的瀏覽器環境
- 無需重新登入
"""

import json
import os
import urllib.parse


def nlm_to_playwright_storage_state(
    nlm_creds_path: str,
    output_path: str = 'playwright-storage-state.json'
):
    """
    轉換 NLM credentials.json 為 Playwright 格式

    Args:
        nlm_creds_path: nlm credentials.json 文件路徑
        output_path: 輸出文件路徑

    Input (NLM format):
    {
        "name": "default",
        "cookies": {"SID": "...", "SAPISID": "..."},
        "csrf_token": "AOEOulZm8x...",
        "session_id": "1234567890",
        "email": "user@gmail.com",
        ...
    }

    Output (Playwright format):
    {
        "cookies": [...],
        "origins": [...]
    }
    """
    # 讀取 NLM credentials
    with open(nlm_creds_path, 'r') as f:
        nlm_creds = json.load(f)

    # 轉換 cookies
    playwright_cookies = []
    for name, value in nlm_creds['cookies'].items():
        playwright_cookies.append({
            "name": name,
            "value": value,
            "domain": ".google.com",
            "path": "/",
            "expires": -1,  -1  # Session cookie
            "httpOnly": True,
            "secure": True,
            "sameSite": "None" if name.startswith("__Secure-") else "Lax"
        })

    # 構建 storageState
    storage_state = {
        "cookies": playwright_cookies,
        "origins": [
            {
                "origin": "https://notebooklm.google.com",
                "localStorage": []
            }
        ]
    }

    # 保存
    with open(output_path, 'w') as f:
        json.dump(storage_state, f, indent=2)

    print(f"✅ Playwright storageState 已保存: {output_path}")
    return storage_state


# 使用示例
if __name__ == '__main__':
    nlm_creds_path = os.path.expanduser('~/.nlm/profiles/default/credentials.json')
    nlm_to_playwright_storage_state(nlm_creds_path)
```

---

### 2.3 使用 saved storageState 運行 Playwright

```python
"""
使用從 nlm 轉換的 storageState 運行 Playwright

無需重新登入，直接使用已認證的環境
"""

import asyncio
from playwright.async_api import async_playwright


async def use_saved_auth():
    """
    使用已保存的 storageState 載入認證狀態
    """
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)

        # 載入已保存的認證狀態
        context = await browser.new_context(
            storage_state='playwright-storage-state.json'
        )

        page = await context.new_page()

        # 直接訪問，應該已經登入
        await page.goto('https://notebooklm.google.com/')

        # 檢查是否登入成功
        await page.wait_for_selector('[data-test-id="notebook-grid"]')
        print("✅ 已成功使用已保存的認證狀態")

        # 執行其他操作...
        # await page.click(...)
        # await page.screenshot(...)

        await browser.close()


# 運行
if __name__ == '__main__':
    asyncio.run(use_saved_auth())
```

---

## 三、CI/CD 環境完整配置

### 3.1 GitHub Actions 完整工作流

```yaml
# .github/workflows/notebooklm-automation.yml
name: NotebookLM Automation

on:
  workflow_dispatch:  # 手動觸發
  schedule:
    - cron: '0 9 * * *'  # 每天 9:00 UTC
  push:
    branches: [main]

jobs:
  notebooklm:
    name: Generate NotebookLM Content
    runs-on: ubuntu-latest

    # 環境變量
    env:
      NOTEBOOKLM_COOKIES: ${{ secrets.NOTEBOOKLM_COOKIES }}
      NOTEBOOK_ID: ${{ secrets.NOTEBOOK_ID }}

    steps:
      # ========================================
      # Phase 1: 環境設置
      # ========================================

      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
          cache: 'pip'

      - name: Install dependencies
        run: |
          pip install notebooklm-mcp-cli
          pip install aiohttp requests

      # ========================================
      # Phase 2: Chrome 環境
      # ========================================

      - name: Install Chromium
        run: |
          sudo apt-get update
          sudo apt-get install -y chromium-browser

      - name: Verify Chromium installation
        run: |
          which chromium-browser
          chromium-browser --version

      # ========================================
      # Phase 3: 認證恢复
      # ========================================

      - name: Create NLTM profile directory
        run: |
          mkdir -p ~/.nlm/profiles/default

      - name: Restore authentication from secrets
        env:
          NOTEBOOKLM_COOKIES: ${{ secrets.NOTEBOOKLM_COOKIES }}
        run: |
          # 從 secrets 恢復 cookies.json
          echo "$NOTEBOOKLM_COOKIES" > ~/.nlm/profiles/default/credentials.json

          # 設置權限
          chmod 600 ~/.nlm/profiles/default/credentials.json

          # 驗證格式
          python3 -m json.tool ~/.nlm/profiles/default/credentials.json

      - name: Check authentication
        run: |
          # 驗證認證是否有效
          nlm login --check

          # 列出可用的 notebooks
          nlm notebook list

      # ========================================
      # Phase 4: 主要工作
      # ========================================

      - name: Generate audio podcast
        run: |
          # 獲取 notebook ID（可從 secrets 或運行時參數）
          NOTEBOOK_ID=${NOTEBOOK_ID:-$(nlm notebook list --quiet | head -1)}

          # 生成 podcast（使用 --confirm 自動確認）
          nlm audio create "$NOTEBOOK_ID" --confirm

      - name: Download generated audio
        run: |
          NOTEBOOK_ID=${NOTEBOOK_ID:-$(nlm notebook list --quiet | head -1)}

          # 獲取 artifact ID
          ARTIFACT_ID=$(nlm studio status "$NOTEBOOK_ID" --json | \
            jq -r '.[0].id' 2>/dev/null || echo "")

          if [ -n "$ARTIFACT_ID" ]; then
            # 下載音頻
            nlm download audio "$NOTEBOOK_ID" "$ARTIFACT_ID"

            # 上傳到 GitHub artifacts（可選）
            echo "Audio generated: $ARTIFACT_ID"
          else
            echo "No audio artifact found or generation in progress"
          fi

      # ========================================
      # Phase 5: 輸出和日誌
      # ========================================

      - name: Display studio status
        if: always()
        run: |
          NOTEBOOK_ID=${NOTEBOOK_ID:-$(nlm notebook list --quiet | head -1)}
          nlm studio status "$NOTEBOOK_ID"

      - name: Upload artifacts (optional)
        if: success()
        uses: actions/upload-artifact@v3
        with:
          name: notebooklm-audio
          path: |
            *.mp3
            *.wav
          retention-days: 7

      # ========================================
      # Phase 6: 錯誤處理
      # ========================================

      - name: Handle authentication failure
        if: failure()
        run: |
          echo "❌ 工作流失敗，可能原因:"
          echo "   1. Cookies 過期 (每 2-4 週需要更新)"
          echo "   2. Notebook ID 錯誤"
          echo "   3. NotebookLM API 限流"
          echo ""
          echo "建議操作:"
          echo "   1. 本地運行: nlm login"
          echo "   2. 更新 GitHub Secrets: NOTEBOOKLM_COOKIES"
          echo "   3. 重新觸發工作流"

      - name: Send notification (optional)
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'NotebookLM automation workflow failed'
          webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

### 3.2 Docker 容器化部署

```dockerfile
# Dockerfile
FROM python:3.11-slim

# 安裝系统依賴
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-thai-tlwg \
    fonts-kacst \
    fonts-freefont-ttf \
    libxss1 \
    \
    && rm -rf /var/lib/apt/lists/*

# 安裝 Python 依賴
RUN pip install --no-cache-dir \
    notebooklm-mcp-cli \
    aiohttp \
    requests

# 創建工作目錄
WORKDIR /app

# 設置環境變量
ENV NLM_PROFILE_PATH=/app/data

# 暴露端口（如需要）
# EXPOSE 8000

# 複製腳本
COPY requirements.txt .
COPY main.py .

# 預設命令
CMD ["python", "main.py"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  notebooklm-worker:
    build: .
    container_name: notebooklm-worker
    restart: unless-stopped

    volumes:
      - ./data:/app/data  # 持久化認證數據

    environment:
      - NLM_PROFILE_PATH=/app/data
      - NOTEBOOK_ID=${NOTEBOOK_ID}

    # 定期任務設置 (cron)
    # command: >
    #   /bin/bash -c "
    #     while true; do
    #       echo 'Running NotebookLM task...'
    #       python main.py
    #       echo 'Next run in 24 hours...'
    #       sleep 86400
    #     done
    #   "
```

```python
# main.py
"""
Docker 容器中的 NotebookLM 自動化腳本
"""

import os
import sys
import time
import asyncio
import aiohttp
from pathlib import Path

# 環境變量
NOTEBOOK_ID = os.environ.get('NOTEBOOK_ID')
PROFILE_PATH = os.environ.get('NLM_PROFILE_PATH', '/app/data')


def setup_environment():
    """設置環境"""
    # 確保數據目錄存在
    Path(PROFILE_PATH).mkdir(parents=True, exist_ok=True)

    # 檢查認證文件
    creds_path = Path(PROFILE_PATH) / 'profiles' / 'default' / 'credentials.json'

    if not creds_path.exists():
        print(f"❌ 認證文件不存在: {creds_path}")
        print("請先運行: docker-compose exec notebooklm-worker nlm login")
        sys.exit(1)

    print(f"✅ 認證文件存在: {creds_path}")


async def check_authentication():
    """檢查認證狀態"""
    import subprocess

    result = subprocess.run(
        ['nlm', 'login', '--check'],
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        print("✅ 認證有效")
        return True
    else:
        print("❌ 認證失敗")
        print(result.stderr)
        return False


async def generate_audio():
    """生成音頻 podcast"""
    import subprocess

    if not NOTEBOOK_ID:
        print("❌ NOTEBOOK_ID 環境變量未設置")
        # 嘗試獲取第一個 notebook
        result = subprocess.run(
            ['nlm', 'notebook', 'list', '--quiet'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            NOTEBOOK_ID = result.stdout.strip().split('\n')[0]
            print(f"使用 Notebook ID: {NOTEBOOK_ID}")
        else:
            print("無法獲取 Notebook ID")
            return False

    # 生成音頻
    result = subprocess.run(
        ['nlm', 'audio', 'create', NOTEBOOK_ID, '--confirm'],
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        print("✅ 音頻生成任務已提交")
        print(result.stdout)
        return True
    else:
        print("❌ 音頻生成失敗")
        print(result.stderr)
        return False


async def main():
    """主函數"""
    print("=" * 60)
    print("NotebookLM Automation Worker")
    print("=" * 60)

    # 1. 設置環境
    setup_environment()

    # 2. 檢查認證
    if not await check_authentication():
        print("認證失敗，請更新認證文件")
        sys.exit(1)

    # 3. 執行任務
    success = await generate_audio()

    # 4. 結果
    if success:
        print("\n✅ 任務完成")
        sys.exit(0)
    else:
        print("\n❌ 任務失敗")
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())
```

---

### 3.3 Kubernetes 部署配置

```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: notebooklm-config
data:
  NOTEBOOK_ID: "your-notebook-id"
  NLM_PROFILE_PATH: "/data"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: notebooklm-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notebooklm-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notebooklm-worker
  template:
    metadata:
      labels:
        app: notebooklm-worker
    spec:
      containers:
      - name: worker
        image: your-registry/notebooklm-worker:latest
        envFrom:
          - configMapRef:
              name: notebooklm-config
          - secretRef:
              name: notebooklm-secrets
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: notebooklm-data
```

```yaml
# k8s/cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: notebooklm-daily-job
spec:
  schedule: "0 9 * * *"  # 每天 9:00
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: worker
            image: your-registry/notebooklm-worker:latest
            envFrom:
              - configMapRef:
                  name: notebooklm-config
              - secretRef:
                  name: notebooklm-secrets
            volumeMounts:
            - name: data
              mountPath: /data
            restartPolicy: OnFailure
          volumes:
          - name: data
            persistentVolumeClaim:
              claimName: notebooklm-data
```

---

## 四、故障排除詳解

### 4.1 常見錯誤診斷

#### **錯誤: Port 9222 already in use**

```bash
# 問題描述
# Error: Port 9222 is already in use. Chrome may be running with debugging enabled.

# 解決方案 1: 殺死所有 Chrome 進程
pkill -9 chrome
pkill -9 chromium

# 解決方案 2: 殺死占用 9222 端口的進程
lsof -ti:9222 | xargs kill -9

# 解決方案 3: CLI 自動處理（v0.1.6+ 已修復）
# nlm 會自動掃描 9222-9231 端口，找到可用端口

# 手動指定端口（如果需要）
nlm login --port 9223
```

#### **錯誤: 401 Unauthorized**

```bash
# 問題描述
# Error: 401 Unauthorized | Authentication failed

# 診斷步驟
# 1. 檢查認證狀態
nlm login --check

# 2. 檢查配置檔時間戳
cat ~/.nlm/profiles/default/credentials.json | jq '.last_validated'

# 3. 檢查 cookies 是否過期（> 14 天?）
python3 << 'EOF'
import json
from datetime import datetime

creds_path = os.path.expanduser('~/.nlm/profiles/default/credentials.json')

with open(creds_path) as f:
    creds = json.load(f)

if creds.get('created_at'):
    created = datetime.fromisoformat(creds['created_at'].replace('Z', '+00:00'))
    now = datetime.now(created.tzinfo)
    delta = (now - created).days

    print(f"Credentials 年龄: {delta} 天")
    if delta > 14:
        print("⚠️ Cookies 可能已過期 (> 14 天)")
    else:
        print("✅ Cookies 似乎是新的")
else:
    print("⚠️ 無created_at字段，配置檔可能不正確")
EOF

# 解決方案: 重新登入
nlm login

# 如果仍然失敗，嘗試:
# 1. 刪除舊配置檔
nml auth delete default --confirm
# 2. 重新登入
nlm login
```

---

### 4.2 Debug 模式

```bash
# 啟用詳細日誌
# 方法 1: 環境變量
export NLM_DEBUG=1
export NLM_LOG_LEVEL=DEBUG

# 方法 2: CLI 標誌
nlm notebook list --verbose

# 方法 3: Python 腳本中
import logging
logging.basicConfig(level=logging.DEBUG)

# 查看 Chrome CDP 日誌
# Chrome 的 stdout/stderr 會被 nlm 捕獲並輸出
nlm login 2>&1 | tee nlm-debug.log

# 然後檢查 nlm-debug.log 中的 CDP 命令
grep "CDP command" nlm-debug.log
grep "Network.getCookies" nlm-debug.log
```

---

### 4.3 手動 Cookie 驗證

```python
"""
手動驗證 cookies 是否仍然有效
"""

import aiohttp
import json
import os
from urllib.parse import urlencode


async def validate_cookies():
    """驗證 cookies"""
    creds_path = os.path.expanduser('~/.nlm/profiles/default/credentials.json')

    with open(creds_path) as f:
        creds = json.load(f)

    cookies = creds['cookies']
    csrf_token = creds['csrf_token']
    session_id = creds['session_id']

    # 構建請求頭
    headers = {
        'X-Same-Domain': '1',
        'x-goog-authuser': '0',
    }

    try:
        async with aiohttp.ClientSession(cookies=cookies, headers=headers) as session:
            # 嘗試獲取 notebooks
            url = 'https://notebooklm.google.com/notebook/ListNotebooks'
            params = {
                'f.sid': f'{cookies["SID"]}|{cookies["SAPISID"]}|{session_id}',
                'bl': 'boq_assistant-noteboox-backend_20250123.14_p0',
                '_reqid': '1',
                'rt': 'c',
            }

            async with session.get(url, params=params) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    print("✅ Cookies 仍然有效")
                    print(f"找到 {len(data.data)} 個 notebooks")
                    return True
                else:
                    print(f"❌ 驗證失敗: HTTP {resp.status}")
                    text = await resp.text()
                    print(f"響應: {text}")
                    return False

    except Exception as e:
        print(f"❌ 驗證錯誤: {e}")
        return False


# 運行
if __name__ == '__main__':
    import asyncio
    asyncio.run(validate_cookies())
```

---

## 五、安全最佳實踐

### 5.1 Cookie 加密存儲

```python
"""
使用加密方式存儲 cookies

注意: nlm CLI 不內建此功能，但您可以擴展
"""

import os
import json
from cryptography.fernet import Fernet
from getpass import getpass


def generate_key():
    """生成加密密鑰"""
    return Fernet.generate_key()


def encrypt_cookies(cookies: dict, key: bytes) -> bytes:
    """加密 cookies"""
    f = Fernet(key)
    json_str = json.dumps(cookies)
    return f.encrypt(json_str.encode())


def decrypt_cookies(encrypted_data: bytes, key: bytes) -> dict:
    """解密 cookies"""
    f = Fernet(key)
    decrypted = f.decrypt(encrypted_data)
    return json.loads(decrypted.decode())


# 使用示例
key = getpass("輸入加密密鑰: ").encode()

cookies = {
    "SID": "...",
    "SAPISID": "...",
}

encrypted = encrypt_cookies(cookies, key)
# 保存 encrypted 到文件...

decrypted = decrypt_cookies(encrypted, key)
print(decrypted)
```

---

### 5.2 權限審計腳本

```bash
#!/bin/bash
# audit-nlmt-credentials.sh
# 審計 nlm 認證文件權限

echo "=== NLM 認證權限審計 ==="
echo ""

# 檢查目錄權限
echo "1. 檢查 .nlm 目錄權限:"
ls -ld ~/.nlm/

echo ""
echo "2. 檢查配置檔目錄權限:"
for profile in ~/.nlm/profiles/*/; do
    echo "  $(basename $profile):"
    ls -ld "$profile"
    ls -l "$profile/credentials.json" 2>/dev/null && echo "    ✅ credentials.json 存在" || echo "    ⚠️  無 credentials.json"
done

echo ""
echo "3. 檢查文件內容是否包含敏感信息:"
if grep -r "password\|secret\|token" ~/.nlm/profiles/*/ 2>/dev/null; then
    echo "    ⚠️  發現潛在敏感關鍵詞"
else
    echo "    ✅ 無明顯敏感關鍵詞"
fi

echo ""
echo "4. 檢查是否添加到 .gitignore:"
if grep -q "^\.nlm/" .gitignore 2>/dev/null; then
    echo "    ✅ .nlm/ 已添加到 .gitignore"
else
    echo "    ⚠️  .nlm/ 未添加到 .gitignore"
fi

echo ""
echo "=== 審計完成 ==="
```

---

## 六、參考資料和附加資源

### 6.1 相關文檔

- **Chrome DevTools Protocol**: https://chromedevtools.github.io/devtools-protocol/
- **JSON-RPC 規範**: https://www.jsonrpc.org/specification
- **CDP WebSocket**: https://chromedevtools.github.io/devtools-protocol/tot/Target/
- **Playwright Authentication**: https://playwright.dev/python/docs/auth
- **aiohttp 文檔**: https://docs.aiohttp.org/

### 6.2 社區資源

- **notebooklm-mcp-cli GitHub**: https://github.com/jacob-bd/notebooklm-mcp-cli
- **notebooklm-cli Issues**: https://github.com/jacob-bd/notebooklm-mcp-cli/issues
- **Stack Overflow**: 搜索 "notebooklm-cli" 或 "nlm login"
- **Discord/Reddit 社區**: NotebookLM 用戶社群

### 6.3 工具和依賴

- **Python 套件**:
  - notebooklm-mcp-cli
  - aiohttp
  - playwright
  - cryptography (可選，加密)

- **系統工具**:
  - chromium-browser
  - jq (JSON 處理)
  - lsof (端口佔用檢查)

---

**文檔版本**: 1.0
**最後更新**: 2026-02-05
**作者**: Sisyphus (OhMyOpenCode AI Agent)
**用途**: NotebookLM CLI 技術深度分析和實施指南
