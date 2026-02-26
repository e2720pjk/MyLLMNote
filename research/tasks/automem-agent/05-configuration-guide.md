# 記憶管理 Agent 配置指南

本指南說明如何設定和使用記憶管理 Agent（記憶圖書館員）。

---

## 1. 前置要求

### 1.1 系統需求

| 項目 | 需求 |
|------|------|
| 操作系統 | Linux (Ubuntu 20.04+) / macOS |
| Docker | 20.10+ |
| Docker Compose | 2.0+ |
| Node.js | 18.0+ (如需執行 Skills) |
| OpenClaw Gateway | 最新版本 |

### 1.2 軟體安裝

```bash
# 安裝 Docker (Ubuntu)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安裝 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

---

## 2. Automem 服務部署

### 2.1 取得 Automem

```bash
# 克隆 Automem 倉庫 (假設位置)
git clone https://github.com/[organization]/automem.git
cd automem
```

### 2.2 Docker Compose 配置

創建 `docker-compose.yml`:

```yaml
version: '3.8'

services:
  # Qdrant 向量資料庫
  qdrant:
    image: qdrant/qdrant:latest
    ports:
      - "6333:6333"
    volumes:
      - qdrant_data:/qdrant/storage
    environment:
      - QDRANT__SERVICE__GRPC_PORT=6334

  # FalkorDB 圖譜資料庫
  falkordb:
    image: falkordb/falkordb:latest
    ports:
      - "6379:6379"
    volumes:
      - falkordb_data:/data

  # Automem 服務
  automem:
    image: automem:latest
    # 或使用本地構建
    # build: .
    ports:
      - "8080:8080"
    environment:
      # 資料庫連接
      - AUTOMEM_VECTOR_DB_URL=http://qdrant:6333
      - AUTOMEM_GRAPH_DB_URL=redis://falkordb:6379
      - AUTOMEM_GRAPH_DB_TYPE=falkordb

      # 向量嵌入模型
      - AUTOMEM_EMBEDDING_MODEL=all-MiniLM-L6-v2
      - AUTOMEM_EMBEDDING_DIMENSION=384

      # 記憶配置
      - AUTOMEM_BASE_DECAY_RATE=0.0  # 代碼記憶不衰退
      - AUTOMEM_CLUSTERS_ENABLED=true
      - AUTOMEM_CONSOLIDATION_ENABLED=true

      # API 配置
      - AUTOMEM_API_KEY=${AUTOMEM_API_KEY:-your-api-key}
      - AUTOMEM_CORS_ORIGIN=*

      # 日誌
      - AUTOMEM_LOG_LEVEL=INFO
    depends_on:
      - qdrant
      - falkordb
    volumes:
      - automem_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # 可選: Automem Web UI
  automem-ui:
    image: automem-ui:latest
    ports:
      - "3000:3000"
    environment:
      - AUTOMEM_API_URL=http://automem:8080
      - AUTOMEM_API_KEY=${AUTOMEM_API_KEY:-your-api-key}
    depends_on:
      - automem

volumes:
  qdrant_data:
  falkordb_data:
  automem_data:
```

### 2.3 啟動服務

```bash
# 生成 API Key
export AUTOMEM_API_KEY=$(openssl rand -hex 32)

# 啟動服務
docker-compose up -d

# 查看日誌
docker-compose logs -f automem

# 檢查服務健康狀態
curl http://localhost:8080/health
```

### 2.4 驗證部署

```bash
# 檢查版本
curl http://localhost:8080/api/v1/version

# 測試保存記憶
curl -X POST http://localhost:8080/api/v1/memories \
  -H "Authorization: Bearer $AUTOMEM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "這是一個測試記憶",
    "category": "test",
    "scope": "global"
  }'
