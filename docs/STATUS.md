# VocabLock 当前状态（2026-11-10）

## 一句话

全量审计、P0 数据正确性与安全稳定性修复已完成并 push；本地 ASR provider 与两个“对答式造句”题型已实现，并已用真实 whisper.cpp 二进制 + 模型实机验证中英日识别、90s 超时与失败分支（修复提交 b1e15af）。前端诊断 / 作业 / 被动三块 UI 已补齐（2026-11-17，接口与 widget 级验证通过，尚未真人点过）。下一步进 Electron M0。

## 仓库状态

- 路径：F:/Projects/Golang/GitHub/Private/VocabLock-v2
- 分支：master；基线、P0 数据修复、安全修复、ASR/对答式造句、ASR 实机修复均已提交（代码最新 b1e15af），master 与 origin/master 同步。
- 工作区：clean；go test 若改写 SIMULATION.md，提交前必须还原。
- backend/.git 已归档：F:/Projects/Golang/GitHub/Private/_archive/VocabLock-v2-backend-git-20261110.bundle（及 .git 原目录）。
- 仓库内 flutter/ 是本地 Flutter SDK，已被 .gitignore 忽略，不提交。
- 风险：core.autocrlf 导致提交时大量 LF→CRLF 警告；backend/scripts/deploy-pi.sh 在 Pi 上执行前需确认换行。

## 已完成

- 基线提交与 push：26138df、f6e781d、0d30d31、677d029；4 个多月未提交工作已保住。
- P0 数据正确性修复提交并 push：7ff1a94（15 files，+481/-128）。
- 新界面原型：docs/design/app.html（双主题 + 中英日，四屏）
- 全量审计：docs/AUDIT-2026-11-10.md
- 设计说明：docs/DESIGN.md
- 工程日志：docs/ENGINEERING-LOG.md
- P0 数据正确性（代码 + 回归测试）：
  - daily_stats 改为 (date, language) 复合主键，旧库自动迁移。
  - 达标准确率分母改为总尝试数（attempts），不再用唯一题数。
  - read_sentence 目标文本只从 AI 题缓存取句子，缺缓存返回 no_target，绝不退化用单词读音。
  - 学习卡跟读传 study=true：只评估，不写 SM-2 / review_log / daily_stats / 解锁；系统错误也不再按答错推进 SM-2。
  - AI 题缓存 miss（listening / reading_comp / grammar）返回 cache_miss，不判错、不写库。
  - AI 题 ID 改为完整题型（ai-<type>-<wordID>），消除 read_sentence / reading_comp 的 ai-r- 碰撞。
  - 作业使用 DB 自增主键作为对前端 ID；提交按 assignment_id 查该作业的 Prompt/Context，CompleteAssignment 用 int64 并检查错误。
- 验证：cd backend && go test ./... 全绿（sim 21.4s）；go vet ./... 0 问题；cd backend/frontend && flutter test 11/11；flutter analyze 0 error（147 warning/info，退出码 1 为既有告警）。
- 安全与稳定性（提交 e53b537）：
  - token 不再打印，也不进 Flutter 命令行；Go 通过 stdin 传给 Flutter。
  - query token 只允许 GET/HEAD /data/audio/；其余路径只认 Bearer，token 比较改常量时间。
  - 全局请求体上限 16 MiB；AI chat、TTS、词表导入、作业/答题答案、标签等文本字段另有上限。
  - AI key 移到 secrets.yaml（0600），app.yaml 不再包含；启动时自动迁移旧 app.yaml 明文 key。secrets.yaml 已加入 .gitignore。
  - Windows 锁屏：消息循环 LockOSThread；退出改为向锁线程 PostMessage(WM_APP+10)；装 WH_KEYBOARD_LL/WH_MOUSE_LL，吞 Alt+Tab/Win/Ctrl+Esc/Alt+F4/Ctrl+Shift+Esc，保留 Ctrl+Shift+Q 紧急退出；健康检查改 net/http。
  - 新增回归测试：query token 边界、请求体上限、key 不落 app.yaml、清除 key、旧 key 迁移。
