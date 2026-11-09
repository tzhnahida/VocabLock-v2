# VocabLock 工程日志

> 追加式，最新在上。每条固定记录：完成 / 完成方法 / 踩坑 / 失败 / 失败原因 / 剩余 / 规划。
> 代码与测试是事实来源；本文记录过程与决策，不替代审计报告。

## 历史基线（已核实）

| 日期 | 事实 |
|---|---|
| 2026-06-14 | 最后一次提交 c2e31c4（onboarding l10n）；此后工作未提交 |
| 2026-09-02 | ROADMAP：15 项已勾 / 22 项未勾 |
| 2026-10-16 | 30 天仿真：到期池长期远超目标，体感“永远减不下去” |
| 2026-11-08 | 新界面四屏原型；决定 Flutter → Electron |
| 2026-11-10 | 全量代码审计；决定先修数据正确性，再加本地 ASR |

## 2026-11-10 — 安全与稳定性修复（e53b537）

### 完成
- token 不再写入日志，也不再作为 Flutter 命令行参数；Go 通过 stdin 传 token。
- query token 只允许 GET/HEAD /data/audio/；其余 API 只认 Bearer；token 比较改为常量时间。
- 全局请求体上限 16 MiB，AI/TTS/词表/作业/答题等文本字段加独立上限。
- AI key 移到 secrets.yaml（0600），app.yaml 不再包含；Load 自动迁移旧 app.yaml 明文 key；secrets.yaml 加入 .gitignore。
- Windows 锁屏消息循环改为 LockOSThread；ExitLockMode 改为向锁线程 PostMessage(WM_APP+10)；安装 WH_KEYBOARD_LL/WH_MOUSE_LL，吞 Alt+Tab/Win/Ctrl+Esc/Alt+F4/Ctrl+Shift+Esc，保留 Ctrl+Shift+Q；健康检查改 net/http。
- 新增 query token、请求体上限、key 不落 app.yaml、清除 key、旧 key 迁移测试；提交 e53b537 并 push。

### 完成方法
- 先枚举所有 token 入口（日志、argv、query、Dart AppLog），再逐项切断。
- 请求体在 withMiddleware 最外层用 MaxBytesReader；字段上限放在进入 AI/TTS/SQLite 之前。
- 配置写入复制 App 并清空 key；secrets.yaml 单独 0600；Load 读 secrets 后覆盖 env。
- 锁屏问题按 Win32 线程模型修：建窗/消息循环/钩子都在同一 LockOSThread 线程；退出只发消息，不跨线程 PostQuitMessage。
- 用临时 hook 探针验证 SetWindowsHookEx 返回非 0，探针测试用完删除。
- 全量 go test ./...、go vet ./...、flutter test、flutter analyze；go test 改写的 SIMULATION.md 每次还原。

### 踩坑
- 第一次全量 go vet 报 provider_windows.go:539 possible misuse of unsafe.Pointer；用 uptrToPtr 局部转换后通过。
- secrets.yaml 一开始没加入 .gitignore，代码审查时才发现；已补 backend/configs/secrets.yaml。
- go test ./... 仍会重写根目录 SIMULATION.md；本次已 checkout 还原，未混入提交。
- 首次 git push 超时并遇到 Connection was reset；用 HTTP/1.1 + 重试循环后成功，未重复推送已完成的对象。

### 失败
- 首次 go vet 未通过（unsafe.Pointer 误报）。
- 首次 push 失败（连接重置/超时）。

### 失败原因
- Go 的 uintptr→unsafe.Pointer 直接转换触发 vet 的 unsafeptr 检查；需要经过局部变量转换。
- GitHub 直连链路不稳定；不是仓库或认证错误。

### 剩余
- 打包 GUI 实测 token stdin；实机验证锁屏钩子、Alt+Tab/Win+D、Flutter 崩溃自动解锁。
- Ctrl+Alt+Del 无法拦截，需在发布说明中注明。
- 本地 ASR（whisper.cpp）+ 两个对答式造句尚未开始。

### 规划
1. 开 feat/local-asr：ASR provider 最小闭环，复用 16k mono WAV。
2. 接两个“对答式造句”：手敲走文本判分，朗读走 ASR + AI 语义批改。
3. 补前端诊断/作业/被动 UI，最后 Electron M0。

