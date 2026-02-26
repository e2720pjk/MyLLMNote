# 記憶管理 Agent Skills 實作指南

## 概述

本文檔描述如何為記憶管理 Agent 實作相關技能。這些技能將與 Automem 服務交互，提供記憶檢索、更新和分析功能。

---

## 1. 技能框架選擇

### 選項 A: OpenClaw Native Skills
直接在 OpenClaw Gateway 中定義技能（推薦）

### 選項 B: MCP Server
將技能包裝為 MCP 服務供 OpenClaw 呼叫

### 選項 C: 獨立 HTTP Service
將技能部署為獨立的 HTTP API

**建議**: 先採用選項 A (Native Skills），未來如需要可轉換為 MCP Server。

---

## 2. 技能實作清單

### 2.1 memory_read - 記憶檢索

**技能描述**: 從 Automem 檢索相關記憶

**參數**:
| 參數 | 類型 | 必填 | 說明 |
|------|------|------|------|
| query | string | 是 | 查詢關鍵字或問題 |
| scope | string | 否 | global/project/conversation (默認: project) |
| limit | int | 否 | 返回結果數量 (默認: 5, 最大: 20) |
| filters | object | 否 | 額外過濾條件 |

**輸出格式**:
```json
{
  "success": true,
  "results": [
    {
      "id": "mem_123456",
      "content": "記憶內容",
      "similarity": 0.92,
      "created_at": "2026-01-15T10:30:00Z",
      "source": "user",
      "category": "preference"
    }
  ]
}
```

**實作程式碼 (TypeScript/JavaScript)**:

```typescript
// File: .openclaw/skills/memory-read.js

import { fetch } from 'undici';

interface MemoryReadParams {
  query: string;
  scope?: 'global' | 'project' | 'conversation';
  limit?: number;
  filters?: Record<string, any>;
}

interface MemoryResult {
  id: string;
  content: string;
  similarity: number;
  created_at: string;
  source: string;
  category?: string;
}

export async function memory_read(params: MemoryReadParams): Promise<{
  success: boolean;
  results?: MemoryResult[];
  error?: string;
}> {
  const AUTOMEM_URL = process.env.AUTOMEM_URL || 'http://localhost:8080';
  const API_KEY = process.env.AUTOMEM_API_KEY;

  try {
    const response = await fetch(`${AUTOMEM_URL}/api/v1/query`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
      body: JSON.stringify({
        query: params.query,
        scope: params.scope || 'project',
        limit: Math.min(params.limit || 5, 20),
        filters: params.filters,
      }),
    });

    if (!response.ok) {
      throw new Error(`Automem API error: ${response.status}`);
    }

    const data = await response.json();
    return {
      success: true,
      results: data.results || [],
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

// OpenClaw 技能元數據
export const skillMetadata = {
  name: 'memory_read',
  description: '從 Automem 檢索相關記憶',
  parameters: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: '查詢關鍵字或問題',
      },
      scope: {
        type: 'string',
        enum: ['global', 'project', 'conversation'],
        description: '記憶範圍',
      },
      limit: {
        type: 'number',
        description: '返回結果數量 (1-20)',
        minimum: 1,
        maximum: 20,
      },
      filters: {
        type: 'object',
        description: '額外過濾條件',
      },
    },
    required: ['query'],
  },
};
```

**OpenClaw 代理配置 (AGENTS.md)**:
```markdown
## Skills - memory_read

當用戶詢問關於過去的信息、偏好或決策時，使用 memory_read 技能。

使用情境：
- 「我以前說過...？」
- 「還記得...嗎？」
- 「為什麼選擇這個方案？」
- 查詢用戶偏好或設定

不要使用情境：
- 當前會話中的信息（應直接從對話上下文獲取）
- 需要即時資訊的查詢
```

---

### 2.2 memory_save - 保存記憶

**技能描述**: 將資訊保存到 Automem

**參數**:
| 參數 | 類型 | 必填 | 說明 |
|------|------|------|------|
| content | string | 是 | 記憶內容 |
| category | string | 否 | 分類標籤 (preference/decision/knowledge) |
| importance | number | 否 | 重要性 0-1 (默認: 0.5) |
| scope | string | 否 | global/project/conversation (默認: project) |
| protected | boolean | 否 | 是否保護（不受衰退影響，默認: false) |

**輸出格式**:
```json
{
  "success": true,
  "memory_id": "mem_789012",
  "created_at": "2026-02-04T12:00:00Z"
}
```

**實作程式碼**:

