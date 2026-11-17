# VocabLock 新界面原型（2026-11-08）

## 状态

- 用户已确认四屏设计稿（m00476，2026-11-08）。
- 这是 Electron 前端的视觉目标，不是当前 Flutter 界面的实现。
- 原型是静态 mock，不连后端；真实数据/交互在 Electron M0–M2 落地。
- 双主题 + 中/英/日三语是默认真实能力，不再询问用户选浅色还是深色（m00190 用户纠正）。

## 解耦约束（2026-11-17）

四条硬约束，改代码时别破坏（破坏会被下面的守卫或检查抓到）：

1. **学习语言与提示词解耦**
   - `internal/ai/prompts/*.yaml` 不允许出现具体语言名（日本語/中文/English…），只能用变量 `{{.TeacherRole}}`、`{{.Language}}`、`{{.Level}}`、`{{.ExplanationLang}}`。
   - 检查：`grep -P '[\x{4e00}-\x{9fff}]' internal/ai/prompts/*.yaml` 应为空。
   - 反例（已修）：chat.yaml 曾写死「先问学生想学哪门外语」+ 中文培养方案标题。

2. **提示词与界面语言解耦**
   - 讲解语言由 `app.yaml: ai_explanation_lang` 决定，空值才回落到课程配置 `prompt_context.explanation_lang`，最后 `en`。
   - `Server.aiExplLang()` **不再读 `interface_lang`**：界面切日语 ≠ AI 用日语讲解。
   - 设置页「讲解语言」（跟随课程 / 中文 / English / 日本語）。实测 ja 课程：=en 回英文、=ja 回日文、空=中文。

3. **工具与框架解耦**
   - 渲染层组件只 import hooks 与 `*Api` 模块（纯 fetch），不 import `electron`；窗口能力只经 preload 的 `window.vocablock`。
   - 服务端 TTS / ASR / 词典 / 发音评分全部配置驱动（tts/asr/dict/pronounce.yaml），换实现不动 Go。

4. **UI 必须 i18n**
   - 设计稿文案在 `i18n.json`（由 docs/design/app.html 抽取，不手改）；新增文案统一进 `electron/src/renderer/src/strings.ts`，zh/en/ja 共用同一 key 类型（缺翻译 = 类型错误）。
   - 组件内不内联文案：`grep -P '[\x{4e00}-\x{9fff}]' --include='*.tsx'` 只允许注释。
   - 每个屏幕必须有 `body[data-screen="x"] .s-x` 规则，`scripts/check-screens.mjs` 在 `npm run typecheck` 时检查（漏写会导致整屏空白，真实发生过）。

## 文件

| 文件 | 说明 |
|---|---|
| docs/design/app.html | 可交互原型，单文件、无外部依赖 |
| docs/design/screenshots/home-zh-light.png | 首页浅色（中文） |
| docs/design/screenshots/home-zh-dark.png | 首页深色（中文） |
| docs/design/screenshots/lib-en-light.png | 词库浅色（英文） |
| docs/design/screenshots/quiz-zh-light.png | 答题页浅色（中文） |
| docs/design/screenshots/quiz-ja-dark.png | 答题页深色（日文） |
| docs/design/screenshots/lock-ja-dark.png | 锁屏深色（日文） |

原始产物：F:/Projects/VocabLock-design/app.html；本次归档复制到 docs/design/app.html。

## 打开方式

直接用浏览器打开 docs/design/app.html，或带参数：

~~~text
docs/design/app.html?screen=home&theme=light&lang=zh
docs/design/app.html?screen=quiz&theme=dark&lang=ja
docs/design/app.html?screen=library&theme=light&lang=en
docs/design/app.html?screen=lock&theme=dark&lang=ja
~~~

- screen：home / quiz / library / lock
- theme：light / dark
- lang：zh / en / ja
- 无参数时跟随系统主题和系统语言；选择写入 localStorage（vl-theme / vl-lang）。

