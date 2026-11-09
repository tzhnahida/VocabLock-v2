# VocabLock v2 — Roadmap(2026-09-02 规划)

> 基于 2026-09-02 的三轮完整走查(代码审计 + 实机模拟 + 论文检索)形成。
> 状态基线:bug 修复清单见 git 工作区(未提交);论文依据详见项目旁的 LLM Wiki 草案
> `_cc-inbox/to-vault/2026-09-02 - VocabLock v2 设计决策的论文依据.md`。

## 一、本轮结论(已固化的判断)

### 1. 质量基线
- 调度(SM-2 + tier 分层)、判定(exact→regex→AI 三层)、字典 gate、发音评分(GOP 谱系)、零 AI 降级 — **五根柱子立住,短期不动**。
- 已修复 21 项(气泡百分比、grammar 跳过、完成页死代码、溢出、l10n 全库、daily_time_target 全链路、mock 完结制等),详见交付记录。
- **非 bug 确认**:注入式鼠标在 Flutter WM_POINTER 管线下的平台伪影,已用 widget 测试反证("答→下一题"循环零异常)。

### 2. 锁屏定性(行为设计)
**锁屏是承诺装置(commitment device),不是惩罚装置。**
- 有效机制:损失厌恶(Kahneman & Tversky)+ 自我设限优于外部死线(Ariely & Wertenbroch 2002)。
- 边界:逼的是入场不是学习;逼走"状态差的日子"会驱逐用户(Lally 2010:习惯养成均值 66 天,可持续 > 完美);对无内在目标者引发逆反。
- 方向:**自适应强度**(连续达标 N 天后可降级为软模式/streak 型)、**无损逃逸**(逃一次=缩量,不加重惩罚)、**自设赌注**(用户主动下注,替代系统单向惩罚)。

### 3. 学习机制诊断
**机制不缺,闭环偏浅。** 三个深化方向(按证据强度排序):

| # | 方向 | 学习科学依据 | 现状缺口 |
|---|------|-------------|---------|
| 1 | **错因分类 + 纠正性反馈**(形似/音似/义混;发音"怎么改"而非仅"哪里错") | ITS 模型追踪(vonLehn);反馈诊断性 > 即时性 | 答错仅显示对错 + 一行 feedback;音素格只标红绿无纠正建议 |
| 2 | **错题即时重测**(不等明天) | 检索练习即时强化(Roediger & Karpicke 2006) | 答错仅 SM-2 tier 重置,当下无重测 |
| 3 | **新词交错化 + 语义关联挂靠**(形近/义近/同根词对;新词挂已学词) | 交错优势(Rohrer & Taylor 2007);深度加工/精细化(elaboration) | AI 按主题分块出词;词条语义孤立 |

### 4. 次要观察
- AI 评判需**信任校准**:AI 判错的题要能回看/申诉;记录 AI 判定与确定性判定的分歧率。⚠️ 推断建议,无实验数据。
- 情景对话/输出驱动:价值最高但工程量大 — 排在 P1 完成之后,别抢在闭环加深前铺摊子。
- 语音跟读无"口型/重音纠正提示",发音反馈止步于评分。⚠️ 待产品确认优先级。

## 二、规划(按产出/成本比排序)

### P1 — 错因诊断 + 纠正性反馈(护城河方向)
- [ ] 判定响应增加 `error_category`(形似/音似/义混/语法/其他)+ 判定依据说明
- [ ] AI 评判输出错误解释并写入 review log(可回看)
- [ ] 发音评分:音素格扩展为"偏差 + 纠正建议"(重音/口型/连读提示),数据来自 pronounce provider 扩展
- [ ] 前端反馈卡升级:错因标签 + 1-2 句"怎么改"
- 验收:一次答错 → 用户能说出"我错在哪、怎么改";日志可按错因聚合
- 依据:ITS 模型追踪、GOP(发音纠正),论文见草案 §3/§6

