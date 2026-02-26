# CodeWiki 源代碼庫探索報告

**探索日期**: 2026-02-05  
**倉庫路徑**: `~/MyLLMNote/openclaw-workspace/repos/CodeWiki/`  
**當前分支**: `opencode-dev`

---

## 📋 執行摘要

CodeWiki 是一個 **AI 驅動的多語言代碼文檔生成框架**,基於 Tree-sitter 進行靜態代碼分析,支援 7 種編程語言。項目使用 Python 3.12+ 開發,採用分層架構設計,包含 CLI、Web 應用和後端分析引擎。

---

## 🏗️ 1. 目錄結構與主要模塊

### 總體架構
```
CodeWiki/
├── codewiki/                      # 主程序包 (81 個 Python 文件)
│   ├── cli/                       # CLI 接口層
│   │   ├── commands/              # 命令實現 (config, generate)
│   │   ├── models/                # 數據模型 (Configuration, AgentInstructions)
│   │   ├── utils/                 # 工具函數 (validation, fs, progress)
│   │   └── adapters/              # 外部集成
│   ├── src/
│   │   ├── be/                    # 後端核心
│   │   │   ├── dependency_analyzer/   # 依賴分析引擎 ⭐核心
│   │   │   │   ├── analyzers/         # 語言分析器 (8 個文件, 4233 行)
│   │   │   │   ├── analysis/          # 分析服務 (call_graph, repo_analyzer)
│   │   │   │   ├── models/            # 數據模型 (Node, CallRelationship)
│   │   │   │   └── utils/             # 工具 (thread_safe_parser, security)
│   │   │   ├── agent_tools/           # Agent 工具集
│   │   │   ├── agent_orchestrator.py  # Agent 調度器
│   │   │   ├── cluster_modules.py     # 模塊聚類
│   │   │   └── llm_services.py        # LLM 服務層
│   │   └── fe/                    # 前端 Web 應用
│   │       ├── routes.py
│   │       ├── visualise_docs.py
│   │       └── background_worker.py
│   └── templates/                 # Jinja2 模板
├── test/                          # 測試套件 (15 個文件, 3066 行)
├── docs/                          # 文檔輸出目錄
├── docker/                        # Docker 配置
├── pyproject.toml                 # 項目元數據
├── requirements.txt               # Python 依賴 (165 個包)
└── README.md, DEVELOPMENT.md      # 文檔
```

### 核心模塊分類

| 模塊 | 功能 | 關鍵文件 |
|------|------|---------|
| **CLI 層** | 命令行接口 | `cli/main.py`, `commands/generate.py`, `config_manager.py` |
| **依賴分析** | 多語言 AST 解析 | `dependency_analyzer/analyzers/*.py` (8 種語言) |
| **Agent 系統** | 遞歸文檔生成 | `agent_orchestrator.py`, `agent_tools/` |
| **配置管理** | 持久化配置 | `cli/models/config.py`, `src/config.py` |
| **Web 應用** | FastAPI 後端 | `fe/routes.py`, `fe/web_app.py` |
| **測試** | 單元/集成測試 | `test/test_*.py` (15 個測試文件) |

---

## 🔍 2. Joern 相關搜索結果

### 發現情況
**Joern 支持狀態**: **已配置但未實現**

#### 搜索結果 (4 處匹配)
1. **`codewiki/cli/commands/config.py:72-74`**
   ```python
   "--use-joern/--no-joern",
   help="Enable Joern CPG analysis",
   ```

2. **`codewiki/cli/commands/generate.py:146`**
   ```python
   "--use-joern/--no-joern",
   ```

3. **`codewiki/cli/commands/config.py:296`**
   ```python
   click.secho(f"✓ Joern CPG: {'enabled' if use_joern else 'disabled'}", fg="green")
   ```