## 2026-11-10 — 基线提交与 P0 数据正确性修复

### 完成
- 基线提交并 push 4 个 commit：26138df、f6e781d、0d30d31、677d029；master 与 origin/master 同步。
- 归档并移除 backend/.git 旧 convo 仓：bundle + 原 .git 移到 _archive（bundle verify 通过）。
- 修完 P0 数据正确性：daily_stats 复合主键迁移、accuracy 改 attempts 分母、read_sentence 目标文本取缓存句子、学习卡跟读 study 语义、AI 缓存 miss 不判错、AI 题 ID 防碰撞、作业主键/提交主题。
- 新增回归测试：旧 daily_stats 表迁移、同日双语写入、attempts 准确率、学习卡跟读不写库、AI 缓存 miss 不写库、read_sentence 目标文本。
- 验证通过：go test ./... 全绿；go vet ./... 0；flutter test 11/11；flutter analyze 0 error（147 warning/info）。
- P0 修改提交 7ff1a94 并 push；master 与 origin/master 同步。

### 完成方法
- 先读调用链和 schema，再改代码；每项修复配一个能复现原 bug 的测试。
- 把 read_sentence 目标文本选择抽成 readAloudTargetText()，用缓存题目直接单测，避免依赖外部发音二进制。
- 学习卡跟读新增请求字段 study，前后端透传；后端在写 SM-2 之前分流，study 只返回评估结果。
- daily_stats 迁移用 PRAGMA table_info 判断主键列数；旧表在事务内重建并复制数据。
- 用固定种子的 30 天仿真回归每日目标/准确率口径。

### 踩坑
- 第一次只拦截“expectedAnswers 为空”的缓存 miss；listening/reading_comp 仍会拿 word.Meaning 判分并推进 SM-2。全量检查调用链后增加 questionRequiresCachedAnswer() 早退。
- flutter 不在 PATH；SDK 在仓库内 flutter/（已被 .gitignore 忽略），需用绝对路径调用。
- 改 onSubmit 函数类型后，test/quiz_flow_test.dart 的两个闭包缺 bool? study，flutter test 编译失败；补参数后通过。
- go test ./... 会重写根目录 SIMULATION.md；两次运行的总答题数出现 575/578 波动，报告不是稳定 golden。已还原 SIMULATION.md，不把生成结果混进 P0 提交。
- flutter analyze 退出码 1 是既有 warning/info，不是编译错误；本次已确认 0 error。

### 失败
- 初次 P0 缓存 miss 修复不完整（只覆盖空 expectedAnswers），被全量测试前的代码复查发现。
- 初次 Flutter 验证失败：测试回调签名与新的 onSubmit 不匹配。
- 仿真报告自动写入导致工作区出现非预期修改；未定位到所有非确定性来源。

### 失败原因
- 只按单个分支现象修补，没有先枚举所有 AI 题型对缓存答案的依赖。
- 函数类型新增可选命名参数后，Dart 的函数子类型不兼容旧闭包，测试替身必须同步签名。
- internal/sim 测试把报告写到仓库根目录，且数据源含非确定性选择；测试不是 hermetic 的。

### 剩余
- P0 安全与稳定性：token、API key、请求体上限、锁屏键盘钩子/线程锁定。
- 本地 ASR provider + 两个对答式造句题型。
- 前端诊断/作业/被动答题 UI；Electron M0–M4。
- 可考虑给 sim 报告写入加 -update 开关，避免普通测试改工作区。

### 规划
1. P0 已提交（7ff1a94），保持工作区可回滚。
2. 再做安全修复；每项给出可复现验证。
3. 开 feat/local-asr，先打通 ASR provider 最小闭环，再接两个题型。
4. 补前端三块 UI，最后 Electron M0 视觉对齐。

## 2026-11-10 — 全量审计、设计归档、本地 ASR 决策

### 完成
- 完成后端 15 个 Go 包 + 前端主要页面/组件的全量审计，输出 docs/AUDIT-2026-11-10.md。
- 把已确认的新界面原型归档到 docs/design/app.html，并复制四张验收截图。
- 用户确认两个“对答式造句”题型：手敲版 + 朗读版；朗读版选本地 ASR，不走云 ASR、不降级跟读。
- 记录当前执行顺序：commit/push → 修 P0 数据 bug → 本地 ASR + 两个新题型 → Electron M0。