### P2 — 错题即时重测
- [ ] submit 判错后,当前会话内 2-3 题内重新出现同词(标"重测")
- [ ] 重测题分数与首测分开记录(避免污染 SM-2 间隔)
- 验收:答错词在 5 分钟内重测 ≥1 次
- 依据:Roediger & Karpicke 2006(检索强化)

### P3 — 交错化 + 语义网络
- [ ] 出词参数支持"词对"(同族/形近/义近),AI 产出候选词对经字典门校验
- [ ] 新词卡展示与已学词的关联(1 行)
- [ ] 题组顺序轻度交错(同主题不连排 3+)
- 验收:新词引入与旧词显式关联;主题连续题 ≤2
- 依据:Rohrer & Taylor 2007;Cepeda 2006(间隔)

### P4(远期,预留)— 输出驱动/情景对话
- [ ] 待 P1 闭环稳定后评估;不与 P1-P3 并行抢工

### 产品侧决策项(需人工拍板)
- [ ] 锁屏强度自适应策略(达标 N 天后降级?)
- [ ] 逃逸改"无损"(逃=缩量)还是保持惩罚式?(⚠️ 建议前者)
- [ ] 自设赌注功能是否立项

## 三、参考(已核实 DOI 见 LLM Wiki 草案)
- SM-2/FSRS/HLR、Cepeda 2006、Nation 2020、Kulik & Fletcher 2016、Roediger & Karpicke 2006、Witt & Young 2000(GOP)、Kornell 2009(pretesting)
- 行为设计(经典引用,未逐条核实):Ariely & Wertenbroch 2002(自我设限)、Lally 2010(66 天习惯)、Kahneman & Tversky(损失厌恶)、Milkman 2014(temptation bundling)

## 四、AI 行为监控与矫正诊断(2026-09-02 追加)

**结论:监控够"记录",不够"诊断";矫正够"单点",不够"闭环"。** 数据基础好(原始字段 80% 已入库),缺的是分析层。

### 现状(代码事实)
- ✅ 已有:`review_log` 含 question_type / user_answer / expected_answer / correct / score / **source(判定来源!)** / created_at → AI 校准分析的数据基础在;daily_stats(含时长);training_plan(direction/confidence);pending review 审核队列(AI 出词的矫正)
- ⚠️ 半丢失:**发音音素被序列化成 feedback 字符串**入库(如 `あ:85+ か:40-`)— 可看不可 SQL 聚合 → "某个音素 30 天持续 <45%" 需解析字符串
- ❌ 缺失:错因维度(error_category:形似/音似/义混);跨 subject 聚合查询(只有单词 GetReviewLogs);AI 评判无分歧率监控;无错因专项矫正

### 已修:i18n 未传入 AI(2026-09-02)
- 断层:`InterfaceLang`(UI 语言)只存在于 config 存取,**AI prompt 层 0 处使用**;AI 输出语言仅由"学习语言配置的 ExplanationLang"决定(chat 还硬编码默认 zh-CN)→ UI 英文学日语会收到中文 AI 回复
- 修复:`Server.aiExplLang(lang)` — **UI 语言 > 语言配置解释语言 > "en"**,统一接入全部 8 处出口(chat / aiJudge / 出题面 / grammar 题 / assignment×3 / session 总结与计划 / expand);`go vet + test + build` 全绿

### 后续(与 P1/P2 合并评估)
- [ ] `review_log` 加 `error_category`(P1 前置,1 天)
- [ ] phonemes 独立表(或 JSON 列)— 发音监控归因的前提
- [ ] AI 校准查询:source='ai' 且与确定性判定分歧的比率;阈值告警

## 五、AI 出词可复现性与显性化(2026-09-02)

**症状**:用户感觉"AI 出词逻辑每次都不一样"。
**归因(非 bug,三层叠加)**:① LLM 固有随机(expand.yaml temp 0.6);② 刻意随机抽样 — `buildVocabSummary` 的 `rand.Shuffle`(commit "randomize vocab summary samples every call",防重复出词,但让 AI 选词空间每轮漂移);③ 状态漂移(plan/daily_target 被 session 总结更新、recent words 变化、pending 重试);④ 无固定 seed 放大器。

