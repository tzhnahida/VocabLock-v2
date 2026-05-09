# VocabLock v2 — Flutter + Go 架构重构

## Context

当前是 Wails v2 单二进制（Go + React/WebView）。扩展听力、阅读、语法、AI 判题、AI 扩词五块功能后，架构会持续恶化。决定拆为 Flutter 桌面 + Go HTTP 服务，老代码全部放 `backup/`，新代码从零建。

---

## 架构总览

```
Flutter 桌面 (UI)
    │  HTTP REST (localhost)  JSON
Go API 服务
    ├── 学习引擎 (SM-2 / 出题 / 判题 / 扩词)
    ├── AI 编排   (DeepSeek / prompt / 解析)
    ├── TTS 调度  (外部命令，可插拔)
    ├── 词典调度  (外部命令，可插拔)
    ├── 系统控制  (锁屏 / 托盘 / 单实例 / 自启)
    ├── SQLite
    └── 配置文件 (YAML)
```

### 进程模型

```
VocabLock.exe 启动
  ├── Go API 服务 (goroutine 1, HTTP 随机端口)
  ├── 锁屏窗口 (goroutine 2, Win32 窗口线程)
  ├── 系统托盘 (goroutine 3, 独立 OS 线程)
  └── Flutter 窗口 (子进程, 通过参数获取 API 端口)
```

### 通信契约

Flutter ↔ Go：HTTP JSON，Go 侧定义 OpenAPI 3.0 规范。Flutter 不 import Go，Go 不 import Flutter。换前端只需重新实现 HTTP 客户端。

### 进程生命周期与故障恢复

**启动握手**：
```
Go 起随机端口 → 生成 Auth Token → 启动 Flutter
  → 参数: --api-port=xxx --auth-token=yyy --go-pid=zzz
  → Flutter 调 /health（带 token）确认就绪
```

**双向检测**：
- Flutter → Go：每 3s `/health`，连续 2 次超时 → 进入故障恢复
- Go → Flutter：每 5s 检查进程存活，不存在 → 自动解锁 + 日志

**三种崩溃场景与恢复路径**：

| 场景 | 锁屏窗口 | HTTP | 用户状态 | 恢复 |
|------|---------|------|---------|------|
| Go panic（进程存活） | 仍在 | 死 | **被锁** | Flutter 心跳超时 → 显示"服务中断"+ "强制退出"按钮 → 调 `taskkill /F /PID <go-pid>` → 窗口随进程销毁 |
| Go 硬崩溃（OS 杀） | 随进程销毁 | 死 | **已解锁** | 锁屏窗口已随进程消失，用户自由。Flutter 显示"服务中断，请重新启动" |
| Go 假死（hung/不响应） | 仍在 | 超时 | **被锁** | 同 panic：Flutter 超时 → 用户点强制退出 → `taskkill /F` |

Flutter 知道 Go 的 PID（启动参数），`taskkill /F` 杀同用户进程不需要管理员权限。Go 崩溃本身不可恢复，但恢复路径能保证**用户不被永久锁死**。

**锁屏覆盖下的 UI 逃生**：假死场景中 Go 锁屏窗口（TOPMOST 全屏）遮挡 Flutter，"强制退出"按钮不可见也不可点击。采用三层逃生体系：

| 层 | 机制 | 触发 | 可靠性 |
|----|------|------|--------|
| **1. Global Hotkey** | Flutter 调用 Win32 `RegisterHotKey` 注册 `Ctrl+Shift+Q`，OS 级送达，不被 TOPMOST 遮挡 | 用户按键，任意时刻 | 最高——独立进程+OS级 |
| **2. Go 死等开关** | Go 窗口线程独立 ticker 每 10s 自检 HTTP 健康，连续 3 次失败 → 锁屏界面直接绘制倒计时 + "立即退出"按钮 | 自动 | 中——需窗口线程存活 |
| **3. Ctrl+Alt+Del** | Windows 安全注意序列，永远可用，任务管理器结束进程 | 用户手动 | 100%（操作系统保证） |