- 本地 ASR + 对答式造句（提交 1b1b06d）：
  - backend/internal/asr：Provider 接口 + whisper.cpp provider（外部二进制，16k mono WAV，支持 -m/-f/-otxt/-of/-nt、语言、线程、超时、Args 模板）；config 读 configs/asr.yaml，缺省禁用；Server.WireASR/HasASR 接线；asr.yaml.example 与 .gitignore。
  - 新题型 dialogue_write / dialogue_speak：tier2 加手敲、tier3 加朗读；ASR 不可用时不进朗读题；题型权重 4/5 并计入慢题；validator 与语言配置同步。
  - AI 生成情境问句 + 参考句；judge prompt 支持 Scenario，按目标语言完整句、用目标词、语义自然度判分，接受改写；朗读输入为 ASR 文本，忽略轻微识别误差。
  - 提交分流：手敲走文本；朗读先 ASR（90s 超时），no_asr / asr_error / bad_audio / cache_miss / ai_error 均不写 SM-2 / review_log / daily_stats；空答按 empty 计错；成功才落库并返回 transcript / expected_answer。
  - Flutter：QuestionType 两新值、SubmitResult 带 transcript/expected_answer、口头造句录音 UI、结果卡显示识别结果与参考句、中英日 l10n；mock 数据同步。
  - 验证：go test ./... 全绿（sim 18.9s）；go vet ./... 0；flutter test 11/11；flutter analyze 0 error（149 warning/info）。
- ASR 实机验证（提交 b1e15af）：
  - 本地安装 whisper.cpp v1.9.2（whisper-bin-x64，backend/bin，含 DLL）与 ggml-base.bin（142MB，backend/models）；backend/configs/asr.yaml 配 provider=whisper、timeout_sec=90。三者均被 gitignore。
  - Windows SAPI 生成 16k mono WAV 三语样本；显式 -l 识别：en “Smart phones have become ubiquitous in modern life.”（约 1.1s）、zh “今天天氣很好,我們一起去公園散步吧。”（繁体，约 1.2s）、ja “今日はとてもいい天気ですね。一緒に公園へ3歩に行きましょう。”（散歩→3歩，约 1.3s）。
  - 发现 language: auto 会把清晰的中日语音判成英语并翻译；WireASR 改为 resolveASRLanguage：auto/空跟随 active_lang（去掉 -CN 等后缀），显式 en/ja/zh 仍为 override。当前 active_lang=ja，真实 config 解析为 ja。
  - 73.6s 长音频 + provider timeout 1s：1013ms 被杀进程并返回错误；handler 90s deadline 由测试断言。
  - 合法 base64 但非 WAV 的 payload 会让 whisper 退出 0、返回空文本，原来会被当成 empty 记错；现加 RIFF/WAVE 头校验，归为 bad_audio。
  - 新增 dialogue_asr_test.go：语言解析、90s deadline、no_asr/bad_base64/bad_wav/asr_error 不写库、asr_empty 记 1 条错、cache_miss 不调 ASR。
  - 验证：go test ./... 全绿（sim 20.6s）；go vet ./... 0。
- 前端诊断 / 作业 / 被动 UI（2026-11-17）：
  - 诊断面板：StatsApi.getDiagnostics + models/diagnostics.dart + widgets/diagnostics_panel.dart，侧栏可进入；覆盖 / 错因分布 / 弱音素 / AI 分歧 / 题型准确率，7-30-90 天窗口。
  - 被动面板：widgets/passive_panel.dart，取到期词→回忆→翻面→记得/有点难/忘了→下一条；提交带 {word_id, recall}（此前 POST 空 body，后端只 ack 不写库）。
  - 作业：空态按后端 reason（no_due / ai_required / generation_failed）+ next_due_at 出文案；加载与提交失败不再被吞掉。
  - 后端：handleSystemPassiveSubmit 的 review_log 补 language / subject_type / subject_id（否则诊断与单词历史都看不到被动作答）；/quiz/assignment 三个空态加 reason。
  - l10n：新增 40 键 ×3 语言，并补齐 zh/ja 原先缺失的 10 个旧键（expandStatus*、quizGoal*）。
  - 修 .gitignore：backend/.gitignore 的裸 models/ 会吞 backend/frontend/lib/models/，根 test/ 会吞 backend/frontend/test/；改为 /models/ 与 /test/，把此前从未入库的 panel_smoke_test.dart、quiz_flow_test.dart 补进仓库。
  - 验证：flutter test 18/18（新增 diagnostics_test、api_live_test、两个面板 smoke）；flutter analyze 0 error（149 warning/info，新文件 0 条）；go vet 0；go test ./... 全绿（sim 23.4s）。
