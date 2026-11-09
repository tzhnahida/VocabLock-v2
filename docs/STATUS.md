# VocabLock 当前状态（2026-11-10）

## 一句话

全量审计、P0 数据正确性与安全稳定性修复已完成并 push，Go/Flutter 回归通过。下一步做本地 ASR 与两个“对答式造句”题型，最后进 Electron。

## 仓库状态

- 路径：F:/Projects/Golang/GitHub/Private/VocabLock-v2
- 分支：master；基线、P0 数据修复与安全修复均已 push（最新 e53b537），master 与 origin/master 同步。
- 工作区：docs/STATUS.md、docs/ENGINEERING-LOG.md 随本次文档更新提交；提交后 clean。
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

## 未完成

| 优先级 | 事项 | 状态 |
|---|---|---|
| P0 | 安全与稳定性：token、AI key、请求体上限、锁屏键盘钩子/线程锁定 | 已完成（e53b537） |
| P1 | 本地 ASR provider（whisper.cpp）+ 两个对答式造句题型（手敲 / 朗读） | 未开始 |
| P1 | 前端诊断 / 作业 / 被动答题三块 UI | 未开始 |
| P2 | Electron M0–M4 | 未开始 |

## 下一步顺序

1. 开 feat/local-asr：用 whisper.cpp 做 ASR provider 最小闭环（外部二进制，16k mono WAV）。
2. 接两个“对答式造句”题型：手敲走文本判分；朗读走 ASR + AI 语义批改。
3. 补前端诊断 / 作业 / 被动 UI。
4. 最后进 Electron M0：用 docs/design/app.html 做视觉验收。

## 不要做

- 不要在安全/ASR 改动未提交/未评审时开 Electron 主界面重写。
- 不要把 app.yaml / token / API key 提交进仓库。
- 不要把 docs/design/app.html 当成已实现界面；它是静态原型。
- 不要再让学习卡跟读写 SM-2，或让 AI 缓存 miss 当答错。
- 不要在未接 ASR 时声称“朗读版对答式造句”可用。
- 锁屏无法拦截 Ctrl+Alt+Del（Windows 安全注意序列），不要声称能完全锁死系统。
- token stdin 与锁屏钩子尚未在打包 GUI 实机回归，发布前必须验证。

## 相关文件

- 审计：docs/AUDIT-2026-11-10.md
- 设计：docs/DESIGN.md
- 日志：docs/ENGINEERING-LOG.md
- 原型：docs/design/app.html