Flutter 调 Win32 API：Dart FFI 直接调 `user32.dll`（`RegisterHotKey` + `GetMessage`），不需要额外原生代码。`Ctrl+Shift+Q` 按下 → Flutter 弹出 TOPMOST 确认对话框 → 确认 → `taskkill /F /PID <go-pid>`。

Go 窗口线程入口 `defer/recover`：panic 时标记窗口失效 + `os.Exit(1)`，确保窗口与进程状态一致。

**正常退出**：Flutter → `POST /system/quit` → Go 解锁 → 清理 → Go 发 SIGTERM 给 Flutter → 全部退出。

---

## 1. Go 后端

### 目录

```
backend/
├── cmd/server/main.go
├── internal/
│   ├── api/               # HTTP handler（路由/中间件/各资源handler）
│   ├── api/
│   │   └── mock/          # Mock handler（--mock 模式，不调AI不写DB）
│   ├── engine/            # 业务（sm2/question/expand/scheduler）
│   │   └── judge/         # 判题（exact/regex/ai三级）
│   ├── ai/                # AI（client/prompts/parser）
│   ├── tts/               # TTS（provider调度/cache）
│   ├── dict/              # 词典（provider调度）
│   ├── db/                # 数据库（sqlite/models/migrations）
│   ├── system/            # 系统层（provider接口+分平台文件）
│   └── config/            # 配置读写 + validator
├── configs/
│   ├── app.yaml           # 主配置
│   ├── tts.yaml           # TTS provider 列表
│   ├── dict.yaml          # 词典 provider 列表
│   ├── languages/         # 语种定义（ja/en/zh/...各一yaml）
│   └── prompts/           # prompt模板
├── tts/                   # TTS外部二进制
├── dict/                  # 词典外部二进制
├── data/                  # 运行时（SQLite/音频缓存/日志）
├── go.mod / go.sum
```

### API 路由

```
# 测验
GET    /api/v1/quiz/progress
GET    /api/v1/quiz/next
POST   /api/v1/quiz/submit
GET    /api/v1/quiz/today-stats
POST   /api/v1/quiz/complete

# 单词
GET    /api/v1/words
GET    /api/v1/words/:id
POST   /api/v1/words
PUT    /api/v1/words/:id
DELETE /api/v1/words/:id
POST   /api/v1/words/:id/reset
GET    /api/v1/words/export
POST   /api/v1/words/import
POST   /api/v1/words/expand      # AI 扩词

# AI
POST   /api/v1/ai/chat
GET    /api/v1/ai/profile
PUT    /api/v1/ai/profile

# TTS
GET    /api/v1/tts/word/:id
POST   /api/v1/tts/text

# 统计
GET    /api/v1/stats/heatmap
GET    /api/v1/stats/streak
GET    /api/v1/stats/daily-report

# 系统
GET    /api/v1/system/status
POST   /api/v1/system/lock
POST   /api/v1/system/unlock
GET    /api/v1/system/passive-q
POST   /api/v1/system/passive-submit
POST   /api/v1/system/quit

# 配置
GET    /api/v1/config
GET    /api/v1/config/:key
PUT    /api/v1/config
POST   /api/v1/config/password
```

---

## 2. 配置文件分层

三层设计：全局 TTS/Dict provider 列表 + 语种专属配置。语种文件只引用上层 provider name。

### `configs/tts.yaml`

```yaml
tts:
  cache_limit: 500
  fallback_order: [edge-tts, sapi]
  providers:
    edge-tts:
      command: 'tts\edge-tts\edge-tts.exe --voice {voice} --text "{text}" --write-media "{output}"'
      format: mp3
      voices:
        ja: ja-JP-NanamiNeural
        en: en-US-JennyNeural
        zh: zh-CN-XiaoxiaoNeural
        ko: ko-KR-SunHiNeural
    sapi:
      command: 'powershell -File tts\sapi\speak.ps1 -Lang {lang} -Text "{text}" -Output "{output}"'
      format: wav
```

### `configs/dict.yaml`