- 真机 UI 回归（2026-11-17 补记）：
  - 隔离副本启动真实构建（exe + Release + configs/data 副本，副本里 daily_target=0 防锁屏、passive 关闭），真实数据未动。
  - 截图 + 视觉核对发现真 bug：720p 下 10 个工具塞不进 72px 侧栏，诊断/被动被挤出可视区且无滚动提示 → 条目 56→44、图标 22→20、常显 Scrollbar；修后截图确认 10 项齐全。
  - 桌面自动化限制（记录在案）：Flutter Windows 的 UIA 树只有窗口层，headless 鼠标 POLICY_DENIED，PostMessage 的 WM_LBUTTON* 被 WM_POINTER 管线忽略，真实输入需要前台而用户正在用电脑 → 改用「截图 + 视觉」与「widget 级真 tap」两条不抢焦点的路。
  - 新增 home_flow_test：1280x720 下 pump 真实 HomeScreen + 真 loopback HTTP server，点诊断、翻被动卡并评分、开作业面板，断言新入口在可视区内。
  - 验证：flutter test 19/19；flutter analyze 0 error（150 warning/info）。

- Electron M0（2026-11-17，按 docs/design/app.html 重构 UI）：
  - 新前端放在 electron/（Electron 34 + electron-vite + React 19 + TS）。样式与三语文案由 scripts/extract-design.mjs 从原型直接抽取（design.css / i18n.json），不手抄，避免与设计稿漂移。
  - 四屏落地：home（今日目标环、近 7 天柱状、最近学过、连续天数、待复习、薄弱项、快捷操作）、library（搜索 + 状态筛选 + 表格 + 右侧详情）、quiz（题卡 + 右侧 rail + 键位提示）、lock（全屏专注遮罩）；另有 stats 简版（题型准确率 + 词汇覆盖）。
  - 导航回到设计稿的 6 项（学习 / 词库 / 听力 / 统计 / 设置 + 更多：AI 对话），侧栏 234px；听力、设置、AI 暂标灰（M2）。
  - 数据接真：config/languages、quiz/progress、quiz/today-stats、stats/streak、stats/heatmap、words、stats/diagnostics；连不上回落演示数据，标题栏标 demo。
  - 新增 headless 通路 backend/cmd/devserver：只起 HTTP、不拉 UI、不碰锁屏/托盘，打印 {"port","token"}；Electron 接受与 Flutter 相同的 --api-port/--auth-token，主进程替换留到 M4。
  - 验证：真实数据库副本（ja，127 词）跑通 home/library 截图；浅色/深色、中/英/日均可渲染；npm run build 通过。

