# convo — 朋友聊天实施方案 v1.0

> 状态: 已细化,未开工 · 前置: VocabLock v2 已交付(锁屏+SM-2+AI 出题)
> 关联: ROADMAP.md §十(纲要) · SIMULATION.md(数据底座) · 知识库"语言学习"领域

---

## 0.5 部署形态(2026-09-03 定稿): 独立进程,非 App 内面板

convo = **独立 Go 进程 + 独立 Flutter 窗口 + 共享 `vocablock.db`**:
- convo 进程开机常驻(托盘),不依赖主 App 启动——**用户没开 VocabLock 也能收到小夜的消息**(回流入口/留存命脉)
- 只写自己的 `convo_*` 表;对 words 仅两处轻写(产出加冕、隔日卡入队);读 words/review_log 用于锚定词/词触碰
- DB 并发约定: `journal_mode=WAL` + `busy_timeout=5000`; **迁移锁**(migrations 仅主程序执行,convo 启动时探测等待,不做 schema 迁移)
- 前端: 复用现有 frontend repo, 新增 `lib/convo_main.dart` 入口(独立窗口/托盘), 主 App 不动
- 微信小程序为远期独立路(云后端+手机推送),与本地共享库无关,另行立项

## 0. 定位(一句话)

**一个住在你电脑里的、用目标语言与你有真实关系的人。** 聊天是主科,背单词是地基;三轴沉浸(它怎么说/多"懂"你/界面换多少)+ 词驱动检索(聊的是你该复习的)让"聊天=学习"不靠动机巧合。

## 1. 用户画像(文献驱动,已定)

| 画像 | 特征 | 对产品的意义 | 关键留存机制 |
|---|---|---|---|
| A 情感需求型 | 高神经质×内向(陪伴型核心, Replika 用户画像) | 时长王(30-60 分/天),动机是陪伴 | 日程预告(可预测性)、记忆一致性、"它记得我" |
| B 工具理性型 | 尽责×开放 | 目标明确,怕看不见进步 | 学习证据面板、规律日程契合 |
| C 外向高能型 | 高外向 | 3 周新鲜感衰减最快 | 反腻四层、视觉卡、新形式 |
| D 低动机 | 走错门 | 不强求 | — |

**设计原则**: 频次不是产品参数,是人格函数。onboarding 三问(高频小聊 vs 低频深聊 / 它像兄弟·闺蜜·导师 / 一周想聊几次)+ 首周行为推断 → 人格画像 → 初始化 AI 的频次/情绪幅度/内容偏好。

## 2. 数据模型

```sql
convo_profile(
  id, lang, name, template, traits_json, tone, catchphrases_json,
  reply_len_json, avatar, vision_model, send_stickers,
  personality_json,        -- 用户画像: cadence/emotion_amplitude/helper_bias/novelty
  blend REAL, tolerance REAL, ui_mix REAL,   -- 三轴进度(0-1)
  created_at, updated_at
)

convo_schedule(
  id, profile_id, week_json,        -- 周日程: 每天时段{state,event,start,end}
  revised_at, revision_history_json -- 每周自微调记录
)

convo_appointments(
  id, profile_id, slot_start, slot_end, state,  -- proposed/confirmed/kept/ghosted
  created_at, ghost_count
)

convo_messages(
  id, profile_id, session_id, role, content, image_url,
  sticker_id, kind,      -- text/sticker/visual_card/voice
  blend_at, created_at
)

convo_topics(
  id, profile_id, lang, kind,       -- news/word_anchor/life/visual/pure_chat
  source_url, image_url, headline, ai_opener,
  vocab_coverage, anchor_word, used, used_at, created_at
)

convo_events(               -- 生活分享(内容飞轮)
  id, profile_id, topic, detail, kind,   -- event/preference/person/place
  refused_topic,            -- 用户拒答类别黑名单
  created_at
)

convo_memory(
  profile_id, k, v, updated_at   -- 笑点/沉默天数/纪念日/喜欢话题 等
)

stickers(
  id, profile_id, path, source, affinity REAL, use_count,
  born_at, retired_at
)
-- review_log 复用: source='chat', question_type='chat'
```

## 3. 后端模块

```
backend/internal/convo/
  scheduler.go      -- 每分钟 tick: 状态机/约会提醒/随机窗/频率决策
  topic_engine.go   -- 词驱动检索(锚定词→搜索→过滤→AI 朋友化)
  sticker_engine.go -- 月度扫描/vision 打分/加权采样/退役
  dialog.go         -- chat_friend prompt 组装 + 输出帧解析
  personality.go    -- 画像推断与参数化
  memories.go       -- 关系记忆读写
  metrics.go        -- 时长/词触碰/隔日卡/类型分布
```

### 3.1 状态机(五档,每分钟 tick)