#### 分析
- ✅ **CLI 參數已定義**: `--use-joern/--no-joern` 標誌已在配置和生成命令中實現
- ✅ **配置模型已支持**: `Configuration.use_joern: bool = False` (默認禁用)
- ❌ **無實際集成**: 未發現 `pyjoern` 導入或 CPG 分析實現代碼
- 🔧 **當前狀態**: Joern 是**計劃中的功能**,配置框架已就緒但未實現

---

## 🌲 3. Tree-sitter 使用情況

### 集成狀態
**Tree-sitter**: **✅ 全面集成並作為核心依賴**

#### 依賴版本 (來自 `pyproject.toml`)
```toml
"tree-sitter>=0.23.2",
"tree-sitter-language-pack>=0.8.0",
"tree-sitter-python>=0.23.6",
"tree-sitter-java>=0.23.5",
"tree-sitter-javascript>=0.21.4",
"tree-sitter-typescript>=0.21.2",
"tree-sitter-c>=0.21.4",
"tree-sitter-cpp>=0.23.4",
"tree-sitter-c-sharp>=0.23.1",
"tree-sitter-php>=0.23.0",
```

#### 使用位置 (23 處匹配)

##### 1. **核心解析器** (`dependency_analyzer/utils/thread_safe_parser.py`)
```python
from tree_sitter import Parser, Language

class ThreadSafeParserPool:
    """Thread-safe pool of tree-sitter parsers for parallel processing."""
```
- 實現了**線程安全的解析器池**,支持並行分析

##### 2. **語言分析器** (5 個文件)
| 文件 | 導入 | 用途 |
|------|------|------|
| `analyzers/javascript.py` | `from tree_sitter import Parser, Language` | JS AST 分析 |
| `analyzers/typescript.py` | `from tree_sitter import Parser, Language` | TS AST 分析 |
| `analyzers/php.py` | `from tree_sitter import Parser, Language` | PHP AST 分析 |

##### 3. **分析器接口** (`analysis/call_graph_analyzer.py`)
```python
# 356: Analyze JavaScript file using tree-sitter based AST analyzer
# 407: Analyze TypeScript file using tree-sitter based analyzer
# 457: Analyze C file using tree-sitter based analyzer
# 491: Analyze C++ file using tree-sitter based analyzer
# 524: Analyze Java file using tree-sitter based analyzer
# 564: Analyze C# file using tree-sitter based analyzer
# 605: Analyze PHP file using tree-sitter based analyzer
```

### 語言分析器實現 (代碼行數)
| 語言 | 文件名 | 行數 | 實現狀態 |
|------|--------|------|---------|
| TypeScript | `typescript.py` | 1024 | ✅ 完整實現 (最大) |
| JavaScript | `javascript.py` | 759 | ✅ 完整實現 |
| PHP | `php.py` | 677 | ✅ 完整實現 |
| C++ | `cpp.py` | 424 | ✅ 完整實現 |
| Java | `java.py` | 415 | ✅ 完整實現 |
| C# | `csharp.py` | 366 | ✅ 完整實現 |
| Python | `python.py` | 305 | ✅ 基於 `ast` 模塊 (非 Tree-sitter) |
| C | `c.py` | 262 | ✅ 完整實現 |

**總計**: 4233 行分析器代碼

---

## 🧪 4. 測試覆蓋情況

### 測試文件統計
```
test/ 目錄:
- 15 個測試文件
- 3066 行測試代碼
- 配置路徑: pyproject.toml → testpaths = ["tests"]
```

### 測試文件列表
| 文件名 | 行數 | 測試內容 |
|--------|------|---------|
| `test_parallel_correctness.py` | 13165 | 並行處理正確性 |
| `test_llm_cache.py` | 11738 | LLM 緩存機制 |
| `test_file_limits.py` | 11766 | 文件限制處理 |
| `test_refactoring.py` | 10065 | 重構功能 |
| `test_backward_compatibility.py` | 9381 | 向後兼容性 |
| `test_phase2_core.py` | 7522 | 第二階段核心功能 |
| `test_gitignore.py` | 7088 | .gitignore 解析 |
| `test_phase2.py` | 6848 | 第二階段測試 |
| `test_performance_utils.py` | 6848 | 性能工具 |
| `test_cache_concurrency.py` | 6509 | 緩存並發 |
| `test_token_tracking.py` | 6295 | Token 追蹤 |
| `test_gitignore_direct.py` | 4854 | .gitignore 直接測試 |
| `test_integration_token_tracking.py` | 3235 | Token 集成測試 |
| `test_gitignore_simple.py` | 2997 | .gitignore 簡單測試 |
| `test_cli_file_limits.py` | 1757 | CLI 文件限制 |