- Electron M1（2026-11-17，答题回路接真）：
  - quiz 屏走真接口：session/start → next → submit → next；preparing / empty / daily_completed / error 四种分支各有独立状态与重试。
  - 选择题 1–4 作答，填空/发音题输入框 + Enter；反馈显示对错、服务器 feedback、正确答案、下次复习日期；AI 判错且带 log_id 时出现「我觉得判错了」申诉。
  - 每答一题刷新侧栏与主页计数，不再等下次启动。
  - 验证（CDP 驱动真实 UI + 真实服务，数据来自副本库）：道 输入 みち → 反馈「正确 · 下次复习：2026-11-23」，review_log 319→320（type=pronounce / source=exact / language=ja），词条 reps 2、interval 6、EF 2.7；再答错 → 「正确答案: みぎ · 下次复习：2026-11-18」，next 可用。
  - 新增 --nowindow：无窗口 + CDP 可脚本化操作界面（不抢前台）。
  - 词库转可写：添加词（对话框）、编辑（含删除）、加入复习（重置进度后进今日队列）；保存/失败都有提示，操作后刷新表格与计数。
  - 设置屏：课程语言、每日目标题数、达标准确率、AI 扩词开关、界面语言、主题、AI（base_url / model / API Key，留空不覆盖），一次保存写 app.yaml 与 secrets.yaml。
  - 验证（CDP + 真服务）：每日目标 20→25、主题切浅色后保存 → 界面回显「已保存」，app.yaml 实际写入 daily_target: 25 / theme: vscode-light；interface_lang 由 zh-CN 归一为 zh 写入。
  - 启动链路：Go 新增 `--shell=electron`；resolveElectron 先找打包产物（vocablock-desktop.exe），再找仓库里的 electron/ 检出；token 走环境变量 VOCABLOCK_AUTH_TOKEN（不进 argv），Electron 侧已实测能用 env token 拿到真数据。resolver 有 3 个单测。
  - 截图管线修复：隐藏窗口在无 DevTools 附着时不重绘 → 截图模式改为离屏窗口 + showInactive，等 .app 挂载后 capturePage。
  - 听力屏：单词朗读（/tts/word/{id}）、任意文本朗读（/tts/text）、原文隐藏/显示、词表切换。音频用 fetch+blob 播放（file:// 页面加载 http 媒体会被 Chromium 的 URL safety check 拒掉）。
  - TTS 诊断：之前记录的 exit status 3 是临时目录缺 backend/tts 脚本；真实原因是 edge-tts 7.2.8 被 Microsoft 拒（WSS 403），升级到 7.3.1 后正常。实测播放：currentTime 0.07→1.49→1.56s 结束，readyState 4。
  - 验证（CDP）：添加 → 表格与库内出现新词（127→128）；编辑 → 释义写入并回显；删除 → 词条消失（128→127）。测试数据已还原。

## 未完成

| 优先级 | 事项 | 状态 |
|---|---|---|
| P0 | 安全与稳定性：token、AI key、请求体上限、锁屏键盘钩子/线程锁定 | 已完成（e53b537） |
| P1 | 本地 ASR provider（whisper.cpp）+ 两个对答式造句题型（手敲 / 朗读） | 已完成（1b1b06d + b1e15af 实机验证） |
| P2 | ASR 外挂组件的安装引导（首次运行提示 + 设置页 provider 状态） | 未开始 |
| 可选 | 发行时附带 ASR 组件包（whisper-cli+DLL+模型，单独 zip 或安装器附加项） | 产品决策，未开始 |
| P1 | Flutter 麦克风→HTTP→ASR 整链路人工回归（真人录音） | 未开始 |
| P1 | 前端诊断 / 作业 / 被动答题三块 UI | 已完成（2026-11-17；工具驱动回归：真机构建+截图、widget 真 tap；未做人眼审美验收） |
| P2 | base 模型中日语有识别误差，发布前评估 small | 待评估 |
| P2 | Electron M0（设计稿四屏 + 真数据） | 已完成（2026-11-17） |
| P2 | Electron M1 答题回路（session/next/submit/complete） | 已完成（2026-11-17） |
| P2 | Electron M1 词库增删改（对话框） | 已完成（2026-11-17） |
| P2 | Electron 设置屏（课程/目标/主题/AI） | 已完成（2026-11-17） |
| P2 | Electron M4 启动切换 + electron-builder 打包 | 已完成并实跑（2026-11-17）：Go 起打包的 vocablock-desktop.exe，asar 内页面挂载、6 个导航、随服务退出 |
| P2 | Electron M3：系统级锁屏（现在是应用内覆盖层） | 未开始 |
| P2 | Electron 托盘 / 单实例 / 开机自启（Go 端已有，Electron 未接） | 未开始 |
| 可选 | 移除 Flutter 前端（55 个 dart 文件） | 等 Electron 功能对齐 |
| P2 | Electron 听力屏（单词朗读 + 任意文本朗读） | 已完成（2026-11-17，真机出声） |
| P2 | Electron AI 对话屏（/ai/chat；/ai/profile 未接） | 已完成（2026-11-17，真 key 实跑：日语回答 + 中文讲解） |
| P1 | AI 对话改为课程内对话（不再反问"想学哪门语言"） | 已完成（2026-11-17，prompt v2.4） |
| P1 | 解耦：讲解语言独立于界面语言；提示词无硬编码语言；UI 文案统一 strings.ts | 已完成（2026-11-17，见 DESIGN.md「解耦约束」） |
| P0 | Electron 录音答题（read_word / read_sentence / dialogue_speak） | 已完成（2026-11-17，真机麦克风→WAV→判分） |
| P1 | Electron listening 题型的音频播放 | 已完成（2026-11-17）：自动播放 + 重听 + 隐藏词形 + TTS 缺失提示 |
| P2 | Electron 作业（首页卡片）/ 待审词（词库面板）/ 被动回忆（统计卡片） | 已完成（2026-11-17） |
| P2 | Electron 每日报告、语法点 CRUD、词库 import/export/tags | 未开始 |
| P2 | Electron 词库高级：import / export / expand / tags；语法点 CRUD | 未开始（后端接口齐全） |
| P2 | Electron 配置页：tts / dict / language / password provider 明细 | 未开始 |

