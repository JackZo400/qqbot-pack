# 爱绫 QQbot 一键包

**做的事**：一条命令装起一个能用的 QQ 机器人后端。
协议端用 NapCat（跑官方 Linux QQ + 注入），出口是 OneBot v11，扫码登录，容器化。

**不做什么**：不做人格、不做插件、不造协议。上层（Koishi / NoneBot / 自己的代码）接 OneBot 就行。

## 用法

    bash install.sh --account <bot的QQ号>

可选参数：

| 参数 | 默认 | 说明 |
|---|---|---|
| `--dir` | `~/qqbot` | 装到哪 |
| `--account` | 空 | QQ 号；留空也能起，登录时扫码 |
| `--ws-port` | 3001 | OneBot WS 端口 |
| `--ui-port` | 6099 | WebUI 端口 |
| `--check` | — | 只检查环境，不动手 |
| `--dry-run` | — | 只生成配置，不拉镜像不起容器 |

装完：

    cd ~/qqbot
    ./qr.sh      # 看二维码，手机 QQ 扫
    ./logs.sh    # 全部日志
    ./stop.sh    # 停

## 硬要求

- **x86_64**（arm 得另做，别硬装）
- **内存 ≥ 2GB**，1G 的机器 QQ 起不来
- **磁盘 ≥ 6GB**（镜像约 2.1GB，装开更大）
- docker + docker compose 插件
- 端口 3001 / 6099 空闲（脚本会查）

## 已验证到什么程度

在 NAS 上真跑通过一次（2026-11-17 19:33）：

- 环境检查、端口冲突检测 ✅
- `docker compose config` 语法 ✅
- 容器起来，QQ 客户端加载完成（`[preload] succeeded`）✅
- **二维码正常输出**：字符画 + `/app/napcat/cache/qrcode.png` + 一行 `https://txz.qq.com/p?k=...` 解码地址 ✅

**没验的**：真正扫码登录后的收发（那要用真 QQ 号登一次，不敢拿现有账号试）。
所以本文档不说「装完就能用」——**登录那一步得你自己扫**。

## 已知坑

- 二维码字符画在有些终端会变形，扫不动就用那行 txz.qq.com 链接去生成
- 免费 VPS 很多给的是 1G，装之前先看 `free -m`
- 容器里没有 dbus，日志会刷一堆 `Failed to connect to the bus`——**无害**，不影响登录
- 数据在 `~/qqbot/data/`，换机器时整个目录拷走就行