### 已改(2026-09-02)
1. **日级 seed 可复现抽样**:`rand.New(rand.NewSource(daySeed))`(日期+语言)— 同一天抽样一致(可复现/可 debug),次日自动变(保留防重复意图)
2. **扩展审计日志**:每次 expand 记录 `lang/count/direction/dedup 池大小/recent 上下文长度`("expand audit" 行)
3. **响应显性化**:`POST /words/expand` 响应增加 `direction` + `context_words` → 前端横幅显示"按[direction]生成 N 个词汇(已入库 X,待审核 Y,参考 Z 个旧词)"；原硬编码中文状态文案全部 l10n(expandStatus* 6 key ×3 语)
4. **温度 0.6 → 0.5**(降漂移;多样性由日级抽样保障)

### 观测项
- [ ] 用审计日志观察:每天 expand 的 direction/dedup 变化是否符合预期;若仍觉漂移大 → 温度再降 0.4 或抽样改为"低频类别优先"

## 六、语义修正:取消"挂钟时间解锁"(2026-09-02)

**背景**:设计意图 — 每日目标以题数计;"时间"只是 UX 换算(30 min ≈ 15 题,onboarding 滑块),**不存在独立计时器/挂钟解锁**。此前接线 `daily_time_target` 时引入了"累计流逝时间达标 → 解锁"的 OR 分支(挂机 20 分钟可解锁),属实现偏离设计。

**已修正**:
- `DailyTargetMet`:移除时间分支 → **题数门槛 + 准确率门槛**(answered>0 时 accuracy ≥ MinAccuracy,落实 onboarding "Accuracy >= 80% required to unlock" 承诺 — 此前从未被任何逻辑执行)
- `time_spent_sec` 累计保留,明确为**统计用途**(未来"投入时间"展示/分析),不参与解锁
- `daily_time_target` 配置保留,用途 = 设置时的题数换算/展示
- 顺带修复预存 flaky 测试 `TestSelectQuestionType_NewWord`(断言写死"必是 choice",与 tier-0 随机抽题实现矛盾 — 之前全绿纯属运气)

**语义备忘**:解锁 = 复习足够题数(N,subject 去重)且(若已作答)准确率 ≥ 80%;时间不进入判定。

## 七、目标语义脱节修复(2026-09-02,来自真实截图)

**症状**:用户截图显示"共 90 题 · 预估 135 分钟"(到期复习 76 堆 + 新词 13)— 用户必然逃走。
**根因(4 层)**:① 复习池无配额(SM-2 到期积累,漏学/答错重置都会堆);② 新词扩展正常;③ **显示与目标脱节(真 bug)** — 概览把"整池"当"今日必修",而实际解锁 = DailyTarget(20 题),`getNext` 达标即 ended;④ 预估值按全池算。

**已修**:
- 后端 `session/start` 3 个 READY 分支返回 `daily_remaining`/`daily_target`(实时 = DailyTarget − 已复习唯一数)
- 前端概览:醒目目标框"今日目标:再完成 N 题解锁";复习池降级为"到期可复习 M(达标后自动结束)";预估时间只按目标算;无字段时优雅回退(旧行为)
- l10n:quizGoalRemaining / quizReviewPool / quizReviewNote / quizEstimateGoal ×3 语

**遗留(见 P2/P3)**:
- [ ] 复习池配额 cap(session/start 的 review 显示 capped 到"剩余目标+余量",超出顺延)
- [ ] 答错重置提示(interval=1d 会推高明日池 — SM-2 规范,给预期管理文案)

## 八、AI 信任回路 — 校准与申诉(2026-09-02 落地,①②③ 升级)

### ① 数据逻辑 B- → B+
- [x] `review_log` 新列:`phonemes_json`(结构化音素)/ `error_category` / `dispute` / `language` + 索引;insert/select 全链更新
- [x] judge 链错因:`classifyError` 启发式(空答→"empty";Levenshtein ≥0.6 相似→"similarity";其它→"other");空答分支直接赋类别;AI 层可覆盖
- [x] `GET /api/v1/stats/diagnostics`:错因分布 / 弱音素分布(<45%)/ AI 分歧率(ai 判错但答案与期望完全一致 = AI 假阴性,含样本)/ 题型错误率 / 词汇覆盖(30 天窗口)

