# Pronounce Test — 非主线，纯测试用

## 直接测试 Julius

```bash
cd backend/pronounce-test/kit
.\julius.exe -C main.jconf -C am-gmm.jconf -demo -charconv utf-8 sjis
```

对着麦克风念日语词，终端实时出识别结果。

## 测试发音评估 wrapper

```bash
python backend/pronounce-test/bin/pronounce-julius.py --audio test.wav --text たべる
```

输出 JSON：`{"score": 0.85, "phonemes": [...]}`

## 模型文件

- `kit/model/phone_m/` — JNAS 三音素 HMM (~15MB)
- `kit/model/lang_m/` — BCCWJ 60K 词典 + LM (~92MB)
- `kit/model/dnn/` — DNN 层（备用，未启用）