### 測試框架
```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = "-v --cov=codewiki --cov-report=term-missing"
```

### 開發依賴
```toml
[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "pytest-asyncio>=0.21.0",
    "black>=23.0.0",
    "mypy>=1.5.0",
    "ruff>=0.1.0",
]
```

---

## ⚙️ 5. 配置管理架構

### 配置文件層次結構

#### 5.1 CLI 配置層 (`cli/models/config.py`)

**核心類**: `Configuration`
```python
@dataclass
class Configuration:
    # LLM 配置
    base_url: str
    main_model: str
    cluster_model: str
    fallback_model: str = "glm-4p5"
    
    # Token 配置
    max_tokens: int = 32768
    max_token_per_module: int = 36369
    max_token_per_leaf_module: int = 16000
    
    # Agent 自定義指令
    agent_instructions: AgentInstructions = field(default_factory=AgentInstructions)
    
    # 分析選項 (集成)
    max_files: int = 100
    max_entry_points: int = 5
    max_connectivity_files: int = 10
    enable_parallel_processing: bool = True
    concurrency_limit: int = 5
    enable_llm_cache: bool = True
    agent_retries: int = 3
    cache_size: int = 1000
    use_joern: bool = False          # ⭐ Joern 配置
    respect_gitignore: bool = False
```

**Agent 指令類**: `AgentInstructions`
```python
@dataclass
class AgentInstructions:
    include_patterns: Optional[List[str]] = None  # 文件包含模式
    exclude_patterns: Optional[List[str]] = None  # 文件排除模式
    focus_modules: Optional[List[str]] = None     # 重點模塊
    doc_type: Optional[str] = None                # 文檔類型 (api, architecture, etc.)
    custom_instructions: Optional[str] = None     # 自由文本指令
```

#### 5.2 後端配置層 (`src/config.py`)

**核心類**: `Config`
```python
@dataclass
class Config:
    repo_path: str
    output_dir: str
    dependency_graph_dir: str
    docs_dir: str
    max_depth: int
    
    # LLM 配置
    llm_base_url: str
    llm_api_key: str
    main_model: str
    cluster_model: str
    fallback_model: str = FALLBACK_MODEL_1
    
    # 分析選項
    analysis_options: AnalysisOptions = field(default_factory=AnalysisOptions)
    
    # Token 配置
    max_tokens: int = DEFAULT_MAX_TOKENS
    max_token_per_module: int = DEFAULT_MAX_TOKEN_PER_MODULE
    max_token_per_leaf_module: int = DEFAULT_MAX_TOKEN_PER_LEAF_MODULE
    
    # Agent 指令
    agent_instructions: Optional[Dict[str, Any]] = None
```

#### 5.3 配置管理器 (`cli/config_manager.py`)

- **持久化路徑**: `~/.codewiki/config.json`
- **功能**: 
  - 讀取/寫入配置
  - API Key 管理 (使用 `keyring`)
  - 配置驗證

#### 5.4 前端配置 (`src/fe/config.py`)

- Web 應用專用配置
- FastAPI 路由設置

### 配置流程
```
CLI 命令參數
    ↓
CLI Configuration (models/config.py)
    ↓
持久化到 ~/.codewiki/config.json
    ↓
Backend Config (src/config.py)
    ↓
分析引擎 + Agent 系統
```

---

## 📊 6. Git 狀態與開發活動