### ③ AI 集成 B- → B+
- [x] 校准回路:diagnostics 的 ai_disagreement(wrong_but_exact_hit 即假阴性率)— 每周可报告
- [x] 判定基准集:`judge/bench_test.go` — 15 条人工标注样本(exact/regex/substring/strict/lenient/空答/多答案/错因)+ AI stub 层验证;**改 prompt 前跑回归** = 缺失的 prompt 评测体系(分层:确定层 vs AI 层)
- [x] 评分申诉闭环:submit 响应带 `log_id`;`POST /api/v1/quiz/dispute`(仅标记,无 SM-2 副作用);前端答错反馈卡"我觉得判错了"按钮(仅 AI/非 exact 错答显示);l10n disputeGrade ×3 语

### ② 工程卫生 B → B+
- [x] 面板 smoke 测试 ×8(Words/Stats/Audio/AIChat/PendingReview/Config/Assignment/SessionSummary — 无后端状态零异常)— `flutter test` 3 → 11
- [x] CI:`.github/workflows/ci.yaml` 加 frontend job(subosito/flutter-action:pub get + analyze + test)
- [x] flaky 修复:TestSelectQuestionType_NewWord(§六);基准集防回归

### 待办(未做,如实)
- [ ] 前端申诉按钮的 widget 测试(11 个测试未覆盖 dispute 交互)
- [ ] diagnostics 端点前端展示(当前只 API,面板未挂)

## 九、月度仿真(2026-09-03)— 9 场景 × 30 天,真实 HTTP handler + 时间旅行

**方法**:新增 `internal/clock`(唯一可注入时钟)替换全部调度/日界判定(SQLite `datetime('now')` ×6、Go `time.Now()` 散点 ×14、插入日志 created_at、双服务窗口)。仿真器 `internal/sim/` 驱动真实 handler:每天 session/start→next/submit 循环→complete(→summarize),每 题 +8s 推进时钟。产出 `SIMULATION.md`(仓库根,`go test ./internal/sim/` 可复现)。附带 `probe_test.go`(SM-2 持久化回归)。

**9 场景**:稳定学霸(300词,90%,无AI)/ 波动生(35-85%,均60%)/ 卡手难词(10% p=0.15)/ 请假 5 天 / 摸鱼(5题/天)/ AI+自动扩词(无词典)/ 日英混学 / AI+语法(200词+15语法)/ 贫词汇(40词,零AI)。

**关键发现**(数据见 SIMULATION.md):

1. **零 AI 小词库死锁(最严重)**:40 词 2 天学完 → 22/30 天 BLOCK。`totalAvailable < DailyTarget` 且当天未答题时 session/start 返回 `preparing`,零 AI 无任何补词手段 → 用户第二天起永远"AI 准备中"(实际没有 AI)。10+ 词到期也不给学。
2. **准确率门压榨**:波动生 0/30 天达标,26 天被迫刷满 100 题(仿真上限)仍不满 80%;会话无软上限,低正确率=永锁+无限刷题,无降级出口。
3. **到期池体感永远不减**:稳定学霸天天达标,池子仍长期 40-280(27/30 天 >40);目标 cap 每天只消化 20 → 欠债感永存(§七修了展示,池本身是常态)。
4. **AI 扩词无词典 = 死路**:扩词全部进 pending_review 隔离墙,nw 永远 0;150 词成熟(间隔 15-90 天)后每天到期 <20 → 触发扩词→填不满→BLOCK(第 28/30 天)。真实用户=第 3 周起"AI 准备中"回环。
5. **单日答题量波动大**:池≫目标或准确率临时跌破门槛时 20-60 题/天(S3 出现 50/60 题天)。
6. **请假 5 天无冲击**:回归后零异常,池+20 目测无感 — 调度健康。
7. **语法自动注入**:AI 场景 summarize 触发 expandGrammar(gTotal<5)自动补语法点 — 即使 config 未启用 grammar 题型,handler 的语法分支不查配置(设计如此,记录在案)。
8. **SM-2 30 天节奏**:90% 正确率下 30 天间隔分布集中 1-6 天;EF 正常(2.6);无异常。