```yaml
dict:
  providers:
    jmdict:
      lang: ja
      command: 'dict\ja\lookup.exe --word "{word}"'
      format: json
    webster:
      lang: en
      command: 'dict\en\lookup.bat "{word}"'
      format: json
    cedict:
      lang: zh
      command: 'dict\zh\lookup.ps1 -Word "{word}"'
      format: json
```

### `configs/languages/ja.yaml`

```yaml
lang:
  code: ja
  display_name: 日本語
  native_name: 日语

tts:
  provider: edge-tts          # 引用 tts.yaml
  voice: ja-JP-NanamiNeural

dict:
  provider: jmdict            # 引用 dict.yaml

question_types:
  - choice
  - fill
  - reading
  - listening
  - reading_comp
  - grammar

prompt_context:
  teacher_role: 日本語教師
  explanation_lang: zh-CN
  level_descriptions:
    beginner: "N5レベル：1-2文、基本語彙"
    intermediate: "N3-N4レベル：3-4文、日常会話"
    advanced: "N2レベル：4-6文、含意を読み取る"

grammar_points:
  - 助詞（は/が/を/に/で）
  - 活用形（て形/た形/ない形）
  - 敬語（尊敬語/謙譲語/丁寧語）
  - 文型（〜ている/〜てしまう/〜なければならない）

seed_words_file: seeds/ja.json
```

### Go 加载逻辑

```go
ttsConfig := load("configs/tts.yaml")
dictConfig := load("configs/dict.yaml")
for _, f := range glob("configs/languages/*.yaml") {
    lang := load(f)
    // 校验: tts.yaml 中有 lang.TTS.Provider?
    // 校验: dict.yaml 中有 lang.Dict.Provider?
    // 校验: 该 provider 的 voices 中有 lang.TTS.Voice?
}
```

加语言 = `tts.yaml`加voice → `dict.yaml`加provider → 写 `languages/ko.yaml`。

### 语种热切换

启动时全部语种配置加载到内存。用户切语种 → `PUT /api/v1/config` 更新 `active_lang` → engine 读取新语种 → 重新生成题目池 → 后续出题/判题/TTS 全用新语种。**不需要重启。** 之前语种的 SM-2 状态保留在 SQLite，切换是叠加不是覆盖。

"清空"的精确边界：只丢弃 `question_pool` 中 `is_used=0` 的预生成题目。当前正在作答的题目（前端已获取、待提交）在 `SubmitAnswer` 时才会标记 `is_used=1`，不在清理范围。用户感知：当前题不受影响，下一题起切到新语种。

### 配置 Schema 校验

启动时 `config/validator.go` 全量校验，不等到运行时报错：

```go
func ValidateConfigs() []error {
    // 1. 校验 tts.yaml 格式
    // 2. 校验 dict.yaml 格式
    // 3. 遍历 languages/*.yaml:
    //      - tts.provider 在 tts.yaml 中存在？
    //      - tts.voice 在该 provider.voices 下存在？
    //      - dict.provider 在 dict.yaml 中存在或为空？
    //      - question_types 无未注册的 type？
    // 4. 校验 prompt 模板文件存在且可解析
}
```

校验失败 → 启动中止，stderr 打印具体错误行。运行时永不报配置错。

---

## 3. TTS 可插拔 + 词典可插拔（标准输出协议）

Go 不做实现，只做调度+缓存。关键："可插拔"不等于纯改 yaml——需要一份**标准输出协议**。遵守协议的新 provider = 零 Go 代码接入。不遵守 = 写一个 wrapper 脚本适配，仍不需要改 Go。

### TTS 协议

```
输入:  参数列表 [--voice {voice} --text {text} --write-media {output}]
输出:  音频文件写入 {output} 路径
stdout: 忽略
stderr: Go 读取写入日志
退出:  0 = 成功, 非0 = 失败
超时:  30s
```

Go 端 `tts/provider.go`：build args array → exec → 检查退出码 → 读输出文件 → 转 data URL → LRU 缓存。所有 provider 同一段 Go 代码。

### 词典协议

```
输入:  参数列表 [--word "{word}"]
stdout: 一行 JSON
stderr: Go 读取写入日志
退出:  0 = 命中, 1 = 未命中, 2+ = 错误
超时:  5s
```