```

---

## 3. OpenClaw Agent 配置

### 3.1 創建技能目錄

```bash
mkdir -p ~/.openclaw/skills/memory-manager
cd ~/.openclaw/skills/memory-manager
```

### 3.2 複製 Skills 文件

將 `03-skills-implementation.md` 中的程式碼保存為：

```
~/.openclaw/skills/memory-manager/
├── memory-read.js
├── memory-save.js
├── memory-update.js
└── memory-analyze.js
```

### 3.3 創建 Agent 配置

創建 `~/.openclaw/agents/memory-manager/config.json`:

```json
{
  "name": "Memory Manager",
  "role": "記憶管理 Agent（圖書館員）",
  "description": "專門負責檢索、保存和管理記憶的 Agent。像圖書館員一樣幫助用戶找到相關資憶。",
  "version": "1.0.0",

  "skills": [
    {
      "name": "memory_read",
      "file": "~/.openclaw/skills/memory-manager/memory-read.js",
      "description": "從 Automem 檢索相關記憶",
      "enabled": true
    },
    {
      "name": "memory_save",
      "file": "~/.openclaw/skills/memory-manager/memory-save.js",
      "description": "將資訊保存到 Automem",
      "enabled": true
    },
    {
      "name": "memory_update",
      "file": "~/.openclaw/skills/memory-manager/memory-update.js",
      "description": "更新現有記憶",
      "enabled": true
    },
    {
      "name": "memory_analyze",
      "file": "~/.openclaw/skills/memory-manager/memory-analyze.js",
      "description": "分析記憶模式、聚類或時間線",
      "enabled": true
    }
  ],

  "system_prompt": "你是記憶管理 Agent（圖書館員）。你的職責是幫助用戶查詢和管理記憶。\n\n使用原則：\n1. 當用戶詢問過去的信息時，使用 memory_read\n2. 當用戶要求記住重要事項時，使用 memory_save\n3. 當需要修正或更新記憶時，使用 memory_update\n4. 當需要查看記憶模式或時間線時，使用 memory_analyze\n\n注意事項：\n- 只保存重要的、長期有價值的信息\n- 不要保存臨時的對話上下文\n- 記憶應該清晰、簡潔、獨立\n- 對敏感信息要謹慎處理",

  "automem_config": {
    "url": "http://localhost:8080",
    "api_key": "${AUTOMEM_API_KEY}",
    "default_scope": "project",
    "max_results": 10,
    "request_timeout": 5000
  },

  "behavior": {
    "auto_save": {
      "enabled": false,
      "threshold": 0.8  # 重要性閾值
    },
    "auto_update": {
      "enabled": false
    },
    "fallback_to_local": true
  },

  "integration": {
    "codewiki": {
      "sync_enabled": true,
      "sync_interval": "1h",
      "summary_categories": ["module", "architecture", "documentation"]
    },
    "notedb": {
      "sync_enabled": true,
      "sync_interval": "2h"
    },
    "daily_notes": {
      "auto_summarize": true,
      "summarize_time": "23:00"
    }
  }
}
```

### 3.4 設定環境變數

```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
export AUTOMEM_URL=http://localhost:8080
export AUTOMEM_API_KEY=your-api-key-here

# 重新載入
source ~/.bashrc
```

---

## 4. OpenClaw Gateway 整合

### 4.1 註冊 Agent

如果 OpenClaw 支持動態 Agent 註冊：

```bash
# 使用 CLI 注冊
openclaw agent add \
  --name "memory-manager" \
  --config ~/.openclaw/agents/memory-manager/config.json
```

### 4.2 檢查 Agent 狀態

```bash
# 列出所有 Agents
openclaw agent list

# 檢查 Memory Manager 狀態
openclaw agent status memory-manager
```

### 4.3 測試 Agent

```bash
# 透過 Telegram 或 Web 介面測試
openclaw message send \
  --channel memory-manager \
  "幫我檢查是否有關於 PostgreSQL 的記憶"
```

---

## 5. MCP Server 模式 (可選)

### 5.1 註冊 Automem 為 MCP Server

如果 Automem 支援 MCP 協議：

```bash
# 添加 MCP Server
opencode mcp add automem \
  --command "automem-mcp-server" \
  --args "--port 8080" \
  --env "AUTOMEM_API_KEY=$AUTOMEM_API_KEY"