**已修(2026-09-03 全部落地)**:
- [x] P0 准入语义(①):session/start 只查"空库"——池>0 永远 READY;池=0 且有 AI → preparing(唯一转圈);池=0 且零 AI → `empty:true` 诚实空态。删除 total<target → preparing 分支(及 final safety net)。后端单测 TestSessionStartEmptyVault / TestSessionStartPartialPoolReady;仿真 S9 从 22 天 BLOCK → 7 天正常空态、零死锁
- [x] P1 会话软上限(②):`hitSoftCap` = 1.5×目标(min +10),达到后 next 返回 `session_exhausted`;`POST /quiz/session/continue` 显式继续(预算当日重置)。修复过程中抓到并修掉 2 个引入级 bug:budget 跨日不滚动(→ rolloverLocked 统一)与 replace_all 递归(栈溢出)。仿真 S2 从 2600 题/月 → 573 题,达标 0→7 天。单测 TestNextSoftCapAndContinue
- [x] P1 零 AI 自适应目标(③):连续 3 天(有学习记录且)不达标 → DailyTarget ×0.8(下限 10),质量门槛(0.8)永不降;`target_adjusted` 响应字段。单测 TestCompleteAdjustsTargetAfter3UnmetDays
- [x] P1 无词典扩词(⑥-a 用户选择保留隔离墙):`POST /words/pending-review/accept-all` 批量验收(已有字段/dict/AI 补全,仍缺释义跳过并报告);前端"全部验收"按钮。单测 TestPendingAcceptAll
- [x] P4 (④)语法注入条件:summarize/bootstrap 的 expandGrammar 仅当语言配置启用 grammar 题型
- [x] (⑤ 部分)空态/继续训练 UI:quiz 页空库视图、软上限完成视图"继续训练";前端 l10n 新键 ×3 语(并补 zh/ja 缺失的 disputeGrade)
- [ ] 后续(未做,如实):池子展示"本周掌握 x/300"进度感(需 coverage 前端管线);前端"继续训练"按钮 widget 测试

## 十、convo 朋友聊天(方案已细化 —— 见 CONVO-SPEC.md 单一规格源)

**定位**: 朋友式沉浸语言陪伴 — 聊天是主科,背单词是地基;三轴沉浸 + 词驱动检索让"聊天=学习"。

**已拍板**: 全天随机触发(锁屏挂起解锁即达)/ 联网抓料 / 自定角色 / AI 自搜表情包(喜欢位加权+月度轮换)/ 隔日回顾卡 / AI 自主日程表(五档状态+摸鱼+预告)/ 日程协商约会(被鸽会失望)/ 双向索取(拒绝=小失望+内容飞轮)/ 反腻四层(AI 自主决策+系统记忆骰子)。

**用户画像**(文献驱动): A 情感需求型(神经质×内向, 时长王·留存主体)/ B 工具理性型(尽责×开放, 学得下留不长, 要进度面板)/ C 外向高能型(3 周衰减, 反腻四层为其设计)/ D 走错门。

**阶段**: P1 朋友上线(~4 天: profile+创建页/状态机/chat_friend/回顾卡/内置话题/内置表情/API+前端) → P2 真·找资料(~3 天: 联网+视觉卡+按钮区界面替换+分享飞轮) → P3 朋友养成(~2 天: 通知/语音/升降频/A/B)。

**实证口径**: 1w 下载 → 30 天 800-1300 → 90 天 350-550 → 1 年 150-300 → 真学会 80-150(对照单词 App: 数字 1.5-3 倍,行为差一个品类)。审判日 A/B: 聊天组 vs 刷题组 3 周 recall。