## 四屏

### home
- 今日目标环 + 已完成/剩余题数 + 预计时间。
- 近 7 天学习量柱状图、连续学习、待复习、薄弱项。
- 最近学过、快捷操作（导入词表 / AI 加词 / 锁屏专注 / 查看统计）。
- 左侧固定侧栏：学习/词库/听力/统计/设置/AI 对话；底部语言切换 + 连续天数。

### quiz
- 题型标签（词义选择）、单词、音标/词性、例句填空。
- 1–4 选项，正确项绿色反馈。
- 右侧 rail：今日进度、本轮题目方块、薄弱项、快捷键提示。
- 底部键位：Esc 退出、1–4 选择、R 重听、Space 下一题。

### library
- 搜索 + 状态筛选（All / Learning / Due / Mastered）。
- 词表列：Word / Meaning / Status / Next review / Strength。
- 右侧详情：释义、例句、复习参数（EF/Interval/Reviews）、标签、加入复习。

### lock
- 全屏专注遮罩，居中题卡 + 进度条。
- Esc 退出、Ctrl+Shift+Q 紧急退出、鼠标锁定提示。
- 这是视觉概念；实际系统级锁定/防绕过在 Electron M3 实现。

## 设计 token

### 颜色（浅色）
| token | 值 |
|---|---|
| bg | #F4F4F1 |
| panel | #FFFFFF |
| panel2 | #FAFAF7 |
| border | #E5E3DD |
| text | #1A1B1D |
| muted | #666A70 |
| faint | #93979D |
| accent | #3A56D4 |
| green | #1A7F4B |
| amber | #A16207 |

### 颜色（深色）
| token | 值 |
|---|---|
| bg | #0B0D10 |
| panel | #12151A |
| panel2 | #0E1014 |
| border | rgba(255,255,255,.075) |
| text | #E9EBEF |
| muted | #9AA1AC |
| faint | #6C7480 |
| accent | #8C9BFF |
| green | #5BD68A |
| amber | #E8B45E |

### 排版/尺寸
- 字阶：46/30/18/15/13/12.5/12/11.5/10.5/10（按场景取用）；正文 13px。
- 卡片圆角 12；控件 6–9；导航高 32；侧栏 234；标题栏 40；图标 16。
- 1px 发丝边框替代重阴影。
- 间距以 4/8/12/16/24 为主。
- 字体按语言切栈：zh 用 Microsoft YaHei UI，ja 用 Yu Gothic UI/Meiryo，en 用 Segoe UI。

## 与实现的关系

- 已拍板 Electron 34 + electron-vite + React 19 + TS + Tailwind v4 + shadcn/ui（2026-11-08）。
- 原型用于 M0 视觉验收：先对齐 token/布局/键位，再拆组件。
- 未实现的交互：真实 API、录音、TTS、SM-2 数据、锁屏防绕过、多屏。
- 原型里的数字/单词是演示数据，接后端时必须替换。

## 实现状态（2026-11-17）

- M0 已落地在仓库根 `electron/`（Electron 34 + electron-vite + React 19 + TS）。
- `src/renderer/src/styles/design.css` 与 `i18n.json` 由 `electron/scripts/extract-design.mjs` 从本目录 `app.html` 抽取，token/文案与原型同源；改设计请改原型再重跑脚本。
- 已实现：home / library / quiz / lock 四屏 + stats 简版；浅色/深色、中/英/日；导航 6 项（听力/设置/AI 标灰待 M2）。
- 未实现：真实答题提交与 SM-2、听力/设置/AI 三屏、系统级锁屏、打包。详见 docs/STATUS.md。

## 已知限制

- 锁屏只是网页遮罩，不是 OS 级锁定。
- 没有真实错误态/空态/加载态。
- 没有移动端/窄窗适配。
- 没有键盘导航 focus ring 的完整规范。