**强制输出 schema**：

命中：`{"found":true,"word":"食べる","reading":"たべる","meaning":"to eat","pos":"verb"}`
未命中：`{"found":false}`

Go 端：`json.Unmarshal(stdout)` → 检查 `Found` → 取 `POS` 做词性校验。

### 缓存策略（防高频 fork）

缓存键：`MD5(provider_name + ":" + voice + ":" + text)`，缓存到 `data/audio/<md5>.<format>`，500 文件 LRU。

| 场景 | fork? | 原因 |
|------|-------|------|
| 题目生成期，预生成听力音频 | ✓ 首次 | N 段脚本 → N 次 edge-tts → 写入缓存 |
| 用户播放听力题 | ✗ | 生成期已写入，播放时 MD5 命中 → 纯读文件 |
| 用户点单词发音，首次 | ✓ | 缓存 miss → fork |
| 用户点单词发音，再次 | ✗ | 缓存 hit |

一次复习 10 道听力题 = 生成期 N 次 fork（可接受），学习期 0 次 fork。

### 僵尸进程防泄露（Windows Job Object）

`os/exec + context.WithTimeout` 只杀直接子进程，不杀孙子。windows Provider 用 **Job Object** 解决：

```go
// provider_windows.go
job, _ := windows.CreateJobObject(nil, nil)
// 设置 JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
// 子进程挂入 Job
windows.AssignProcessToJobObject(job, windows.Handle(cmd.Process.Pid))
```

超时或异常退出 → `job.Close()` → Windows 内核自动终止 Job 内**所有**进程树（含 PowerShell → edge-tts 两层嵌套）。无僵尸。

`provider_unix.go` 用 `setsid` + 进程组 signal。跨平台差异在 build tags 内解决，Go 上层只调 `StartWithTimeout()`。

**附加约束**：TTS provider 尽量直接调 exe，不走 `powershell -File`。SAPI 兜底例外，用 `-EncodedCommand` + stdin 管道。

### 命令注入防护（参数列表，不经 shell）

yaml 的 `command` 不是 shell 字符串，是**可执行路径 + 参数数组**：

```yaml
providers:
  edge-tts:
    binary: 'tts\edge-tts\edge-tts.exe'
    args:
      - '--voice'
      - '{voice}'
      - '--text'
      - '{text}'
      - '--write-media'
      - '{output}'
```

Go 端：

```go
func buildCmd(p Provider, vars map[string]string) *exec.Cmd {
    args := make([]string, len(p.Args))
    for i, tpl := range p.Args {
        args[i] = os.Expand(tpl, func(k string) string { return vars[k] })
    }
    return exec.Command(p.Binary, args...)  // ← 参数列表，不经过 shell
}
```

`exec.Command("edge-tts.exe", "--text", "hello; rm -rf /")` — 底层走 `CreateProcessW`，不经过 `cmd.exe`。`{text}` 的值即使是恶意字符串，也只是 edge-tts 的一个字面参数，不被解释为命令。

词典同理：用户输入的 `{word}` 来自提交答案或查询单词框，但它只是 `lookup.exe --word` 的参数值，不可能被注入执行。

唯一走 PowerShell 的 SAPI：用 `-EncodedCommand <base64>` 通过 stdin 管道传入脚本，命令行参数面不存在用户输入。

### 启动校验

`config/validator.go` 对每个 dict provider 空跑一次检查。默认用 `--word "test"`。

Provider 可自定义健康检查命令：

```yaml
providers:
  jmdict:
    health_check:
      custom: ['--version']              # 自定义检查命令
    # 或
    health_check:
      skip: true                         # 跳过（用户自担风险，日志 warn）
```

未指定 → 默认 `--word "test"`。指定 `skip: true` → 日志 warn，不中止。验证内容：stdout schema、退出码范围、超时。

### 可插拔的真实边界