# 驗證 MCP Server
opencode mcp list
opencode mcp test automem
```

### 5.2 在 OpenCode 中使用

```bash
# 啟動 OpenCode 並使用 Automem
opencode run "使用 automem 查詢關於架構的記憶"
```

---

## 6. 與 MyLLMNote 整合

### 6.1 CodeWiki 整合

#### 6.1.1 創建同步腳本

創建 `~/MyLLMNote/scripts/codewiki-memory-sync.sh`:

```bash
#!/bin/bash

AUTOMEM_URL="${AUTOMEM_URL:-http://localhost:8080}"
AUTOMEM_API_KEY="${AUTOMEM_API_KEY}"
CODEWIKI_DIR="$HOME/MyLLMNote/CodeWiki"

# 讀取 CodeWiki 摘要並同步到 Automem
for summary in $(find "$CODEWIKI_DIR" -name "*.json" -path "*/summaries/*"); do
  echo "同步: $summary"

  curl -X POST "$AUTOMEM_URL/api/v1/memories" \
    -H "Authorization: Bearer $AUTOMEM_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(cat "$summary" | \
      jq '. | {
        content: .summary,
        category: "codewiki",
        scope: "project",
        protected: true,
        importance: 0.7,
        metadata: {
          source_file: .file,
          module: .module
        }
      }')"
done
```

#### 6.1.2 設定 Cron 任務

```bash
# 每小時同步一次
crontab -e

# 添加以下行
0 * * * * $HOME/MyLLMNote/scripts/codewiki-memory-sync.sh >> /var/log/codewiki-memory-sync.log 2>&1
```

### 6.2 NoteDB 整合

#### 6.2.1 Webhook 集成

在 NoteDB 中配置 Webhook，當筆記更新時發送到 Automem：

```javascript
// NoteDB Webhook 處理程序
const express = require('express');
const axios = require('axios');

const app = express();
app.use(express.json());

app.post('/webhook/notedb', async (req, res) => {
  const { action, note } = req.body;

  if (action === 'note_updated' && note.tags.includes('important')) {
    // 同步重要筆記到 Automem
    await axios.post(`${process.env.AUTOMEM_URL}/api/v1/memories`, {
      content: note.summary || note.content.substring(0, 500),
      category: 'notedb',
      scope: 'project',
      metadata: {
        note_id: note.id,
        tags: note.tags
      }
    }, {
      headers: {
        'Authorization': `Bearer ${process.env.AUTOMEM_API_KEY}`,
        'Content-Type': 'application/json'
      }
    });
  }

  res.status(200).send('OK');
});

app.listen(3001, () => {
  console.log('NoteDB webhook listening on port 3001');
});
```

### 6.3 Daily Notes 自動摘要

創建腳本 `~/MyLLMNote/scripts/daily-note-summary.sh`:

```bash
#!/bin/bash

TODAY=$(date +%Y-%m-%d)
NOTES_FILE="$HOME/.openclaw/workspace/memory/$TODAY.md"

if [ -f "$NOTES_FILE" ]; then
  # 使用 LLM 生成摘要
  SUMMARY=$(opencode run "請用繁體中文總結以下每日筆記的重點（最多 200 字）:\n$(cat "$NOTES_FILE")")

  # 保存摘要到 Automem
  curl -X POST "$AUTOMEM_URL/api/v1/memories" \
    -H "Authorization: Bearer $AUTOMEM_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"content\": \"$SUMMARY\",
      \"category\": \"daily-note\",
      \"scope\": \"project\",
      \"protected\": false,
      \"importance\": 0.4
    }"
fi
```

---

## 7. 配置驗證

### 7.1 基礎測試

```bash
# 測試 1: 保存記憶
curl -X POST http://localhost:8080/api/v1/memories \
  -H "Authorization: Bearer $AUTOMEM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content": "測試記憶", "category": "test", "scope": "global"}'

