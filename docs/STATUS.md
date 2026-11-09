# VocabLock 当前状态（2026-11-10）

## 一句话

全量审计已完成，未改业务代码；当前卡在「先 commit + push 保住 4 个月工作」，之后按 P0 数据修复 → 本地 ASR → Electron 的顺序推进。

## 仓库状态

- 路径：F:/Projects/Golang/GitHub/Private/VocabLock-v2
- 分支：master，ahead origin 3（最后提交 c2e31c4，2026-06-14）
- 工作区：81 modified + 79 untracked；新增 docs/ 也在未跟踪列表
- 风险：根仓库与 backend/ 各有一个 .git；backend/.git 无 remote、残留 convo 删除记录

## 已完成

- 新界面原型：docs/design/app.html（双主题 + 中英日，四屏）
- 全量审计：docs/AUDIT-2026-11-10.md
- 设计说明：docs/DESIGN.md
- 工程日志：docs/ENGINEERING-LOG.md
- 决策：Electron 前端；朗读版“对答式造句”走本地 ASR（引擎待定）

## 未完成

| 优先级 | 事项 | 状态 |
|---|---|---|
| P0 | commit + push 现有工作，清理 backend/.git 风险 | 未开始 |
| P0 | read_sentence 目标文本/缓存；学习卡跟读语义 | 未开始 |
| P0 | daily_stats 复合主键；accuracy 分母 | 未开始 |
| P0 | 作业 ID 字符串/整数；缓存 miss；AI 题 ID 碰撞 | 未开始 |
| P0 | token/key/请求体/锁屏线程安全 | 未开始 |
| P1 | 本地 ASR provider + 两个对答式造句题型 | 未开始 |
| P1 | 前端诊断/作业/被动三块 UI | 未开始 |
| P2 | Electron M0–M4 | 未开始 |

## 下一步顺序

1. 用户确认后，先 commit + push；确认仓库根，处理 backend/.git。
2. 修 P0 数据正确性，每项加回归测试。
3. 修安全与稳定性。
4. 开 feat/local-asr，先做 ASR provider 最小闭环。
5. 接两个“对答式造句”题型（手敲 / 朗读）。
6. 最后进 Electron M0：用 docs/design/app.html 做视觉验收。

## 不要做

- 不要在 P0 修完前开 Electron 主界面重写；坏数据上重做 UI 会返工。
- 不要在 read_sentence 仍是“单词评句子”时继续加朗读题型。
- 不要把 app.yaml / token / API key 提交进仓库。
- 不要把 docs/design/app.html 当成已实现界面；它是静态原型。

## 相关文件

- 审计：docs/AUDIT-2026-11-10.md
- 设计：docs/DESIGN.md
- 日志：docs/ENGINEERING-LOG.md
- 原型：docs/design/app.html