| 场景 | 代价 |
|------|------|
| 换 TTS 引擎（同 CLI 签名） | yaml 改 args |
| 换 TTS 引擎（CLI 签名不同） | 写 5 行 bat/powershell wrapper |
| 加词典语种 | 写一个输出标准 JSON 的脚本 + `dict.yaml` 加一行 |
| 换 AI provider | yaml 改 endpoint + model |
| 加平台支持 | 新建 `provider_xxx.go` |

不是"纯 yaml 零代码"，是"不需要改 Go 代码，wrapper 用任意语言写，遵守协议"。

### 外部文件目录

```
tts/
├── edge-tts/edge-tts.exe
└── sapi/speak.ps1

dict/
├── ja/lookup.exe
├── en/lookup.bat
└── zh/lookup.ps1
```

---

## 4. 系统层平台解耦

Go 文件按平台编译，build tags 分拣。

### 接口

```go
type SystemProvider interface {
    EnterLockMode(hwnd uintptr) error
    ExitLockMode() error
    OnWindowClosing() bool
    StartTray(onShow, onQuit func()) error
    StopTray() error
    AcquireLock() (bool, error)
    SetAutoStart(enabled bool) error
    FindFlutterWindow() (uintptr, error)
}
func Get() SystemProvider  // 编译时选择
```

### 平台文件

```
internal/system/
├── provider.go              # 接口 + 工厂
├── provider_windows.go      # +build windows
├── provider_darwin.go       # +build darwin
└── provider_linux.go        # +build linux
```

Go 操作 Flutter 窗口属性，Flutter 只管渲染 UI。

---

## 5. 题型矩阵

| 题型 | type | 关联词 | 判题 | 比例配置 |
|------|------|--------|------|---------|
| 选择 | choice | ✓ | 精确匹配 | 剩余 |
| 填空 | fill | ✓ | 精确→AI兜底 | ↑ |
| 拼写 | spelling | ✓ | 精确→AI兜底 | ↑ |
| 读音 | reading | ✓ | 精确 | ↑ |
| 听力 | listening | ✗ | 精确(选项) | listening_ratio |
| 阅读 | reading_comp | ✗ | 精确(选项) | reading_ratio |
| 语法 | grammar | ✗ | 精确→AI兜底 | grammar_ratio |

配置项（SettingsPanel 可调，设 0 关闭）：
- `listening_ratio` / `reading_ratio` / `grammar_ratio` — 默认各 0.15
- `auto_expand_words` — 默认 true
- `expand_batch_size` — 默认 10
- `expand_threshold` — 默认 0.6

---

## 6. 新增功能

### 6.1 听力

AI 生成对话/独白 → Edge TTS 预热缓存 → 选择题作答 → 答后折叠展示原文。

### 6.2 阅读

AI 生成短文（邮件/公告/随笔/说明文）→ 阅读理解选择题 → 答后展示解释。

### 6.3 语法

AI 生成语法题（助词/活用/敬语/句型）→ 选择题作答 → 语法点标签显示。

### 6.4 AI 判题（三级 + 严谨度 + 降级）

```go
// internal/engine/judge/
type JudgeResult struct {
    Correct  bool
    Score    float64  // 0-1
    Feedback string
    Source   string   // "exact" | "regex" | "ai" | "regex_fallback"
}
```

**三级判题链 + 降级路径**：

```
提交答案
  → exact 命中 → 直接返回, source=exact, <1ms
  → exact 未命中 → regex 评分, <5ms
      → regex 高置信(>0.9) → 返回, source=regex
      → regex 低置信 → 尝试 AI 判题
          → AI 成功 → 返回, source=ai, 3-8s
          → AI 超时/失败 → 退回 regex, source=regex_fallback
```

**不存在"判不了"的死胡同。** 最坏情况退回 regex，宁可判错一题不卡死用户。

**信任透明**：前端不暴露 `source` 字段，但反馈文案区分：
- AI 判对：`"✓ 正确"` + AI 解释
- regex_fallback：`"✗ 错误"` + 正确答案 + `"(系统规则判定)"` 灰色小字

**严谨度**（`configs/prompts/judge.yaml`）：

| strictness | 题型 | 行为 |
|-----------|------|------|
| strict | spelling | 大小写/假名/空格完全一致 |
| normal | fill, grammar | 允许同义词、替代说法 |
| lenient | 口语(将来) | 语义对齐即可 |

