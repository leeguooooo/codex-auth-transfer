#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# codex-auth-transfer.sh
# 在机器之间导出和导入 Codex CLI 的认证凭据
#
# 交互式使用（无参数）:
#   ./codex-auth-transfer.sh
#
# 直接使用:
#   ./codex-auth-transfer.sh export [-o 文件名.tar.gz]
#   ./codex-auth-transfer.sh import [-f 文件名.tar.gz] [--force]
#   ./codex-auth-transfer.sh serve [--port 端口] [--bundle 文件名.tar.gz]

PROGRAM="codex-auth-transfer"
DEFAULT_BUNDLE="codex-auth-bundle.tar.gz"
DEFAULT_PORT=8888

log() { printf '[%s] %s\n' "$PROGRAM" "$*"; }
err() { printf '[%s][错误] %s\n' "$PROGRAM" "$*" 1>&2; }
info() { printf '[%s][信息] %s\n' "$PROGRAM" "$*"; }

usage() {
  cat <<EOF
用法:
  $0                    交互式菜单
  $0 export [-o 文件名.tar.gz]
  $0 import [-f 文件名.tar.gz] [--force]
  $0 serve [--port 端口] [--bundle 文件名.tar.gz]

选项:
  export              打包当前机器的 Codex 凭据
  import              在目标主机（无头服务器）上恢复凭据
  serve               启动 HTTP 服务器以分发 bundle
  -o, --output        输出文件名（默认: ${DEFAULT_BUNDLE}）
  -f, --file          要导入的 .tar.gz 文件（默认: ${DEFAULT_BUNDLE}）
  --port              HTTP 服务器端口（默认: ${DEFAULT_PORT}）
  --force             不询问直接覆盖目标目录（会先备份）
  -h, --help          显示此帮助信息

说明:
  - Bundle 包含相对路径（例如: .config/codex, .local/share/codex）
  - 导入时，如果目标已存在（例如: ~/.config/codex），会在复制前
    创建备份 <目标>.bak-YYYYmmdd-HHMMSS
  - 通过 curl 导入: curl -sSL http://IP:端口/import.sh | bash
EOF
}

# 收集包含 Codex 凭据的候选路径
find_codex_paths() {
  local base_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  local base_data="${XDG_DATA_HOME:-$HOME/.local/share}"

  local candidates=(
    "$base_config/codex"
    "$base_data/codex"
    "$HOME/.codex"
  )

  # 如果有命令可以指向目录，尝试使用它（尽力而为）
  if command -v codex >/dev/null 2>&1; then
    # 某些版本可能有显示配置路径的子命令；忽略错误
    set +e
    local hinted
    hinted=$(codex config path 2>/dev/null || true)
    set -e
    if [ -n "${hinted:-}" ] && [ -d "$hinted" ]; then
      candidates=("$hinted" "${candidates[@]}")
    fi
  fi

  # 过滤存在的路径
  local existing=()
  for p in "${candidates[@]}"; do
    if [ -e "$p" ]; then
      existing+=("$p")
    fi
  done

  printf '%s\n' "${existing[@]}"
}

timestamp() { date +%Y%m%d-%H%M%S; }