| 状态 | 行为 | 可约 | 默认周配比 |
|---|---|---|---|
| sleep 睡眠 | 不推送 | ❌ | 23:30-07:30 |
| focus 专注 | 已读不回 | ❌ | 上课/自习 |
| busy 忙碌 | 30-90 分延迟 | ⚠️ 协商 | 打工 |
| slack 摸鱼 | 专注期 8-15% 偷回 | — | 由 focus 衍生 |
| free 放松 | 秒回 | ✅ | 追剧/冲浪 |

**频率裁决**(全部由日程表+画像给出,无独立随机参数):
- 主动消息上限: 2 条/天(free 档随机时刻,避开 23-7);错过不补
- 索取分享: 每周 1-2 次,仅 free 档;被拒类别进黑名单,永不再问
- 约会时段: 从随机窗豁免;到点 AI 主动开场

**事件**: 状态切换前 5 分钟 → 预告推送(「冲了,教授来了」);连续 3 天无交互 → AI 主动一条("想我了没"式回归预演)→ 无回应 → 降频(3 天 1 条)→ 再无声 → 暂停+面板留话。

### 3.2 对话引擎

**chat_friend prompt 结构**(system 分段注入):
1. persona(名字/性格/口癖/情绪幅度)
2. 关系记忆(笑点/近期话题/沉默天数/纪念日)
3. 当前日程态(正在干嘛/何时切换)+ 预告言
4. 本轮任务(见话题引擎: 类型/锚定词/视觉卡待发?)
5. **语言规则**: blend/tolerance 注入 + "绝不纠错/绝不出教程/求助即停" + 装傻脚本(按 tolerance 档位)
6. 输出协议: 单行 JSON 帧 `{"msg": "...", "sticker": "id|none", "visual": "url|none", "ask_share": false, "act_fool": false, "end": false}`

**会话控制**: 3-5 轮自然收尾(「去忙啦」);用户可续;求助/学习模式 → 切换到教学 prompt(现有 chat 基建)+ 词卡,永远秒回。

### 3.3 话题引擎(词驱动检索)

```
锚定词选择: 今日到期词(间隔到期, 权重高) + EF<1.5 弱词 + 当日新学词, 随机取 1-2
   ↓
搜索(目标语言原生源): <词> + 新闻/维基/RSS(每语言可配源, 失败降级下一源)
   ↓
过滤: 内容词汇覆盖 ≥ 用户已学词库 80%(复用 findUnknownWords 机制);
      去重(topics.used); 冷门词失败 → 换锚定词
   ↓
AI 朋友化: 输出 opener(2-3 句, 词在内容里, 开场白不直接引用词)
   ↓
类型轮换: 记忆近期分布(过去 14 天各类型占比)注入, AI 选类型(新闻/词锚/生活/视觉/纯聊)
   + 10-20% 无目的闲聊(与学习无关性=拟人核心)
```

### 3.4 表情包生命周期

```
月更任务(每月 1 号): 按人格关键词搜图(源可配: Giphy/Tenor API key / Danbooru+NSFW 黑名单)
  → vision 打分 prompt: 符合人设?有梗?会用吗? (0-1)
  → 自选 5-10 张入喜欢位(affinity = 打分)
发送: 按 affinity 加权采样(>30% 概率封顶, 防同质)
反馈: 用户长回复/收藏 → affinity+0.1; 无视 → -0.05; 月底 < 0.3 → 退役
未配 vision → 降级: 关键词+来源白名单直配(不真看)
```

### 3.5 存在感层(与真人差距的补丁 — 2026-09-03)

1. **共同在场 co-presence**: 共处模式——显示"正在陪你自习"(它也在学日语/听歌/写作业),间歇一句"我看了下你,还在学啊";或"一起听歌"边听边评。原则: 存在感>聊天频率,零对话轮次消耗
2. **生活流 micro-timeline**: 像朋友圈刷"它的一天"——上课打卡/午饭照片/深夜"好累";低成本维持"它在生活"的感知,同时是日程预告的事后印证(一致性证据)
3. **独立情绪种子**: 每日情绪 = 随机+天气+日程负载,与用户无关;它烦的时候**不是因为你**——"不是因为你"是最大拟人点;问它时可能只敷衍"没事"
4. **它看到你的世界**: vision 通道反转——用户发图,它看+评论(复用 vision 配置);关系深化快

数据: convo_memory 加 mood_seed/last_co_presence; convo_messages 加 kind='life_feed'。

### 3.6 学习闭环