### 6.5 AI 动态扩词

触发条件：`ShouldExpandWords()` → 掌握度 > threshold 的词占比 > 80%。流程：

```
getReviewWords 返回不足 → ShouldExpandWords → ExpandWordBank
  → AI 生成新词 → 词典校验 → verified/pending_review
  → INSERT INTO words → 日志
```

### 6.6 扩词幻觉控制

| 层 | 机制 |
|----|------|
| Prompt | 要求返回汉字-假名拆分，只生成 confidence=high |
| 词典 | AI 结果调 Lookup() → 命中+POS匹配 → verified；POS不匹配或未命中 → pending |
| 用户 | 前端展示待审核列表，勾选/编辑/拒绝 |
| 淘汰 | 入库后报错 → confidence=low → 系统停用 |

API 返回格式：`POST /api/v1/words/expand` → `{ verified: [...], pending_review: [...] }`

### 6.7 先学后考与 SM-2 的关系

先学后考（预览阶段）**完全独立于 SM-2**。预览只是展示单词卡片+发音，不触发任何 SM-2 状态变更。

SM-2 的 `first_review` 在用户**第一次提交答案**时触发——无论预览阶段看过多少遍。新词（无 `word_status` 行）→ `next_review_at = NULL` → `getReviewWords` 用 `ORDER BY next_review_at ASC NULLS FIRST` 优先选中 → 立即进入题目池。传统 Anki "学习卡 → 复习卡"两阶段在此合并为"预览（可选）→ 测验（必做）"。

---

## 7. AI 容灾与降级

### 7.1 核心原则：词汇题零 AI 依赖

choice/fill/spelling/reading 四种词汇题型 — 出题用本地模板 `generateLocalQuestions()`，判题用 exact + regex — 完全不需要 AI。SM-2 驱动，永不中断。

### 7.2 AI 全局宕机时系统行为

| 功能 | 断 AI 后果 | 用户可继续？ |
|------|-----------|------------|
| 词汇题 (4 种) | 无影响 | ✓ |
| 听力/阅读/语法题 | 不生成，剩余比例转移给词汇题 | ✓ |
| AI 扩词 | 停止，存量词库继续用 | ✓ |
| AI 判题 | 退回 regex，精度略降 | ✓ |
| AI 助手 | 不可用 | ✓ |
| 每日报告 | 静默跳过 | ✓ |
| 先学后考 | 无影响 | ✓ |
| 统计热力图 | 无影响 | ✓ |

**当日目标始终可达。** `GenerateQuestionsIfNeeded` 里 AI 题生成失败 → warn 日志 → 词汇题填满 daily_target。用户感受："今天全是单词题，没出听力和阅读"——不是"软件坏了"。

**前端 StatusBar AI 状态指示器**：绿点（AI 就绪）/ 灰点（不可用）。宕机时不打断流程，但让用户知道。

### 7.3 延迟预算

| 环节 | 目标延迟 | 超时 | 超时行为 |
|------|---------|------|---------|
| exact 判题 | <1ms | — | — |
| regex 判题 | <5ms | — | — |
| AI 判题 | 3-5s | **8s** | 退回 regex |
| AI 出题 | 10-20s | 30s | 退回本地出题 |
| AI 扩词 | 10-20s | 30s | 静默跳过 |
| AI 聊天 | 5-10s | 30s | "AI 暂时无法响应" |

8 秒判题超时：DeepSeek P99 ~4-6s，8s 有足够余量。超过则说明服务出问题，继续等无意义。

**UI 侧**：AI 判题期间按钮 spinner + "AI 评估中..."。超时后显示 regex 结果 + 灰色小字 "AI 响应超时，采用系统规则判定"。用户始终看到反馈，不会卡死。

---

## 8. 数据隐私与 Prompt 保护

### 8.1 最小上下文原则

AI 只获得完成当前任务所需的最小信息，不传完整学习轨迹：