do_export() {
  local bundle="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'test -n "${tmpdir:-}" && rm -rf "$tmpdir"' EXIT

  log "正在查找 Codex 凭据目录..."
  paths=()
  local tmpfile
  tmpfile=$(mktemp)
  find_codex_paths > "$tmpfile"
  while IFS= read -r line; do
    [ -n "$line" ] && paths+=("$line")
  done < "$tmpfile"
  rm -f "$tmpfile"
  if [ "${#paths[@]}" -eq 0 ]; then
    err "未找到 Codex 凭据目录。中止。"
    exit 1
  fi

  log "检测到的目录:"; printf '  - %s\n' "${paths[@]}"

  # 构建相对于 HOME 的结构 (.config/.local/...)
  mkdir -p "$tmpdir/stage"

  local listfile="$tmpdir/stage/.codex_auth_paths.txt"
  : > "$listfile"

  for p in "${paths[@]}"; do
    # 尽可能将绝对路径转换为相对于 HOME 的路径
    local rel
    if [[ "$p" == "$HOME/"* ]]; then
      rel=".${p#"$HOME"}"
    else
      # 如果不在 $HOME 下，放在 .codex-external/<hash>
      local h
      h=$(printf '%s' "$p" | sha1sum | awk '{print $1}')
      rel=".codex-external/$h"
    fi

    local dest="$tmpdir/stage/$rel"
    mkdir -p "$(dirname "$dest")"

    if command -v rsync >/dev/null 2>&1; then
      rsync -a --chmod=Du+rwx,Fu+rw "$p/" "$dest/"
    else
      # 使用 cp -a 作为后备
      mkdir -p "$dest"
      cp -a "$p/." "$dest/"
      # 在暂存区调整权限
      find "$dest" -type d -exec chmod 700 {} +
      find "$dest" -type f -exec chmod 600 {} +
    fi

    printf '%s\n' "$rel" >> "$listfile"
  done

  # 创建简单的清单（如果 CODEX_AUTH_TRANSFER_NO_METADATA=1 则不包含用户/主机数据）
  {
    echo "created_at=$(date -Iseconds)"
    echo "paths_file=.codex_auth_paths.txt"
    if [ "${CODEX_AUTH_TRANSFER_NO_METADATA:-0}" != "1" ]; then
      echo "user=$USER"
      echo "host=$(hostname -f 2>/dev/null || hostname)"
    fi
  } > "$tmpdir/stage/.codex_auth_manifest"

  # 打包到正在归档的文件夹外部以避免循环
  tar -czf "${PWD}/${bundle##*/}" -C "$tmpdir/stage" .
  chmod 600 "${PWD}/${bundle##*/}"
  log "Bundle 已创建: ${PWD}/${bundle##*/}"
  log "请安全保存此文件。"
}

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ]; then
    local bkp="${target}.bak-$(timestamp)"
    log "备份现有目标: $target -> $bkp"
    mv "$target" "$bkp"
  fi
}

do_import() {
  local bundle="$1"
  local force="$2"

  if [ ! -f "$bundle" ]; then
    err "文件未找到: $bundle"
    exit 1
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'test -n "${tmpdir:-}" && rm -rf "$tmpdir"' EXIT

  log "正在解压 bundle..."
  tar -xzf "$bundle" -C "$tmpdir"

  # 确定要恢复的路径列表
  local listfile="$tmpdir/.codex_auth_paths.txt"
  if [ ! -f "$listfile" ]; then
    # 后备：从内容推断
    log "Bundle 中未找到路径列表；正在推断..."
    (cd "$tmpdir" && find . -maxdepth 2 -type d \( -path './.config/codex' -o -path './.local/share/codex' -o -path './.codex' -o -path './.codex-external/*' \) | sed 's|^./||' > "$listfile")
  fi

  if [ ! -s "$listfile" ]; then
    err "未找到要恢复的凭据路径。中止。"
    exit 1
  fi

  log "要恢复的路径:"; sed 's/^/  - /' "$listfile"

  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    local src="$tmpdir/$rel"
    local dest="$HOME/$rel"

    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ]; then
      if [ "$force" = "1" ]; then
        backup_if_exists "$dest"
      else
        err "目标已存在: $dest"
        err "使用 --force 重新执行以进行备份并覆盖。"
        exit 1
      fi
    fi

    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --chmod=Du+rwx,Fu+rw "$src/" "$dest/"
    else
      cp -a "$src/." "$dest/"
    fi

    # 安全权限
    find "$dest" -type d -exec chmod 700 {} +
    find "$dest" -type f -exec chmod 600 {} +
  done < "$listfile"

  log "凭据已恢复到 $HOME。"
  log "注意: 某些 CLI 会将令牌绑定到主机/用户；如果 Codex 拒绝，请使用设备代码登录或隧道。"
}

# 生成可通过 curl 下载的导入脚本
generate_import_script() {
  local server_host="$1"
  local server_port="$2"
  local bundle_file="$3"
  local bundle_name="${bundle_file##*/}"
  cat <<IMPORT_SCRIPT_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROGRAM="codex-auth-import"
log() { printf '[%s] %s\n' "$PROGRAM" "$*"; }
err() { printf '[%s][错误] %s\n' "$PROGRAM" "$*" 1>&2; }

log "正在开始导入 Codex 凭据..."

# 自动检测服务器地址
# 如果脚本是通过 curl 下载的，使用 HTTP 头中的 Host
# 否则，使用提供的地址
SERVER_HOST="${server_host}"
SERVER_PORT="${server_port}"
BUNDLE_NAME="${bundle_name}"

# 尝试自动检测服务器地址
# 如果通过 curl pipe 执行，服务器可能在同一主机上
if [ -z "\${SERVER_HOST}" ] || [ "\${SERVER_HOST}" = "localhost" ]; then
  # 尝试检测非回环的本地 IP
  if command -v ip >/dev/null 2>&1; then
    DETECTED_IP=\$(ip route get 8.8.8.8 2>/dev/null | awk '{print \$7; exit}' || echo "")
  elif command -v ifconfig >/dev/null 2>&1; then
    DETECTED_IP=\$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1 || echo "")
  fi
  
  if [ -n "\${DETECTED_IP}" ]; then
    SERVER_HOST="\${DETECTED_IP}"
  fi