### 當前狀態
```
分支: opencode-dev
狀態: Clean working tree (無未提交更改)
遠程: origin/opencode-dev (已同步)
```

### 最近 10 次提交
```
7aae3e0 Merge branch 'main' into merge-main
bd119a2 feat: add actual API timing measurement for agent performance tracking
2bf0003 feat: add token usage tracking for agent operations
aedf4e7 fix: improve robustness and error handling in core components
a71b16b refactor: convert cache concurrency tests from threading to async
47f8f14 refactor: optimize module processing and performance tracking
96f2162 fix: resolve async locking, exception handling, and magic number issues
5c5ddf8 feat: implement token tracking for LLM API calls
2bbddbb fix: address code review issues - thread safety, type validation, and error handling
d13dd15 fix: working_dir defaults to 'docs'
```

### 開發活動
- **2025 年以來提交數**: 98 次提交
- **活躍分支**: 19 個遠程分支 (含特性分支和問題分支)
- **主要分支**:
  - `main`: 主線分支
  - `opencode-dev`: 當前開發分支
  - `merge-main`: 合併分支
  - `feat/respect-gitignore`: .gitignore 支持特性

### 問題分支模式
```
opencode/issue{N}-{TIMESTAMP}
例如: opencode/issue23-20260108123748
```
表明使用自動化工具進行問題跟蹤

---

## 📦 7. pyproject.toml 依賴分析

### 項目元數據
```toml
[project]
name = "codewiki"
version = "1.0.1"
description = "Transform codebases into comprehensive documentation using AI-powered analysis"
requires-python = ">=3.12"
license = {text = "MIT"}
```

### 核心依賴分類

#### 7.1 CLI 與工具
```toml
click>=8.1.0                    # CLI 框架
keyring>=24.0.0                 # 安全密鑰存儲
GitPython>=3.1.40               # Git 操作
rich>=14.1.0                    # 終端美化
```

#### 7.2 Tree-sitter 生態 (10 個包)
```toml
tree-sitter>=0.23.2             # 核心解析器
tree-sitter-language-pack>=0.8.0
tree-sitter-python>=0.23.6
tree-sitter-java>=0.23.5
tree-sitter-javascript>=0.21.4
tree-sitter-typescript>=0.21.2
tree-sitter-c>=0.21.4
tree-sitter-cpp>=0.23.4
tree-sitter-c-sharp>=0.23.1
tree-sitter-php>=0.23.0
```

#### 7.3 LLM 服務
```toml
openai>=1.107.0                 # OpenAI SDK
litellm>=1.77.0                 # 統一 LLM 接口
pydantic>=2.11.7                # 數據驗證
pydantic-settings>=2.10.1       # 設置管理
pydantic-ai>=1.0.6              # AI Agent 框架
```

#### 7.4 模板與可視化
```toml
Jinja2>=3.1.6                   # 模板引擎
mermaid-parser-py>=0.0.2        # Mermaid 解析
mermaid-py>=0.8.0               # Mermaid 驗證 (需要 Node.js)
```

#### 7.5 數據處理
```toml
networkx>=3.5                   # 圖算法 (依賴圖構建)
psutil>=7.0.0                   # 系統監控
PyYAML>=6.0.2                   # YAML 處理
requests>=2.32.4                # HTTP 客戶端
```

#### 7.6 環境管理
```toml
python-dotenv>=1.1.1            # .env 文件加載
```

### 外部依賴
```toml
[external]
build-requires = [
    { name = "nodejs", version = ">=14.0.0" }  # mermaid-py 所需
]
```

### CLI 入口點
```toml
[project.scripts]
codewiki = "codewiki.cli.main:cli"
```

### 代碼質量工具
```toml
[tool.black]
line-length = 100
target-version = ['py312']

[tool.mypy]
python_version = "3.12"
warn_return_any = true
disallow_untyped_defs = false

[tool.ruff]
line-length = 100
target-version = "py312"
```

---

## 🔍 8. TODO/FIXME 註釋

### 搜索結果 (2 處)