| AI 调用 | 发送内容 | 不发送内容 |
|---------|---------|-----------|
| 判题 | 当前题干 + 期望答案 + 用户答案 + 关联语法点/文章 | 历史错题、正确率趋势 |
| 出题 | 待复习词列表(word/reading/meaning) + 画像(level/goal/focus) | 每个词掌握度、错误次数 |
| 扩词 | 最近已掌握词列表(仅word+meaning) + level | 全词库分布、学习历史 |
| 聊天 | 当前提问 + 画像 context | 历史对话（存本地 SQLite） |

错误模式分析、SM-2 参数、完整学习轨迹全在本地 SQLite，由本地引擎处理。

### 8.2 用户告知

首次引导 API 配置页：`"AI 仅接收当前题目所需的最小上下文。您的完整学习数据保存在本地，不会上传。"`

### 8.3 Prompt 模板保护

**决策：Go `embed.FS` 编译进二进制，不做加密。**

```go
//go:embed prompts/*.yaml
var promptFS embed.FS
```

- 安装目录里不存在 `configs/prompts/judge.yaml`，普通用户不可见
- 不从 Go 二进制提取字符串的竞争对手 → 拿不到 prompt
- 能提取的人 → 本来就有能力自己写 prompt
- 不做加密：没有账号系统，key 无处存放；内存中最终仍是明文

**语种配置文件不 embed**（`languages/*.yaml`）。加语言、改语法点、调题型——这些应对用户开放。

**Prompt 版本化**：每个模板文件内带 `version: "2.3"`。AI 调用日志记录 prompt 版本，质量问题可溯源。

**护城河不止 prompt**：锁屏系统层、SM-2 引擎、TTS/Dict 协议、离线容灾——这些才是复刻不了的东西。

---

## 9. Flutter 桌面

### 目录

```
frontend/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── api/              # HTTP客户端（Dio，按资源拆分）
│   ├── models/           # 数据模型
│   ├── screens/          # 页面（锁屏/引导/完成/逃生）
│   ├── widgets/          # 组件（题目卡/听力播放器/阅读视图/单词表...）
│   ├── providers/        # 状态管理
│   └── utils/            # 工具（音频播放/错误处理）
├── pubspec.yaml
```

### 新题型 UI

- **听力题**：播放按钮 + 选项 + 答后原文折叠
- **阅读题**：scrollable 文章区 + 选项
- **语法题**：语法点标签 + 选项
- 三种题均隐藏单词发音按钮（无关联 word_id）
- AI 判题反馈行：`ai_feedback` 展示

---

## 10. 实施 Phase

| Phase | 内容 |
|-------|------|
| 1 | Go 后端模块化 + HTTP API + TTS/Dict可插拔 + 系统层接口 + 配置校验 + Mock模式 |
| 2 | 5 新功能 + 多语种配置 + prompt 模板 + 幻觉控制 |
| 3 | Flutter 前端 |
| 4 | 集成（进程管理+生命周期+打包） |

## 11. 部署

```
VocabLock/
├── vocablock.exe          # Go 编译
├── flutter_app/
│   └── vocablock_ui.exe   # Flutter 编译
├── configs/               # YAML 配置
├── tts/                   # TTS 二进制
├── dict/                  # 词典二进制
├── data/                  # 运行时数据
└── backup/                # 老代码（Wails+React，不复用）
```

## 12. Mock 模式

`--mock` 启动参数。`api/mock/` 目录下每个 handler 返回假数据：

- 不调 AI、不写 SQLite、不 exec 外部命令
- 返回预设的题目 JSON、单词列表、统计数字
- Flutter Phase 3 开发全程 Mock 模式，不需要 Go 后端真正跑起来

## 13. 将来

- 被动浮窗挂件（Flutter 透明窗口 + Go 定时推送，非锁屏期屏幕角落显示单词卡片）
- 云同步 / 多设备
- 朗读发音评估

---

## 14. 验证

- Phase 1：`go test ./...` 全绿，curl 遍历 API
- Phase 2：各题型 API 返回正确，AI 判题正确降级，词典校验命中/未命中路径
- Phase 3：Flutter UI 完整可用
- Phase 4：两 exe 协同，退出重启正常