# 測試 2: 查詢記憶
curl -X POST http://localhost:8080/api/v1/query \
  -H "Authorization: Bearer $AUTOMEM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "測試", "limit": 5}'

# 測試 3: OpenClaw Agent 測試
openclaw message send \
  --channel memory-manager \
  "請幫我保存：我喜歡使用 Vim 作為編輯器"
```

### 7.2 整合測試

```bash
# 測試 CodeWiki 同步
$HOME/MyLLMNote/scripts/codewiki-memory-sync.sh

# 測試 Daily Note 摘要
$HOME/MyLLMNote/scripts/daily-note-summary.sh

# 驗證記憶是否正確保存
curl -X POST http://localhost:8080/api/v1/query \
  -H "Authorization: Bearer $AUTOMEM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "CodeWiki", "category": "codewiki", "limit": 10}'
```

---

## 8. 監控和維護

### 8.1 健康檢查

創建 `~/MyLLMNote/scripts/health-check.sh`:

```bash
#!/bin/bash

AUTOMEM_URL="${AUTOMEM_URL:-http://localhost:8080}"

# 檢查 Automem 服務
if curl -f "$AUTOMEM_URL/health" > /dev/null 2>&1; then
  echo "[OK] Automem service is running"
else
  echo "[ERROR] Automem service is down" >&2
  exit 1
fi

# 檢查記憶數量
MEMORY_COUNT=$(curl -s "$AUTOMEM_URL/api/v1/stats" | jq '.total_memories')
echo "[INFO] Total memories: $MEMORY_COUNT"

# 檢查記憶大小
MEMORY_SIZE=$(curl -s "$AUTOMEM_URL/api/v1/stats" | jq '.storage_size_mb')
echo "[INFO] Storage size: $MEMORY_SIZE MB"
```

### 8.2 定期維護

```bash
# 每月執行記憶壓縮 (如果 Automem 支援)
0 0 1 * * curl -X POST http://localhost:8080/api/v1/maintenance/consolidate \
  -H "Authorization: Bearer $AUTOMEM_API_KEY"

# 每週清理過期記憶
0 0 * * 0 curl -X POST http://localhost:8080/api/v1/maintenance/cleanup \
  -H "Authorization: Bearer $AUTOMEM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"days": 90, "importance_threshold": 0.3}'
```

---

## 9. 故障排除

### 9.1 常見問題

| 問題 | 可能原因 | 解決方案 |
|------|----------|----------|
| Automem 服務無法啟動 | 資料庫連接失敗 | 檢查 `docker-compose logs`，確認 Qdrant 和 FalkorDB 正常運行 |
| 查詢返回空結果 | 索引未建立 | 等待 Automem 完成初始化，或手動重建索引 |
| Skills 執行失敗 | API Key 無效 | 檢查 `AUTOMEM_API_KEY` 環境變數 |
| 記憶同步失敗 | 網路超時 | 增加請求超時時間，檢查服務狀態 |

### 9.2 Debug 日誌

```bash
# 查看 Automem 日誌
docker-compose logs -f automem

# 查看 OpenClaw 日誌
tail -f ~/.openclaw/logs/agent.log

# 启用詳細日誌
export AUTOMEM_LOG_LEVEL=DEBUG
docker-compose restart automem
```

---

## 10. 參考資源

- [Automem GitHub Repository](https://github.com/[organization]/automem) (待確認)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [FalkorDB Documentation](https://www.falkordb.com/)
- [OpenClaw Gateway Documentation](https://docs.openclaw.ai/)
- [MCP Protocol](https://modelcontextprotocol.io/)

---

## 11. 下一步

完成配置後，建議進行：

1. ✅ 完成基礎配置和測試
2. ✅ 設定監控和告警
3. ✅ 實現與 MyLLMNote 的整合
4. ⏳ 收集用戶反饋
5. ⏳ 根據需求優化和擴展功能

---

**文檔版本**: 1.0.0
**最後更新**: 2026-02-04
**維護者**: MyLLMNote 研究團隊
