# 記憶管理 Agent 架構設計

## 1. 設計原則

基於 CodeWiki 的「Structure-First」RAG 範式，記憶管理 Agent 應遵循以下原則：

1. **職責單一化**: Agent 專注於記憶的查詢和管理，不直接參與邏輯推導
2. **分層存儲**: 區分「結構化事實」與「語義化記憶」
3. **外部服務化**: Automem 作為 Sidecar 服務運行，避免耦合
4. **時間感知**: 記憶應具備時間戳記和重要性權重

---

## 2. Agent 職責範圍

### 2.1 核心職責
- **記憶檢索 (Memory Retrieval)**: 根據查詢從 Automem 檢索相關資訊
- **記憶更新 (Memory Update)**: 新增或修改記憶項目
- **記憶分析 (Memory Analysis)**: 分析記憶模式、聚類相關內容
- **記憶同步 (Memory Sync)**: 與外部來源同步記憶資料

### 2.2 非職責
- 不執行複雜的程式碼分析
- 不直接修改檔案系統（記憶操作除外）
- 不包含業務邏輯或決策

---

## 3. 系統架構

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw Gateway                          │
│                (Main Agent Coordinator)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ 查詢請求
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Memory Manager Agent (圖書館員)                   │
│  - 接收查詢請求                                              │
│  - 解析查詢意圖                                              │
│  - 呼叫 Automem API                                          │
│  - 格式化回傳結果                                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTP/gRPC Requests
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Automem Service                           │
│  (Sidecar Service)                                          │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Vector Store │  │  Qdrant DB   │  │ FalkorDB     │     │
│  │ (Embeddings) │  │  (Metadeta)  │  │ (Graph)      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
│  Consolidation Engine (時間衰减、聚類、去重)                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. 查詢介面設計

### 4.1 Agent → Automem API

**Endpoint: `POST /query`**

```json
{
  "query": "為什麼專案使用 PostgreSQL？",
  "filters": {
    "scope": "project",
    "category": "architecture",
    "time_range": "last_30_days"
  },
  "limit": 5,
  "include_metadata": true
}
```

**Response:**

```json
{
  "results": [
    {
      "id": "mem_123456",
      "content": "我們選擇 PostgreSQL 是因為它對 JSON 的原生支援...",
      "similarity": 0.92,
      "metadata": {
        "created_at": "2026-01-15T10:30:00Z",
        "source": "user",
        "importance": 0.85
      }
    }
  ],
  "related_memories": ["mem_789012", "mem_345678"]
}
```

### 4.2 Automem → Agent Webhook

**記憶更新事件:**

```json
{
  "event": "memory_updated",
  "memory_id": "mem_123456",
  "action": "consolidated",
  "new_content": "..."
}
```

---

## 5. Skills 設計

### 5.1 讀取記憶 (memory_read)

**用途**: 檢索相關記憶內容

**參數**:
- `query`: 查詢字串
- `scope`: global | project | conversation
- `limit`: 返回結果數量

**輸出**:
```json
{
  "memories": [
    {
      "id": "mem_001",
      "content": "記憶內容",
      "relevance": 0.95,
      "metadata": {...}
    }
  ]
}
```

### 5.2 保存記憶 (memory_save)

**用途**: 新增記憶到 Automem

**參數**:
- `content`: 記憶內容
- `category`: 分類標籤
- `importance`: 重要性 (0-1)
- `scope`: global | project | conversation
- `protected`: 是否保護（不受衰退影響）

**輸出**:
```json
{
  "memory_id": "mem_456",
  "status": "saved",
  "timestamp": "2026-02-04T12:00:00Z"
}
```

### 5.3 更新記憶 (memory_update)

**用途**: 修改現有記憶的內容或元數元數據

**參數**:
- `memory_id`: 記憶 ID
- `content`: 新內容（可選）
- `metadata`: 更新的元數據（可選）

**輸出**:
```json
{
  "memory_id": "mem_456",
  "status": "updated",
  "changes": ["content", "importance"]
}
```

### 5.4 記憶分析 (memory_analyze)

**用途**: 分析記憶模式、聚類、關聯

**參數**:
- `analysis_type`: clustering | timeline | patterns
- `category`: 特定類別（可選）
- `time_range`: 時間範間範圍

**輸出**:
```json
{
  "type": "clustering",
  "clusters": [
    {
      "name": "架構決策",
      "memories": ["mem_001", "mem_002"],
      "summary": "..."
    }
  ]
}
```

---

## 6. 與 MyLLMNote 整合策略

### 6.1 整合點

| 組件 | 整合方式 |
|------|----------|
| CodeWiki | 將模組摘要、架構分析推送到 Automem |
| NoteDB | 將筆記摘要、標籤同步到 Automem |
| Daily Notes | 當日總結自動生成記憶項目 |
| Chat History | 重要對話節點提取為記憶 |

### 6.2 同步流程

```mermaid
sequenceDiagram
    participant User
    participant Agent
    participant Automem
    participant MyLLMNote

    User->>Agent: 「提醒我去買咖啡豆」
    Agent->>Automem: memory_save(content, protected=false)
    Automem-->>Agent: memory_id
    Agent-->>User: 記住了！

    Note that
    MyLLMNote->>Automem: POST /sync (daily summary)
    Automem-->>MyLLMNote: OK
```

---

## 7. OpenClaw Agent 配置

### 7.1 Agent 檔案結構

```
.openclaw/agents/
├── memory-manager/
│   ├── AGENT.md          # Agent 介紹和職責
│   ├── SKILLS.md         # 可用技能清單
│   ├── config.json       # 記憶服務配置
│   └── prompts/
│       ├── system.md     # System prompt
│       └── memory_read.md
```

### 7.2 配置範例 (config.json)

```json
{
  "agent_name": "Memory Manager",
  "agent_role": "librarian",
  "automem_url": "http://localhost:8080",
  "api_key": "${AUTOMEM_API_KEY}",
  "default_scope": "project",
  "consolidation_enabled": true,
  "memory_retention_days": 365
}
```

---

## 8. 實作優先順序

### Phase 1: 基礎功能 (Week 1)
1. [ ] 設定 Automem 服務（Docker 部署）
2. [ ] 實作 memory_read skill
3. [ ] 實作 memory_save skill
4. [ ] 建立 OpenClaw Agent 配置

### Phase 2: 進階功能 (Week 2)
1. [ ] 實作 memory_update skill
2. [ ] 實作 memory_analyze skill
3. [ ] 與 MyLLMNote 整合（CodeWiki 摘要同步）
4. [ ] 時間感知和衰退機制

### Phase 3: 優化和擴展 (Week 3-4)
1. [ ] MCP Server 模式（如 Automem 支援）
2. [ ] 多記憶來源整合
3. [ ] 聊天記憶上下文管理
4. [ ] 效能優化和快取

---

## 9. 風險評估

| 風險 | 影響 | 緩解策略 |
|------|------|----------|
| Automem 服務不可用 | 高 | 實作降級方案，使用本地 Markdown 記憶 |
| 記憶膨脹導致效能問題 | 中 | 實作自動清理和壓縮機制 |
| 記憶資訊過時 | 中 | 時間衰减和重要性評分 |
| 敏感資訊洩漏 | 高 | 實作記憶加密和訪問控制 |

---

## 10. 下一步

1. 確認 Automem 原始碼位置和 API 規範
2. 建立本地 Automem 測試環境
3. 實作第一個 MVP 版本的記憶管理 agent
4. 編寫整合測試