```typescript
// File: .openclaw/skills/memory-save.js

import { fetch } from 'undici';

interface MemorySaveParams {
  content: string;
  category?: string;
  importance?: number;
  scope?: 'global' | 'project' | 'conversation';
  protected?: boolean;
}

export async function memory_save(params: MemorySaveParams): Promise<{
  success: boolean;
  memory_id?: string;
  created_at?: string;
  error?: string;
}> {
  const AUTOMEM_URL = process.env.AUTOMEM_URL || 'http://localhost:8080';
  const API_KEY = process.env.AUTOMEM_API_KEY;

  try {
    const response = await fetch(`${AUTOMEM_URL}/api/v1/memories`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
      body: JSON.stringify({
        content: params.content,
        category: params.category || 'knowledge',
        importance: Math.max(0, Math.min(1, params.importance ?? 0.5)),
        scope: params.scope || 'project',
        protected: params.protected ?? false,
        source: 'openclaw_agent',
        timestamp: new Date().toISOString(),
      }),
    });

    if (!response.ok) {
      throw new Error(`Automem API error: ${response.status}`);
    }

    const data = await response.json();
    return {
      success: true,
      memory_id: data.id,
      created_at: data.created_at,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

export const skillMetadata = {
  name: 'memory_save',
  description: '將資訊保存到 Automem',
  parameters: {
    type: 'object',
    properties: {
      content: {
        type: 'string',
        description: '記憶內容',
        minLength: 1,
        maxLength: 2000,
      },
      category: {
        type: 'string',
        enum: ['preference', 'decision', 'knowledge', 'conversation'],
        description: '記憶分類',
      },
      importance: {
        type: 'number',
        description: '重要性 0-1',
        minimum: 0,
        maximum: 1,
      },
      scope: {
        type: 'string',
        enum: ['global', 'project', 'conversation'],
        description: '記憶範圍',
      },
      protected: {
        type: 'boolean',
        description: '是否保護記憶（不受衰退影響）',
      },
    },
    required: ['content'],
  },
};
```

---

### 2.3 memory_update - 更新記憶

**技能描述**: 更新現有記憶的內容或元數據

**參數**:
| 參數 | 類型 | 必填 | 說明 |
|------|------|------|------|
| memory_id | string | 是 | 記憶 ID |
| content | string | 否 | 新內容 |
| category | string | 否 | 新分類 |
| importance | number | 否 | 新重要性 |

**實作程式碼**:

