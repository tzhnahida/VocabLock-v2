# convo 试跑部署 (Pi) — v2.3

## 1. 交叉编译 (PC 上执行)

```bash
cd backend
# 管理 Web 已 embed 进二进制 (admin_dist), 直接交叉编译:
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o convo-linux-arm64 ./cmd/convo
scp convo-linux-arm64 pi@<host>:/home/pi/convo/convo
```

## 2. Pi 上准备

```bash
mkdir -p /home/pi/convo/data
# convo.yaml 拷到 /home/pi/convo/ (listen 0.0.0.0:8420, owner_qq=你的QQ, CONVO_AI_KEY 在 env)
sudo mkdir -p /etc/convo && echo 'CONVO_AI_KEY=sk-xxx' | sudo tee /etc/convo/env && sudo chmod 600 /etc/convo/env
sudo cp convo.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now convo
journalctl -u convo -f   # 看日志
```

## 3. NapCat (QQ 通道, 独立 unit)

- 官方安装脚本: `curl -o /tmp/napcat.sh https://dl.napcat.napneko.icu/install.sh && bash /tmp/napcat.sh` (或 Docker)
- 登录小号 (扫码), 开放 HTTP API 端口 3001 + 设置反向 WS 地址 `ws://127.0.0.1:8421/ws`
- ⚠️ 实测清单: get_login_info / send_private_msg / 图片文件路径 / set_self_profile (签名联动)

## 4. 验证

```bash
curl -s http://127.0.0.1:8420/health                       # Pi 本机
# PC 浏览器: http://<pi>:8420/?token=<data/convo-token.txt 内容>
```

## 5. 试跑流程

1. PC 浏览器打开管理页 → 创建朋友 (三问+模板 → 预览 → 确认)
2. QQ 里加小号为好友, 测试她主动开口 (状态机配额 2 条/天)
3. 观察台看计数; ⚠️ 每周日 02:00 表情包自搜自选跑一轮