## 下一步顺序

1. Electron M1：把 quiz 的提交/SM-2 回路接上（现在只本地判分，不落库），词库编辑与「添加词」。
2. 补齐听力 / 设置 / AI 对话三屏；主进程把 spawnFlutter 换成 Electron 并打包（electron-builder）。
3. 补外挂组件的安装引导：设置页显示各 provider（TTS / 词典 / 发音 / ASR）是否已接线及期望路径；是否随安装器附带 whisper 组件包是产品决策，不是架构要求。评估用 small 替换 base 以降低中日语识别误差。

## 不要做

- 不要在安全/ASR 改动未提交/未评审时开 Electron 主界面重写。
- 不要把 app.yaml / token / API key 提交进仓库。
- 不要把 docs/design/app.html 当成已实现界面；它是静态原型。
- 不要再让学习卡跟读写 SM-2，或让 AI 缓存 miss 当答错。
- 不要把 language: auto 当默认；whisper 会把清晰的中日语音判成英语并翻译。
- 不要把 ASR 二进制/模型当成源码的一部分：它们是**外挂二进制**（与 TTS / 词典同一套 provider + YAML 机制），backend/bin、backend/models、backend/configs/asr.yaml 被 gitignore 是设计如此；运行时 main.go 先 chdir 到 exe 目录，配置里的 bin/、models/ 就相对 exe 解析。
- 不要以为缺了 ASR 组件会坏：WireASR 找不到 provider 时只是不接线，朗读类题型自动隐藏，其余闭环照常。缺的是“告诉用户为什么”，不是“打包进去”。
- 不要把本次后端 provider 实机验证当成 Flutter 麦克风整链路已验证；录音权限、WAV 格式、提交链路仍需真人跑一遍。
- 不要把诊断 / 作业 / 被动面板的 widget 与真 HTTP 测试当成 UI 已验收：排版、节奏、真实数据下的长文案都没被真人看过。
- 不要在 .gitignore 里写裸 `models/` 或 `test/`：前者会吞 backend/frontend/lib/models/*.dart，后者会吞 backend/frontend/test/*（已踩过，已修）。
- 不要以为被动作答会进每日目标：它只写 SM-2 + review_log（source=passive），不写 daily_stats。
- 不要把 base 模型的中日语识别当成零误差；ja 实测有 散歩→3歩，发布前评估 small。
- 锁屏无法拦截 Ctrl+Alt+Del（Windows 安全注意序列），不要声称能完全锁死系统。
- token stdin 与锁屏钩子尚未在打包 GUI 实机回归，发布前必须验证。

## 相关文件

- 审计：docs/AUDIT-2026-11-10.md
- 设计：docs/DESIGN.md
- 日志：docs/ENGINEERING-LOG.md
- 原型：docs/design/app.html
