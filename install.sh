#!/usr/bin/env bash
# 爱绫 QQbot 一键包 v0.1
# 做的事：装一套能跑的 QQ 机器人后端（NapCat），OneBot v11 + WebUI 扫码登录。
# 不碰任何已有容器；所有东西都在 --dir 指定的目录里。
set -euo pipefail

DIR="${QQBOT_DIR:-$HOME/qqbot}"
ACCOUNT="${QQBOT_ACCOUNT:-}"
WS_PORT="${QQBOT_WS_PORT:-3001}"
UI_PORT="${QQBOT_UI_PORT:-6099}"
IMAGE="${QQBOT_IMAGE:-mlikiowa/napcat-docker:latest}"
MODE="install"

info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    --account) ACCOUNT="$2"; shift 2 ;;
    --ws-port) WS_PORT="$2"; shift 2 ;;
    --ui-port) UI_PORT="$2"; shift 2 ;;
    --check) MODE="check"; shift ;;
    --dry-run) MODE="dry"; shift ;;
    -h|--help)
      cat <<'H'
用法: install.sh [--dir DIR] [--account QQ号] [--ws-port 3001] [--ui-port 6099] [--check|--dry-run]
装一套 QQ 机器人后端（NapCat + 官方 Linux QQ + OneBot v11，容器化）。
H
      exit 0 ;;
    *) die "不认识的参数：$1" ;;
  esac
done

mem_mb() {
  awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0
}
port_busy() {
  # 返回 0 = 被占
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && { exec 3>&-; return 0; }
  return 1
}

info "检查环境"
command -v docker >/dev/null || die "没装 docker。先装：https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || die "docker compose 插件没有。装一下：apt install docker-compose-plugin"
[ "$(uname -m)" = "x86_64" ] || die "这套镜像只做 x86_64；$(uname -m) 得另做，别硬装"
MEM=$(mem_mb)
[ "$MEM" -ge 1800 ] || die "内存只有 ${MEM}MB，QQ 客户端跑不动。至少要 2GB，建议 4GB"
AVAIL=$(df -Pm "$HOME" | awk 'NR==2{print $4}')
[ "$AVAIL" -ge 6000 ] || die "磁盘只剩 ${AVAIL}MB，镜像要 5GB 左右"
if port_busy "$WS_PORT"; then die "端口 $WS_PORT 被占了（OneBot WS）。换一个：--ws-port 3001"; fi
if port_busy "$UI_PORT"; then die "端口 $UI_PORT 被占了（WebUI）。换一个：--ui-port 6099"; fi
info "环境 OK：内存 ${MEM}MB，可用磁盘 ${AVAIL}MB，端口 $WS_PORT/$UI_PORT 都空着"

if [ "$MODE" = "check" ]; then info "只检查，没动手"; exit 0; fi

mkdir -p "$DIR/data/qq" "$DIR/data/config"
cat > "$DIR/docker-compose.yml" <<YML
services:
  napcat:
    image: ${IMAGE}
    container_name: qqbot-napcat
    restart: unless-stopped
    environment:
      - ACCOUNT=${ACCOUNT}
      - NAPCAT_UID=1000
      - NAPCAT_GID=1000
      - TZ=Asia/Shanghai
    ports:
      - "127.0.0.1:${WS_PORT}:3001"
      - "127.0.0.1:${UI_PORT}:6099"
    volumes:
      - ./data/qq:/app/.config/QQ
      - ./data/config:/app/napcat/config
YML

cat > "$DIR/start.sh"   <<'X'
#!/usr/bin/env bash
cd "$(dirname "$0")" && docker compose up -d && echo "已启动；看二维码：./qr.sh"
X
cat > "$DIR/stop.sh"    <<'X'
#!/usr/bin/env bash
cd "$(dirname "$0")" && docker compose down
X
cat > "$DIR/qr.sh"      <<'X'
#!/usr/bin/env bash
cd "$(dirname "$0")"
echo "等二维码出现（Ctrl+C 退出，不影响后台运行）……"
docker compose logs -f --tail=200 napcat | grep --line-buffered -A60 -iE 'qrcode|二维码|扫码' || docker compose logs --tail=100 napcat
X
cat > "$DIR/logs.sh"    <<'X'
#!/usr/bin/env bash
cd "$(dirname "$0")" && docker compose logs -f --tail=200 napcat
X
chmod +x "$DIR"/*.sh

if [ "$MODE" = "dry" ]; then info "只生成配置：$DIR（没拉镜像、没起容器）"; exit 0; fi

info "拉镜像（约 2.1GB，慢的话泡杯茶）"
(cd "$DIR" && docker compose pull)

info "启动"
(cd "$DIR" && docker compose up -d)

cat <<EOF

装完了。下一步：

  1. 看二维码登录：
     cd $DIR && ./qr.sh
     （二维码会以字符画 + 图片两种形式出现；字符画扫不动的话，
       日志里有一行「二维码解码URL」，复制到任意二维码网站生成再扫，
       或者直接拿容器里的 /app/napcat/cache/qrcode.png）

  2. 扫码：手机 QQ（bot 账号）扫终端里的码

  3. WebUI（可选，网页里也能扫码/看状态）：
     http://127.0.0.1:$UI_PORT
     登录 token 在：$DIR/data/config/ 里，或看日志 ./logs.sh

  4. OneBot v11：ws://127.0.0.1:$WS_PORT
     令牌第一次启动时随机生成，在 data/config/onebot11_${ACCOUNT:-<QQ号>}.json 里

  停：cd $DIR && ./stop.sh
  日志：cd $DIR && ./logs.sh

⚠️ 这个包只负责「协议端」。上层的机器人（人格、插件）自己接 OneBot。
⚠️ 登录要人扫一次码；没扫码之前它就是个空壳。
EOF