### 完成方法
- 逐文件读代码：api/db/engine/ai/config/dict/tts/pronounce/system/frontend。
- 跑 go test ./...、go vet ./...、go test -cover ./...；跑 flutter test、flutter analyze。
- 用临时 Go 测试复现 daily_stats 复合键问题；用同一单词两次答对复现 accuracy=2.00；测试后删除临时文件。
- 用 git status / git rev-parse --show-toplevel / git ls-files 分别检查根仓库与 backend/.git。
- 对前端功能接入做“API 方法 + 调用点 + UI 渲染”三层核对，而不是只 grep 一个字段。
- 把原型和报告复制进仓库 docs/，保证脱离聊天记录也能复现。

### 踩坑
- 一度只 grep errorCategory 就判断“P1 前端 0 接入”，实际 dispute 按钮已接，只有 diagnostics 面板没接。
- 仓库根和 backend/ 各有一个 .git；backend/.git 无 remote 且残留 convo 删除记录，容易提交错仓库。
- backend/CLAUDE.md 仍写“No code has been written yet”“Go modules haven't been initialized”，与现状严重不符。
- flutter analyze 退出码 1 不是编译错误，而是 warning/info；未提交的 CI frontend job 会因此变红。
- read_sentence 看起来有完整代码，实际目标文本取单词、缓存句子永不消费；只看函数名会误判。
- 设计稿最初想做单主题让用户选，用户纠正“双色可切换……包括 l10n”；之后统一为双主题 + 三语。

### 失败
- 审计中期得出过错误结论：把“错因诊断前端未接”扩大成“P1 前端 0 接入”。
- 现有 read_sentence 实际不可用；这不是“没做完”，而是“看起来做完但目标文本错了”。
- 作业提交链路实际不可用：生成返回字符串 ID，DB 主键是整数，CompleteAssignment 永远匹配不到。
- daily_stats 多语言写入会失败；accuracy 分子/分母错配，可大于 1。
- 被动答题只有提醒弹窗，没有题目/作答/提交。
- 浅色主题重启后不生效；配置密码接口 501。
- flutter analyze/CI 当前不是绿色。

### 失败原因
- 前端接入判断只看了单个字段，没查 API 方法和 UI 调用点。
- read_sentence 复用了 SubjectType=word 的分支，targetText 优先取 word.Reading；生成提示词也缺 read_sentence。
- 作业 ID 生成与 DB 自增主键是两套 ID 体系，插入时丢了生成 ID。
- daily_stats 初始 schema 用 date 作主键，后加 language 与复合唯一索引，但旧主键仍在。
- DailyTargetMet 用唯一题数做分母，却用总尝试正确数做分子。
- 被动学习只实现了“提醒”，没有实现答题 UI/提交链路。
- 主题配置只处理 vs-dark，浅色没有写回 themeMode。
- 文档长期未维护，CLAUDE.md 停留在项目初期。

### 剩余
- commit + push 现有 81 modified + 79 untracked；处理 master ahead 3。
- 清理 backend/.git（确认是否废弃）与仓库内 build 产物/临时脚本。
- 修 P0：read_sentence 目标文本与缓存、学习卡跟读语义、daily_stats 复合主键、accuracy 分母、作业 ID、缓存 miss、AI 题 ID 碰撞。
- 修安全：token 不打印/不进命令行、AI key 不落 app.yaml、请求体上限、锁屏键盘钩子/线程锁定。
- 本地 ASR：选型 whisper.cpp / faster-whisper / Vosk；新增 internal/asr provider；两个对答式造句题型。
- 补测试：真实 API、录音、锁屏、主题/语言切换、端到端启动。
- 最后再回 Electron M0–M4；原型 docs/design/app.html 作为视觉验收基线。

### 规划
1. 先保住工作：commit/push，确认仓库根，清掉假 backend/.git 风险。
2. 再修数据正确性：P0 六项 + 统计口径；每项配回归测试。
3. 再做安全与稳定性：token/key/请求体/锁屏线程。
4. 再开 feat/local-asr：先做 ASR provider 与一个最小朗读闭环，再接两个题型。
5. 最后做 Electron：M0 视觉对齐 → M1 壳与握手 → M2 主界面 → M3 锁屏 → M4 打包。
6. 每个阶段结束更新本日志与 docs/AUDIT 的新快照（不追改旧审计）。