```typescript
// File: .openclaw/skills/memory-update.js

import { fetch } from 'undici';

interface MemoryUpdateParams {
  memory_id: string;
  content?: string;
  category?: string;
  importance?: number;
}

export async function memory_update(params: MemoryUpdateParams): Promise<{
  success: boolean;
  updated_fields?: string[];
  error?: string;
}> {
  const AUTOMEM_URL = process.env.AUTOMEM_URL || 'http://localhost:8080';
  const API_KEY = process.env.AUTOMEM_API_KEY;

  // 收集實際要更新的欄位
  const updates: Record<string, any> = {};
  if (params.content !== undefined) updates.content = params.content;
  if (params.category !== undefined) updates.category = params.category;
  if (params.importance !== undefined) {
    updates.importance = Math.max(0, Math.min(1, params.importance));
  }

  if (Object.keys(updates).length === 0) {
    return {
      success: false,
      error: '沒有提供任何要更新的欄位',
    };
  }

  try {
    const response = await fetch(`${AUTOMEM_URL}/api/v1/memories/${params.memory_id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
      body: JSON.stringify(updates),
    });

    if (!response.ok) {
      throw new Error(`Automem API error: ${response.status}`);
    }

    const data = await response.json();
    return {
      success: true,
      updated_fields: Object.keys(updates),
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

export const skillMetadata = {
  name: 'memory_update',
  description: '更新現有記憶',
  parameters: {
    type: 'object',
    properties: {
      memory_id: {
        type: 'string',
        description: '記憶 ID',
        minLength: 1,
      },
      content: {
        type: 'string',
        description: '新內容',
      },
      category: {
        type: 'string',
        enum: ['preference', 'decision', 'knowledge', 'conversation'],
      },
      importance: {
        type: 'number',
        minimum: 0,
        maximum: 1,
      },
    },
    required: ['memory_id'],
  },
};
```

---

### 2.4 memory_analyze - 記憶分析

**技能描述**: 分析記憶模式、聚類或時間線

**參數**:
| 參數 | 類型 | 必填 | 說明 |
|------|------|------|------|
| analysis_type | string | 是 | clustering/timeline/patterns |
| category | string | 否 | 特定類別 |
| time_range | string | 否 | 時間範圍 (7d/30d/90d) |

**輸出格式**:
```json
{
  "success": true,
  "analysis": {
    "type": "timeline",
    "entries": [
      {
        "date": "2026-01-15",
        "summary": "選擇 PostgreSQL 作為主資料庫",
        "memory_ids": ["mem_001", "mem_002"]
      }
    ]
  }
}
```

**實作程式碼**:

```typescript
// File: .openclaw/skills/memory-analyze.js

import { fetch } from 'undici';

interface MemoryAnalyzeParams {
  analysis_type: 'clustering' | 'timeline' | 'patterns';
  category?: string;
  time_range?: string;
}

export async function memory_analyze(params: MemoryAnalyzeParams): Promise<{
  success: boolean;
  analysis?: any;
  error?: string;
}> {
  const AUTOMEM_URL = process.env.AUTOMEM_URL || 'http://localhost:8080';
  const API_KEY = process.env.AUTOMEM_API_KEY;

  try {
    const response = await fetch(`${AUTOMEM_URL}/api/v1/analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
      body: JSON.stringify({
        type: params.analysis_type,
        category: params.category,
        time_range: params.time_range || '30d',
      }),
    });

    if (!response.ok) {
      throw new Error(`Automem API error: ${response.status}`);
    }

    const data = await response.json();
    return {
      success: true,
      analysis: data,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

export const skillMetadata = {
  name: 'memory_analyze',
  description: '分析記憶模式、聚類或時間線',
  parameters: {
    type: 'object',
    properties: {
      analysis_type: {
        type: 'string',
        enum: ['clustering', 'timeline', 'patterns'],
        description: '分析類型',
      },
      category: {
        type: 'string',
        description: '特定分類',
      },
      time_range: {
        type: 'string',
        enum: ['7d', '30d', '90d'],
        description: '時間範圍',
      },
    },
    required: ['analysis_type'],
  },
};
```

---

## 3. OpenClaw Gateway 配置整合

### 3.1 SKILLS.md 檔案

在 OpenClaw 工作目錄下創建 `SKILLS.md`:

```markdown
# Memory Manager Skills

## Available Skills

### memory_read
檢索相關記憶
- 用途: 查詢過去的偏好、決策、知識
- Skill file: `.openclaw/skills/memory-read.js`

### memory_save
保存記憶
- 用途: 記住重要資訊、用戶偏好
- Skill file: `.openclaw/skills/memory-save.js`

### memory_update
更新記憶
- 用途: 修正錯誤記憶、更新過時信息
- Skill file: `.openclaw/skills/memory-update.js`

### memory_analyze
分析記憶
- 用途: 查看記憶模式、聚類結果、時間線
- Skill file: `.openclaw/skills/memory-analyze.js`

## Environment Variables

- `AUTOMEM_URL`: Automem 服務地址 (默認: http://localhost:8080)
- `AUTOMEM_API_KEY`: Automem API 金鑰
```

### 3.2 Agent 配置 (.openclaw/agents/memory-manager/config.json)

```json
{
  "name": "Memory Manager",
  "role": "Librarian - 負責記憶查詢和管理的專職代理",
  "description": "專門負責檢索、保存和管理記憶的 Agent。像圖書館員一樣幫助用戶找到相關資訊。",
  "skills": [
    "memory_read",
    "memory_save",
    "memory_update",
    "memory_analyze"
  ],
  "system_prompt": "你是記憶管理 Agent（圖書館員）。你的職責是幫助用戶查詢和管理記憶。\n\n使用時機：\n- 當用戶詢問過去的信息時，使用 memory_read\n- 當用戶要求記住某事時，使用 memory_save\n- 當需要修正記憶時，使用 memory_update\n- 當需要分析記憶模式時，使用 memory_analyze\n\n注意：\n- 只保存重要的、長期有價值的信息\n- 不要保存臨時的對話上下文\n- 記憶應該清晰、簡潔、獨立",
  "automem_config": {
    "url": "${AUTOMEM_URL}",
    "api_key": "${AUTOMEM_API_KEY}",
    "default_scope": "project",
    "max_results": 10
  }
}
```

---

## 4. 測試計劃

### 4.1 單元測試

```typescript
// test/memory-read.test.ts
import { memory_read } from '../.openclaw/skills/memory-read.js';

describe('memory_read', () => {
  it('應該成功查詢記憶', async () => {
    const result = await memory_read({
      query: 'PostgreSQL',
      scope: 'project',
      limit: 5,
    });

    expect(result.success).toBe(true);
    expect(result.results).toBeDefined();
  });
});
```

### 4.2 整合測試

```bash
# 啟動 Automem 測試服務
docker-compose up -d automem

# 執行測試
npm test
```

---

## 5. 部署建議

### 5.1 Docker Compose

```yaml
version: '3.8'
services:
  automem:
    image: automem:latest
    ports:
      - "8080:8080"
    environment:
      - AUTOMEM_DATABASE_URL=postgresql://...
      - AUTOMEM_VECTOR_DB_URL=qdrant://...
    volumes:
      - ./automem-data:/data

  openclaw:
    image: openclaw:latest
    depends_on:
      - automem
    environment:
      - AUTOMEM_URL=http://automem:8080
      - AUTOMEM_API_KEY=${AUTOMEM_API_KEY}
```

### 5.2 MCP Server 模式 (可選)

如果 Automem 將來支援 MCP 協議，可以將其註冊為 MCP server:

```bash
opencode mcp add automem \
  --command "automem-mcp-server" \
  --args "--port 8080" \
  --env "AUTOMEM_API_KEY=$AUTOMEM_API_KEY"
```

---

## 6. 下一步

1. [ ] 取得 Automem 的 API 文檔和規範
2. [ ] 設定 Automem 測試環境
3. [ ] 實作並測試 memory_read skill
4. [ ] 實作其他 skills
5. [ ] 整合到 OpenClaw Agent
