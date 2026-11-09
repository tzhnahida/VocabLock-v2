# QQ 通道抢救方案（NapCat 4.15 降级 + 反检测 + 养号）

> 依据（2026-09 调研）: NapCat latest(4.17.x+) + QQ 3.2.25+ 频繁 KickedOffline
> （GitHub [Issue #1728](https://github.com/NapNeko/NapCatQQ/issues/1728) 实测"不到 2 小时掉"）;
> **4.15.0 + QQ 3.2.23-44343** 组合被多名用户验证"连续 5 天稳"。
> 反检测全开 + Linux Docker 是第二关键（有用户 Windows 1 小时封、Linux 稳 8 个月）。

## 执行顺序（按验证强度排序，一档不行换下一档）

### 档 1：降级 + 反检测（最被广泛验证）

```bash
# Pi 上
docker pull docker.1ms.run/mlikiowa/napcat-docker:4.15.0   # ⚠️ arm64 支持待实测; 拉不到用官方 release 4.15.0 裸跑
# 启动:
docker run -d --name napcat --restart=always \
  -p 3001:3001 -p 6099:6099 \
  -e NAPCAT_UID=<你的uid> -e NAPCAT_GID=<你的gid> \
  -v /home/pi/napcat/config:/app/napcat/config \
  docker.1ms.run/mlikiowa/napcat-docker:4.15.0
```

**反检测配置**（`/home/pi/napcat/config/napcat.json`，改后重启）:

```json
{
  "bypass": {
    "hook": true, "window": true, "module": true,
    "process": true, "container": true, "js": true
  },
  "o3HookMode": 1,
  "webui": true
}
```

官方安全文档: https://doc.napneko.icu/other/security

### 档 2：登录姿态

1. **静置 40-48 小时**再登录被踢的号（社区共识：被踢后立即重登=继续被踢）
2. 扫码登录后 **被踢就重登 2-3 次**（新 IP 转"常用 IP"后转稳）
3. 清残留：删除旧 device 缓存（MAC/GUID 一并清）
4. 登录期间**避免代理/IP 漂移**；Pi 固定出口 IP（重启别换）
5. 与常用号**不同时在线**（同号双端+异地最易触发）

### 档 3：行为降噪（我们的设计天然符合）

- 消息 ≤20 条/分钟 —— 我们 2 条/天 ✅ 最安全节奏
- 重连间隔别太猛（≥30s，默认 5s 太激进）
- 不要自动群发/批量加好友

### 档 4：换协议端（仍不行时）

LLOneBot（llbot）/ LuckyLilliaBot / snowluma —— 社区反馈"换后没再掉过"。
OneBot v11 协议不变，convo 侧零改动（只改 API 地址）。

## 账号侧（用户执行）

- [ ] **被踢号**：静置 40-48h → 档 2 流程重登
- [ ] **并行养一个号**（最稳配方：注册久/等级高/已实名/低活跃；新号需 15-30 天养号期：完善资料、正常聊天、低频）
- [ ] 试跑启动时间 = 养号完成日或被踢号抢救成功日，取较晚者