#### 1. **`llm_services.py:181`**
```python
# TODO: Track last access time and implement actual cleanup logic
```
**上下文**: LLM 緩存清理邏輯
**優先級**: 中等 (性能優化)

#### 2. **`agent_tools/str_replace_editor.py:235`**
```python
# TODO: consider special casing docstrings such that they are not elided. This
```
**上下文**: 文檔字符串處理
**優先級**: 低 (代碼質量改進)

### 分析
- 代碼庫非常乾淨,技術債務很少
- 僅 2 個 TODO,且都不是關鍵問題
- 無 FIXME 或 XXX 標記

---

## 📚 9. 文檔覆蓋

### 主要文檔
1. **README.md** (369 行)
   - 快速開始指南
   - CLI 命令文檔
   - 支持語言列表
   - 使用示例和 GIF

2. **DEVELOPMENT.md** (298 行)
   - 項目結構詳解
   - 開發設置
   - 擴展指南 (新語言, Agent 指令)
   - 測試和調試

3. **DOCKER_README.md**
   - Docker 部署指南

### 代碼文檔質量
- ✅ 所有配置類都有詳細 docstrings
- ✅ 複雜函數有類型提示
- ✅ 分析器有清晰的接口定義
- ⚠️ 部分工具函數缺少文檔

---

## 🎯 10. 關鍵發現與建議

### 10.1 架構亮點
1. **分層清晰**: CLI → Backend Config → Analysis Engine
2. **並行處理**: Thread-safe parser pool + 並發控制
3. **可擴展性**: 易於添加新語言分析器
4. **配置靈活**: AgentInstructions 系統支持高度定制

### 10.2 技術棧
- **核心**: Python 3.12, Tree-sitter, Pydantic
- **LLM**: OpenAI SDK, LiteLLM (多模型支持)
- **Web**: FastAPI (未來 Web 應用)
- **測試**: Pytest + Coverage

### 10.3 待實現功能
1. **Joern CPG 集成** (配置已就緒,代碼未實現)
2. **增量文檔更新** (在 DEVELOPMENT.md 中提及)
3. **LLM 緩存清理邏輯** (TODO 項)

### 10.4 建議改進
1. **Joern 集成路徑**:
   - 添加 `pyjoern` 依賴到 `pyproject.toml`
   - 在 `dependency_analyzer/analysis/` 創建 `joern_analyzer.py`
   - 實現 CPG 提取邏輯
   - 集成到 `CallGraphAnalyzer`

2. **測試覆蓋**:
   - 當前測試主要集中在緩存和並發
   - 建議增加語言分析器的端到端測試
   - 添加 Tree-sitter 解析失敗的邊界測試

3. **文檔**:
   - 為每個語言分析器創建專門的 README
   - 添加 API 文檔生成 (Sphinx/MkDocs)

4. **性能**:
   - 實現 TODO 中的緩存清理邏輯
   - 考慮使用 `rust-tree-sitter` 提升解析性能

---

## 📈 統計總結

| 指標 | 數值 |
|------|------|
| **總 Python 文件** | 81 |
| **總代碼行數** | ~15,000+ (估算) |
| **測試文件** | 15 |
| **測試代碼行數** | 3,066 |
| **支持語言** | 7 (Python, Java, JS, TS, C, C++, C#, PHP) |
| **分析器代碼** | 4,233 行 |
| **依賴包數** | 165 |
| **2025 年提交數** | 98 |
| **活躍分支** | 19 |
| **TODO 項** | 2 |
| **FIXME 項** | 0 |

---

## 🔗 相關鏈接

- **GitHub**: https://github.com/FSoft-AI4Code/CodeWiki
- **論文**: https://arxiv.org/abs/2510.24428
- **許可**: MIT License
- **Python 版本**: ≥3.12

---

**報告生成者**: Antigravity AI  
**工具**: OpenCode Workspace  
**分析方法**: 代碼搜索 (grep), 文件統計, 配置解析, Git 歷史