fi

# 构建 bundle 的 URL
BUNDLE_URL="http://\${SERVER_HOST}:\${SERVER_PORT}/bundle"

log "服务器: \${SERVER_HOST}:\${SERVER_PORT}"
log "正在从 \${BUNDLE_URL} 下载 bundle: \$BUNDLE_NAME"

if command -v curl >/dev/null 2>&1; then
  curl -sSL "\$BUNDLE_URL" -o "\$BUNDLE_NAME"
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "\$BUNDLE_NAME" "\$BUNDLE_URL"
else
  err "未找到 curl 或 wget。请安装其中一个。"
  exit 1
fi

if [ ! -f "\$BUNDLE_NAME" ]; then
  err "下载 bundle 失败。"
  exit 1
fi

log "Bundle 已下载。正在解压..."

# 解压并恢复
TMPDIR=$(mktemp -d)
trap 'rm -rf "\$TMPDIR"' EXIT

tar -xzf "\$BUNDLE_NAME" -C "\$TMPDIR"

LISTFILE="\$TMPDIR/.codex_auth_paths.txt"
if [ ! -f "\$LISTFILE" ]; then
  log "未找到路径列表；正在推断..."
  (cd "\$TMPDIR" && find . -maxdepth 2 -type d \( -path './.config/codex' -o -path './.local/share/codex' -o -path './.codex' -o -path './.codex-external/*' \) | sed 's|^./||' > "\$LISTFILE")
fi

if [ ! -s "\$LISTFILE" ]; then
  err "未找到凭据路径。"
  exit 1
fi

log "正在恢复凭据..."
while IFS= read -r rel; do
  [ -z "\$rel" ] && continue
  src="\$TMPDIR/\$rel"
  dest="\$HOME/\$rel"
  
  mkdir -p "\$(dirname "\$dest")"
  if [ -e "\$dest" ]; then
    bkp="\${dest}.bak-\$(date +%Y%m%d-%H%M%S)"
    log "备份: \$dest -> \$bkp"
    mv "\$dest" "\$bkp"
  fi
  
  mkdir -p "\$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --chmod=Du+rwx,Fu+rw "\$src/" "\$dest/"
  else
    cp -a "\$src/." "\$dest/"
  fi
  
  find "\$dest" -type d -exec chmod 700 {} +
  find "\$dest" -type f -exec chmod 600 {} +
done < "\$LISTFILE"

rm -f "\$BUNDLE_NAME"
log "导入完成！"
log "注意: 某些 CLI 会将令牌绑定到主机/用户；如果 Codex 拒绝，请使用设备代码登录或隧道。"
IMPORT_SCRIPT_EOF
}

