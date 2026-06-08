# VocabLock v2 — 完整项目思路

## 定位

一个 **AI 驱动的语言学习系统**。不是背单词 App，是一个尽力替代真人语言教师角色的软件。

核心假设：真人老师的核心能力——知识传递、即时纠错、记忆调度、跨 session 追踪——都可以被 AI + SM-2 + 数据库替代。

## 架构

```
Go 后端（HTTP API） ←→ Flutter 桌面 UI
         │
         ├── AI（deepseek）：出词、出题、评判、总结、情景对话
         ├── SM-2：记忆调度，决定今天复习什么
         ├── SQLite：词库、语法点、学习记录
         └── 外部二进制插件：
              ├── 字典（社区提供，如 jamdict）
              ├── TTS（社区提供，如 edge-tts）
              └── 发音评判（社区提供，如 julius）
```

插件协议：Go 不实现字典/语音，只做调度+缓存。社区按协议写脚本，零 Go 改动接入。

## 学习闭环

```
首次启动 → 培养方案（AI 面试）
    ↓
每日学习：
    1. AI 出词（按方案方向） → 字典验证 → level 过滤 → 入库
    2. 新词跟读（学习卡片，每张录音，发音评判，算 1 题）
    3. SM-2 复习出题（choice/fill/spelling/pronounce/grammar/listening/reading_comp）
    4. AI 总结 → 标签 → 更新培养方案
    ↓
第二天循环
```

关键原则：
- 字典是 gate，不是词源。AI 出词，字典验证
- SM-2 管复习，AI 管新学
- 复习量够就不出新词，不够再由 AI 出
- 研究-后考（study-before-test），跟读不算 SM-2

## 题目体系

| 类型 | 生成方式 | 评判方式 | AI 依赖 |
|------|---------|---------|--------|
| choice | 本地模板+干扰词 | exact | 无 |
| fill | 本地模板 | exact→regex→AI | 最低 |
| spelling | 本地模板 | exact | 无 |
| pronounce | 本地模板（看词写假名） | exact | 无 |
| read_word | 本地模板 | 外部发音评判 | 无 |
| read_sentence | AI 生成 | 外部发音评判 | 高 |
| grammar | AI 生成 | AI 评判 | 高 |
| listening | AI 生成 | AI 评判 | 高 |
| reading_comp | AI 生成 | AI 评判 | 高 |

核心词类题（choice/fill/spelling/pronounce）零 AI 依赖。AI 挂了也能完成每日目标。

## SM-2 调度

```
新词(NULL) → tier 0: choice, pronounce, read_word
答对 interval=1 → tier 1: choice, fill, pronounce, read_word
答对 interval=6 → tier 2: fill, pronounce, spelling
答对 interval>14, reps≥4 → tier 3: 全类型
答错 → interval=1, reps=0 → tier 1
```

## AI 能替代什么

| 能力 | 替代程度 | 实现方式 |
|------|---------|---------|
| 词汇记忆调度 | 100% | SM-2 超越人类 |
| 发音音素评分 | 100% | 外部二进制，机器比人精确 |
| 即时批改 | 100% | 3 层评判 + AI 解释 |
| 错题追踪 | 100% | 数据库 |
| 固定题型生成 | 100% | 模板+AI |
| 非线性教学 | 90% | 培养方案+session总结+SM-2历史 |
| 文化认知 | 80% | prompt注入文化上下文+情景对话 |
| 输出驱动 | 80% | 情景对话+自由输出+AI评价 |
| 情感连接 | 0% | 无解 |
| 创造力 | 20% | AI 平均最优，无法即兴 |
| 责任心 | 0% | 人对自己负责 |

## Phase 4：锁屏与被动学习（P4 — 来自 v1 规划）

v1 的核心功能，v2 尚未实现：

### 锁屏机制
- Go 创建 Win32 TOPMOST 全屏窗口，遮住整个桌面
- 每日目标未完成 → 不解锁
- 三层逃生：
  1. Ctrl+Shift+Q 全局热键（Flutter FFI 注册 Win32 热键）
  2. Go 死手开关（锁屏窗口 10s 自检 HTTP 健康，3 次失败 → 画倒计时 + "退出"按钮）
  3. Ctrl+Alt+Del（Windows SAS，系统级）

### 系统托盘
- 后台运行，最小化到托盘
- 被动弹窗：SM-2 到期的词，随机间隔弹出小窗
- 弹窗显示单词 → 用户自评（easy/hard/forgot）→ 更新 SM-2
- 间隔可配（默认 25-60 分钟）

### 紧急逃生
- 密码逃生（每日限 1 次）
- 连击点击逃生（每日限 2 次）
- 超出限制 → 无解，必须完成学习

### 进程模型
```
VocabLock.exe (Go)
  ├── HTTP REST server（随机端口）
  ├── Lock screen（Win32 TOPMOST）
  ├── System tray（独立 OS 线程）
  └── spawn Flutter UI（子进程）
```

### 健康监控
- Flutter → Go：GET /health 每 3s，2 次超时 → 恢复流程
- Go → Flutter：进程存活性检查每 5s，挂了 → 自动解锁 + 日志

### 恢复（3 种崩溃场景）
| 场景 | 锁屏窗口 | 用户状态 | 恢复 |
|------|---------|---------|------|
| Go panic | 存活，HTTP 死 | 锁住 | Flutter 显示"服务中断" + 强制退出按钮 |
| Go 硬崩溃 | 销毁 | 解锁 | Flutter 显示"重启应用" |
| Go 挂起 | 存活，HTTP 超时 | 锁住 | 同 panic |

## 未来方向

### 近期
- 学习卡片跟读流程（强制录音，发音评判，计入 daily_target）
- 情景对话模式（替代 listening/reading_comp，STT+TTS+角色扮演）
- 语境纠错（替代 correct/incorrect 二值，带解释和纠正建议）

### 中期
- 输出驱动题目（"用日语描述你昨天做了什么"，AI 评价）
- 图片描述题目（多模态，给图说话）
- 跨 session 薄弱点分析（"你的「て形」已经错了 17 次了"）

### 长期
- 自适应学习路径（AI 分析错误模式，动态调整培养方案方向）
- 多语言无缝切换
- 社区插件市场（字典/TTS/发音评判一键安装）

## 社区插件生态

VocabLock 的核心不碰语音和字典——只定义协议，由社区提供实现。

```
字典协议: --word {word} → stdout JSON → exit 0/1
TTS 协议: --voice {voice} --text {text} --write-media {output} → exit 0
发音协议: --audio {path} --text {target} → stdout JSON → exit 0
```

当前参考实现：
- 字典：jamdict.db + jlpt.csv（366K 中文释义 + N1-N5 分级）
- TTS：edge-tts（Microsoft 免费 TTS）
- 发音：julius（开源日语音素识别）