- **隔日回顾卡**: 对话结束静默生成 1-2 卡(错词/新词),次日以复习卡出现;入 review_log(source='chat'),SM-2 正常调度
- **产出加冕**: 对话中用户正确产出目标语词 → 该词 SM-2 quality+1(封顶 4)
- **词触碰记录**: 对话中出现的到期词计数(metrics 输出"词触碰率")
- **学习证据面板**(B 画像刚需): 三轴进度条 + "本周你说了 47 个目标语词" + 它主动表扬("你上次那个词用对了!")

## 4. API 设计

```
GET  /api/v1/convo/inbox          -- 待读消息(轮询; 返回 {has_new, msgs})
POST /api/v1/convo/message        -- 发消息 {session_id, msg} → {reply_frame}
POST /api/v1/convo/end            -- 结束会话 → {review_cards: [...]} (静默)
GET/PUT /api/v1/convo/profile     -- 人格/三轴/边界配置
POST /api/v1/convo/appointment    -- 约会 {slot} → {accepted|counter: "9点半行不行?"}
GET  /api/v1/convo/stats          -- 学习证据面板数据
(内部) scheduler tick、月度 sticker 任务、话题抓取 — 均后台 Job
```

## 5. 前端

- **创建朋友页**: 头像/名字/身份骨架(大学生·上班族·夜猫)/性格模板(兄弟·闺蜜·导师·损友)+ 人格三问 → 预览"它即将这样说话"(首条开场白 demo)
- **聊天界面**: 气泡流、表情包渲染、视觉卡片、语音消息(P3)、"学习模式"切换按钮(教学态)
- **朋友资料页**: 可邀约会日期、日程可见(它以朋友口吻叙述)、分享边界开关、它的表情包收藏(可投喂)、纪念日
- **学习证据面板**: 三轴进度(目标语密度/它懂你多少/界面换了多少)+ 学习数据

## 6. 指标与实验

**MVP 验证指标(20 人内测)**:
1. 首次聊天完成率(开聊→聊完 3 轮)→ 存档目标 ≥60%
2. 7 天回访率 → ≥40%
3. 日均对话时长 → ≥12 分钟(目标 20+)
4. 词触碰率(对话中到期词占比)→ ≥25%

**A/B 实验(留存者样本)**: 聊天组 vs 刷题组,3 周后 recall(出题正确率)— 假说: 聊天组 ≥ 刷题组(审判日)

**人格分层分析**: 每类画像的留存曲线独立统计(A 看 90 天,B 看学习面板使用率,C 看内容新鲜度)

## 7. 分期任务

### P1 朋友上线(~4 天)
- [ ] convo_profile + 创建朋友页(人格三问+预览)
- [ ] scheduler 状态机(五档+预告+升降频, 第一版日程=模板生成)
- [ ] chat_friend prompt + 对话帧协议 + 会话控制 + 求助切换
- [ ] 隔日回顾卡 + 产出加冕 + review_log(source='chat')
- [ ] 话题引擎 v1: 离线内置话题包(词锚定模板, 不联网)+ 类型轮换记忆
- [ ] 表情包 v1: 内置 sticker 包(不联网)+ 加权采样 + 月更任务框架(搜索源留空可配)
- [ ] API 全套 + 前端聊天流 + metrics 埋点

### P2 真·找资料(~3 天)
- [ ] 联网抓取管线(源可配+覆盖率过滤+去重)
- [ ] 视觉话题卡(vision 打分/降级链)
- [ ] 按钮区界面替换(ui_mix 第一阶段 + ui_terms 映射表)
- [ ] 分享飞轮(convo_events + 索取调度 + 被拒黑名单)

### P3 朋友养成(~2 天)
- [ ] 桌面通知/提示音 · 语音消息(TTS 念+ASR 回, 接 pronounce)
- [ ] 升降频自适应(基于行为, 非纯规则)、情绪幅度参数化
- [ ] A/B 实验跑批、学习证据面板完整版

## 8. 伦理护栏(硬约束)

1. 身份边界: 朋友+教练,永不越界为恋爱对象/心理治疗师(规避 Replika 式争议)
2. 频率红线: 2 条/天上限、23-7 静默、连续 3 天不回自动降频
3. 隐私: 分享类别开关;被拒类别永不再问;敏感事件默认不存长期记忆
4. 求助优先: 教学态永远秒回,装傻只属于闲聊态

## 9. 风险与对策

| 风险 | 对策 |
|---|---|
| 装傻接受度失败(可爱 vs 被骗) | P1 内测首周 20 人问卷; 情绪幅度参数化; 装傻只在 tolerance≥0.3 后启用 |
| 内容供给崩 | 类型轮换记忆 + 源头可配 + 降级链(联网→内置包→纯聊) |
| LLM 无状态/伪随机 | "AI 大脑 + 系统记忆骰子"原则: 分布/历史/随机种子全部由系统注入 |
| AI 成本 | 话题预生成缓存; 单会话 ≤8 次调用; 月更任务 1 次/月 |