# 启动简单的 HTTP 服务器
do_serve() {
  local port="$1"
  local bundle_file="$2"
  
  if [ ! -f "$bundle_file" ]; then
    err "Bundle 未找到: $bundle_file"
    err "请先执行 'export' 创建 bundle。"
    exit 1
  fi

  # 检测本地 IP
  local local_ip
  if command -v ip >/dev/null 2>&1; then
    local_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || echo "localhost")
  elif command -v ifconfig >/dev/null 2>&1; then
    local_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1 || echo "localhost")
  else
    local_ip="localhost"
  fi

  # 生成导入脚本
  local import_script
  import_script=$(mktemp)
  generate_import_script "$local_ip" "$port" "$bundle_file" > "$import_script"
  trap 'rm -f "$import_script"' EXIT

  log "正在启动 HTTP 服务器，端口: $port..."
  log "Bundle: $bundle_file"
  log ""
  log "在远程服务器上导入，请执行:"
  log "  curl -sSL http://${local_ip}:${port}/import.sh | bash"
  log ""
  log "导入脚本会自动检测服务器地址。"
  log ""
  log "按 Ctrl+C 停止服务器。"
  log ""

  # 使用 Python 的简单 HTTP 服务器
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import http.server
import socketserver
import os
import sys

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/import.sh':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            with open('$import_script', 'rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/bundle':
            self.send_response(200)
            self.send_header('Content-type', 'application/gzip')
            self.send_header('Content-Disposition', 'attachment; filename=\"${bundle_file##*/}\"')
            self.end_headers()
            with open('$bundle_file', 'rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = '''<html><body>
<h1>Codex 凭据传输服务器</h1>
<p>Bundle: <code>${bundle_file##*/}</code></p>
<p>要导入，请执行:</p>
<pre>curl -sSL http://${local_ip}:${port}/import.sh | bash</pre>
</body></html>'''
            self.wfile.write(html.encode())
        else:
            self.send_response(404)
            self.end_headers()

with socketserver.TCPServer(('', $port), CustomHandler) as httpd:
    print(f'[codex-auth-transfer] 服务器运行在 http://0.0.0.0:$port')
    httpd.serve_forever()
"
  elif command -v python >/dev/null 2>&1; then
    python -c "
import SimpleHTTPServer
import SocketServer
import os

class CustomHandler(SimpleHTTPServer.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/import.sh':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            with open('$import_script') as f:
                self.wfile.write(f.read())
        elif self.path == '/bundle':
            self.send_response(200)
            self.send_header('Content-type', 'application/gzip')
            self.send_header('Content-Disposition', 'attachment; filename=\"${bundle_file##*/}\"')
            self.end_headers()
            with open('$bundle_file', 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()

httpd = SocketServer.TCPServer(('', $port), CustomHandler)
print('[codex-auth-transfer] 服务器运行在 http://0.0.0.0:$port')
httpd.serve_forever()
"
  else
    err "未找到 Python。请安装 python3 以使用 HTTP 服务器。"
    exit 1
  fi
}

# 交互式菜单
show_menu() {
  clear
  local default_bundle="${DEFAULT_BUNDLE:-codex-auth-bundle.tar.gz}"
  local default_port="${DEFAULT_PORT:-8888}"
  cat <<EOF
╔═══════════════════════════════════════════════════════════╗
║         Codex 凭据传输工具 - 交互式菜单                  ║
╚═══════════════════════════════════════════════════════════╝

1) 导出凭据（创建 bundle）
2) 导入凭据（从本地文件）
3) 启动 HTTP 服务器（分发 bundle）
4) 退出

请选择 [1-4]:
EOF
  read -r choice

  case "$choice" in
    1)
      echo ""
      echo "Bundle 文件名（回车使用默认: ${default_bundle}）:"
      read -r bundle_name
      bundle_name="${bundle_name:-${default_bundle}}"
      do_export "$bundle_name"
      echo ""
      echo "按回车继续..."
      read -r
      show_menu
      ;;
    2)
      echo ""
      echo "Bundle 文件路径（回车使用默认: ${default_bundle}）:"
      read -r bundle_file
      bundle_file="${bundle_file:-${default_bundle}}"
      echo ""
      echo "覆盖现有文件？(s/N):"
      read -r force_choice
      force=0
      if [[ "$force_choice" =~ ^[sS]$ ]]; then
        force=1
      fi
      do_import "$bundle_file" "$force"
      echo ""
      echo "按回车继续..."
      read -r
      show_menu
      ;;
    3)
      echo ""
      echo "Bundle 文件路径（回车使用默认: ${default_bundle}）:"
      read -r bundle_file
      bundle_file="${bundle_file:-${default_bundle}}"
      echo ""
      echo "服务器端口（回车使用默认: ${default_port}）:"
      read -r port_input
      port="${port_input:-${default_port}}"
      do_serve "$port" "$bundle_file"
      echo ""
      echo "按回车继续..."
      read -r
      show_menu
      ;;
    4)
      log "退出..."
      exit 0
      ;;
    *)
      err "无效选项。"
      sleep 1
      show_menu
      ;;
  esac
}

main() {
  # 如果没有参数，显示交互式菜单
  if [ $# -eq 0 ]; then
    show_menu
    exit 0
  fi

  local cmd=""
  local bundle=""
  local port="$DEFAULT_PORT"
  local force=0

  # 简单解析
  while [ $# -gt 0 ]; do
    case "$1" in
      export|import|serve)
        cmd="$1"; shift ;;
      -o|--output)
        bundle="${2:-}"; shift 2 ;;
      -f|--file)
        bundle="${2:-}"; shift 2 ;;
      --port)
        port="${2:-$DEFAULT_PORT}"; shift 2 ;;
      --force)
        force=1; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        err "未知选项: $1"; usage; exit 1 ;;
    esac
  done

  if [ -z "$cmd" ]; then
    usage; exit 1
  fi

  if [ -z "$bundle" ]; then
    bundle="$DEFAULT_BUNDLE"
  fi

  case "$cmd" in
    export)
      do_export "$bundle" ;;
    import)
      do_import "$bundle" "$force" ;;
    serve)
      do_serve "$port" "$bundle" ;;
  esac
}

main "$@"
