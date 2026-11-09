# VocabLock v2 — 项目总结

## 一句话

AI 驱动的语言学习系统。不是 ChatGPT 套壳——AI 是工人，SM-2 是调度，字典是 gate，插件是生态。

## 是什么

- **Go 后端** HTTP REST API（随机端口，token 鉴权）
- **Flutter 前端** 桌面 UI（Windows，被 Go spawn 为子进程）
- **SQLite** 词库 + 语法点 + 学习记录
- **AI**（DeepSeek）出词、出题、评判、总结、情景对话
- **外部二进制插件** TTS / 词典 / 发音评判——Go 不实现，只调度

## 学习闭环

```
首次启动 → AI 面试生成培养方案
    ↓
每日：
    1. SM-2 取到期复习项 → 够就不扩词，不够 AI 出新词
    2. 新词 → 字典验证 → level 过滤 → 入库
    3. 学习卡片（跟读，发音评判，每张 1 题）
    4. 答题循环（9 种题型，SM-2 tier 分层）
    5. AI 总结 → 更新培养方案
    ↓
第二天循环
```

## 关键设计

| 决策 | 为什么 |
|------|--------|
| 字典 gate | AI 会编词，字典是唯一真相源 |
| SM-2 管复习 | 机器比人更懂间隔 |
| AI 管新学 | 按培养方案方向扩展 |
| 零 AI 降级 | core 题型不用 AI，挂了一样完成目标 |
| 插件协议 | 字典/TTS/发音社区提供，Go 零改动 |
| 零配置启动 | 内置 4 种语言，无 YAML 也能跑 |
| 禁止硬编码 | 除 AI prompt 英语外，一切走配置/l10n |

## 题目体系

| 类型 | AI 依赖 | 生成 | 评判 |
|------|--------|------|------|
| choice | 无 | 本地模板 | exact |
| fill | 最低 | 本地模板 | exact→regex→AI |
| spelling | 无 | 本地模板 | exact |
| pronounce | 无 | 本地模板（看词写假名） | exact |
| read_word | 无 | 本地模板 | 外部发音 |
| read_sentence | 高 | AI | 外部发音 |
| grammar | 高 | AI | AI |
| listening | 高 | AI | AI |
| reading_comp | 高 | AI | AI |

## SM-2 分层

```
tier 0 (新词)  → choice, pronounce, read_word
tier 1 (早期)  → choice, fill, pronounce, read_word
tier 2 (中期)  → fill, pronounce, spelling
tier 3 (成熟)  → 全类型
答错          → 回到 tier 1, interval=1d
```

## 当前进度

| 模块 | 状态 |
|------|------|
| 后端 API | ✅ 全量 |
| SM-2 引擎 | ✅ |
| AI 出词+字典验证 | ✅ |
| Level 过滤 | ✅ |
| 9 种题型 | ✅ |
| 前端 l10n（3 语） | ✅ |
| 日常学习流程 | ✅ |
| 每日目标上限 | ✅ |
| 零配置启动 | ✅ |
| 发音评判 | ✅（julius） |
| 字典（jamdict+JLPT） | ✅ |
| TTS | ✅（edge-tts） |
| 锁屏+托盘+被动弹窗 | ✅ P4 完成 |
| 例句三轮校验 | ✅ |
| 自动锁屏/解锁 | ✅ |
| 学习卡片跟读 | 📋 待做 |
| 情景对话 | 📋 待做 |
| 语境纠错 | 📋 待做 |
| 输出驱动 | 📋 待做 |
| 测试覆盖 | 📋 待补 |

## 代码规模

~38,000 行（Go + Flutter），不含外部数据

## 社区插件协议

```
字典: --word {word} → stdout JSON → exit 0/1
TTS:  --voice {v} --text {t} --write-media {out} → exit 0
发音: --audio {p} --text {t} → stdout JSON → exit 0
```

参考实现：jamdict.db（366K 中文释义）+ edge-tts + julius

## 项目评价

**做对了的：**
- 不是 ChatGPT wrapper——AI 是工人不是产品
- SM-2 + AI 分工清晰，互不越界
- 字典 gate 杜绝幻觉污染词库
- 零 AI 降级保证可用性
- 插件协议开放社区生态
- 零配置降低入门门槛

**需要补的：**
- 前端交互复杂度（题型越多 Flutter 越吃力）
- 无测试覆盖（API 层和前端）
- prompt 质量无评测体系

**真正的护城河：**
对"AI 在教育中该做什么"的认知——这不是技术问题，大部分竞品永远想不明白为什么不是套壳聊天就行。