## 2026-11-08 — 新界面原型与 Electron 选型

### 完成
- 调研 Apple HIG、Fluent/主流桌面 UI 的共同点，确定单强调色、发丝边框、13px 正文、4/8 间距、234px 侧栏、32px 导航。
- 出四屏可交互原型：home / quiz / library / lock；双主题 + 中/英/日。
- 用户确认四屏设计稿（m00476）。
- 拍板 Electron 34 + electron-vite + React 19 + TS + Tailwind v4 + shadcn/ui + Zustand/TanStack Query。

### 完成方法
- 先用静态 mock 出答题页，再按用户纠正改为单文件可交互 HTML。
- 用 Edge headless 截图验证 2x 渲染（本机无 Chrome）。
- 设计 token 直接写进 CSS 变量，便于后续映射到 Tailwind/shadcn。

### 踩坑
- vision_html_screenshot 报 chrome exited -4058；改用 Edge headless。
- Fluent 2 / shadcn 文档是 JS 渲染，web_fetch 只拿到空壳。
- 最初想做“浅色/深色二选一”，被用户纠正为双主题 + l10n 实时切换。

### 失败
- 没有在 Flutter 里落地新视觉；当前 app_theme.dart 仍是旧 5 套渐变。
- 浅色主题配置在 Flutter 重启后不生效。

### 失败原因
- 设计稿阶段只做原型，未进入实现。
- app_state.dart 只处理 vs-dark，theme/darkTheme 传同一份 themeData。

### 剩余
- Electron M0：脚手架、token、主窗口、设计 token 映射。
- 原型中的 loading/empty/error/窄窗/键盘 focus 规范。

### 规划
- 先完成 P0 数据修复，再开 Electron 分支；避免在坏数据上重做 UI。

## 2026-10-16 — 30 天仿真

### 完成
- internal/sim 用真实 HTTP handler + internal/clock 时间旅行跑 30 天，9 个场景。
- 发现到期池长期 >40（19–28 天），目标 cap 每天只消化 20，体感“池子永远不减”。
- 低正确率场景长期不达标；零 AI/贫词汇有空库死路。

### 完成方法
- 仿真起点 2026-06-01，每日目标 20，门槛 80%，SM-2 最大间隔 180 天。
- 自动诊断输出到期池、达标天数、加权正确率、EF<1.5 词数。

### 踩坑
- 真实 sleep 会把 30 天跑成数小时；clock.Sleep 改为可注入的虚拟等待。
- 时间字段混用 time.Now 与 SQLite datetime('now') 会造成跨日边界错误；统一走 clock。

### 失败
- 仿真结论尚未回写 ROADMAP；池配额 cap 仍未实现。

### 失败原因
- 仿真完成后直接进入其他工作，没有同步文档/待办。

### 剩余
- review 配额 cap、池子进度感、空库引导、低正确率目标自适应。

### 规划
- 放在 P0 数据修复之后、Electron 之前或并行评估。

## 2026-09-02 — ROADMAP 基线

### 完成
- ROADMAP 15 项已勾 / 22 项未勾；P1 错因诊断后端打通（review_log.error_category、judge.Result.ErrorCategory、/stats/diagnostics、/quiz/dispute）。
- 零 AI 准入三态、软上限、自适应目标、空态 UI、面板 smoke 测试。

### 完成方法
- 后端先做数据与接口，再做前端；逐项勾 ROADMAP。

### 踩坑
- “后端已通”被误读成“功能已交付”；前端实际只接了 dispute，诊断面板没接。
- ROADMAP 勾选不等于端到端可用。

### 失败
- P1 前端诊断展示、P2 错题重测、P3 交错化未开工。
- 三条产品决策悬空（锁屏强度自适应、逃生是否无损、自设赌注）。

### 失败原因
- 优先级被前端迁移/仿真/ASR 打断；缺少“端到端验收”定义。

### 剩余
- 见 ROADMAP.md；以代码与审计报告为准。

### 规划
- 每次勾选 ROADMAP 前，至少跑一次对应端到端路径（API + UI + 数据）。
