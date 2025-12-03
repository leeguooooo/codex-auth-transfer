#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# codex-auth-transfer.sh
# Export and import Codex CLI authentication credentials between machines
# 在机器之间导出和导入 Codex CLI 的认证凭据
#
# Interactive usage (no arguments):
# 交互式使用（无参数）:
#   ./codex-auth-transfer.sh
#
# Direct usage:
# 直接使用:
#   ./codex-auth-transfer.sh export [-o file.tar.gz]
#   ./codex-auth-transfer.sh import [-f file.tar.gz] [--force]
#   ./codex-auth-transfer.sh serve [--port PORT] [--bundle file.tar.gz]

PROGRAM="codex-auth-transfer"
DEFAULT_BUNDLE="codex-auth-bundle.tar.gz"
DEFAULT_PORT=8888

# Detect language: supports CODEX_AUTH_TRANSFER_LANG env var or system LANG
# 检测语言：支持环境变量 CODEX_AUTH_TRANSFER_LANG 或系统 LANG
detect_language() {
  if [ -n "${CODEX_AUTH_TRANSFER_LANG:-}" ]; then
    case "${CODEX_AUTH_TRANSFER_LANG}" in
      en|EN|en_US|en_*) echo "en" ;;
      zh|ZH|zh_CN|zh_TW|zh_*) echo "zh" ;;
      *) echo "en" ;;
    esac
  elif [ -n "${LANG:-}" ]; then
    case "${LANG}" in
      zh_*|zh-*) echo "zh" ;;
      *) echo "en" ;;
    esac
  else
    echo "en"
  fi
}

LANG_CODE=$(detect_language)

# Translation function
# 翻译函数
_() {
  local key="$1"
  if [ "$LANG_CODE" = "zh" ]; then
    case "$key" in
      # Error/Info labels
      error) echo "错误" ;;
      info) echo "信息" ;;
      # Usage
      usage_title) echo "用法:" ;;
      usage_interactive) echo "  $0                    交互式菜单" ;;
      usage_export) echo "  $0 export [-o 文件名.tar.gz]" ;;
      usage_import) echo "  $0 import [-f 文件名.tar.gz] [--force]" ;;
      usage_serve) echo "  $0 serve [--port 端口] [--bundle 文件名.tar.gz]" ;;
      options_title) echo "选项:" ;;
      opt_export) echo "  export              打包当前机器的 Codex 凭据" ;;
      opt_import) echo "  import              在目标主机（无头服务器）上恢复凭据" ;;
      opt_serve) echo "  serve               启动 HTTP 服务器以分发 bundle" ;;
      opt_output) echo "  -o, --output        输出文件名（默认: ${DEFAULT_BUNDLE}）" ;;
      opt_file) echo "  -f, --file          要导入的 .tar.gz 文件（默认: ${DEFAULT_BUNDLE}）" ;;
      opt_port) echo "  --port              HTTP 服务器端口（默认: ${DEFAULT_PORT}）" ;;
      opt_force) echo "  --force             不询问直接覆盖目标目录（会先备份）" ;;
      opt_help) echo "  -h, --help          显示此帮助信息" ;;
      notes_title) echo "说明:" ;;
      note_bundle) echo "  - Bundle 包含相对路径（例如: .config/codex, .local/share/codex）" ;;
      note_backup) echo "  - 导入时，如果目标已存在（例如: ~/.config/codex），会在复制前" ;;
      note_backup2) echo "    创建备份 <目标>.bak-YYYYmmdd-HHMMSS" ;;
      note_curl) echo "  - 通过 curl 导入: curl -sSL http://IP:端口/import.sh | bash" ;;
      # Messages
      searching) echo "正在查找 Codex 凭据目录..." ;;
      not_found) echo "未找到 Codex 凭据目录。中止。" ;;
      detected) echo "检测到的目录:" ;;
      creating) echo "Bundle 已创建:" ;;
      save_security) echo "请安全保存此文件。" ;;
      extracting) echo "正在解压 bundle..." ;;
      restoring) echo "正在恢复凭据..." ;;
      restored) echo "凭据已恢复到" ;;
      checking_config) echo "正在检查并修复配置..." ;;
      config_fixed) echo "配置修复完成。" ;;
      config_ok) echo "配置检查完成，无需修复。" ;;
      import_start) echo "正在开始导入 Codex 凭据..." ;;
      server) echo "服务器:" ;;
      downloading) echo "正在从" ;;
      download_bundle) echo "下载 bundle:" ;;
      downloaded) echo "Bundle 已下载。正在解压..." ;;
      backup) echo "备份:" ;;
      import_done) echo "导入完成！" ;;
      warning) echo "注意: 某些 CLI 会将令牌绑定到主机/用户；如果 Codex 拒绝，请使用设备代码登录或隧道。" ;;
      file_not_found) echo "文件未找到:" ;;
      paths_not_found) echo "Bundle 中未找到路径列表；正在推断..." ;;
      no_credentials) echo "未找到要恢复的凭据路径。中止。" ;;
      paths_to_restore) echo "要恢复的路径:" ;;
      dest_exists) echo "目标已存在:" ;;
      reexecute_force) echo "使用 --force 重新执行以进行备份并覆盖。" ;;
      backup_existing) echo "备份现有目标:" ;;
      starting_server) echo "正在启动 HTTP 服务器，端口:" ;;
      detected_ip) echo "检测到的服务器 IP:" ;;
      remote_import) echo "在远程服务器上导入，请执行:" ;;
      if_wrong_ip) echo "  # 如果检测到的 IP 不正确，请手动指定:" ;;
      if_failed) echo "如果连接失败，请手动指定服务器 IP:" ;;
      press_ctrl_c) echo "按 Ctrl+C 停止服务器。" ;;
      bundle_not_found) echo "Bundle 未找到:" ;;
      run_export_first) echo "请先执行 'export' 创建 bundle。" ;;
      no_ip_warning) echo "警告: 无法检测到有效的 IP 地址，使用 localhost。" ;;
      no_ip_manual) echo "如果无法连接，请手动指定服务器 IP: SERVER_HOST=你的IP curl -sSL http://localhost:" ;;
      no_python) echo "未找到 Python。请安装 python3 以使用 HTTP 服务器。" ;;
      fix_config) echo "修复配置:" ;;
      fixed_config) echo "已修复配置:" ;;
      source_not_exists) echo "源路径不存在:" ;;
      menu_title) echo "Codex 凭据传输工具 - 交互式菜单" ;;
      menu_1) echo "1) 导出凭据（创建 bundle）" ;;
      menu_2) echo "2) 导入凭据（从本地文件）" ;;
      menu_3) echo "3) 启动 HTTP 服务器（分发 bundle）" ;;
      menu_4) echo "4) 退出" ;;
      choose) echo "请选择 [1-4]:" ;;
      bundle_name_prompt) echo "Bundle 文件名（回车使用默认:" ;;
      bundle_path_prompt) echo "Bundle 文件路径（回车使用默认:" ;;
      overwrite_prompt) echo "覆盖现有文件？(s/N):" ;;
      port_prompt) echo "服务器端口（回车使用默认:" ;;
      press_enter) echo "按回车继续..." ;;
      exiting) echo "退出..." ;;
      invalid_option) echo "无效选项。" ;;
      unknown_option) echo "未知选项:" ;;
      *) echo "$key" ;;
    esac
  else
    case "$key" in
      # Error/Info labels
      error) echo "ERROR" ;;
      info) echo "INFO" ;;
      # Usage
      usage_title) echo "Usage:" ;;
      usage_interactive) echo "  $0                    Interactive menu" ;;
      usage_export) echo "  $0 export [-o file.tar.gz]" ;;
      usage_import) echo "  $0 import [-f file.tar.gz] [--force]" ;;
      usage_serve) echo "  $0 serve [--port PORT] [--bundle file.tar.gz]" ;;
      options_title) echo "Options:" ;;
      opt_export) echo "  export              Package Codex credentials from current machine" ;;
      opt_import) echo "  import              Restore credentials on target host (headless)" ;;
      opt_serve) echo "  serve               Start HTTP server to distribute bundle" ;;
      opt_output) echo "  -o, --output        Output filename (default: ${DEFAULT_BUNDLE})" ;;
      opt_file) echo "  -f, --file          .tar.gz file to import (default: ${DEFAULT_BUNDLE})" ;;
      opt_port) echo "  --port              HTTP server port (default: ${DEFAULT_PORT})" ;;
      opt_force) echo "  --force             Overwrite destination directories without asking (backup first)" ;;
      opt_help) echo "  -h, --help          Show this help" ;;
      notes_title) echo "Notes:" ;;
      note_bundle) echo "  - Bundle contains relative paths (e.g.: .config/codex, .local/share/codex)" ;;
      note_backup) echo "  - During import, if destination exists (e.g.: ~/.config/codex), a backup" ;;
      note_backup2) echo "    <destination>.bak-YYYYmmdd-HHMMSS will be created before copying" ;;
      note_curl) echo "  - Import via curl: curl -sSL http://IP:PORT/import.sh | bash" ;;
      # Messages
      searching) echo "Searching for Codex credential directories..." ;;
      not_found) echo "No Codex credential directories found. Aborting." ;;
      detected) echo "Detected directories:" ;;
      creating) echo "Bundle created:" ;;
      save_security) echo "Please store this file securely." ;;
      extracting) echo "Extracting bundle..." ;;
      restoring) echo "Restoring credentials..." ;;
      restored) echo "Credentials restored to" ;;
      checking_config) echo "Checking and fixing configuration..." ;;
      config_fixed) echo "Configuration fixed." ;;
      config_ok) echo "Configuration check completed, no fixes needed." ;;
      import_start) echo "Starting Codex credential import..." ;;
      server) echo "Server:" ;;
      downloading) echo "Downloading bundle from" ;;
      download_bundle) echo "Downloading bundle:" ;;
      downloaded) echo "Bundle downloaded. Extracting..." ;;
      backup) echo "Backup:" ;;
      import_done) echo "Import completed!" ;;
      warning) echo "Note: Some CLIs bind tokens to host/user; if Codex refuses, use device code login or tunnel." ;;
      file_not_found) echo "File not found:" ;;
      paths_not_found) echo "Path list not found in bundle; inferring..." ;;
      no_credentials) echo "No credential paths found to restore. Aborting." ;;
      paths_to_restore) echo "Paths to restore:" ;;
      dest_exists) echo "Destination already exists:" ;;
      reexecute_force) echo "Reexecute with --force to backup and overwrite." ;;
      backup_existing) echo "Backing up existing destination:" ;;
      starting_server) echo "Starting HTTP server on port:" ;;
      detected_ip) echo "Detected server IP:" ;;
      remote_import) echo "To import on remote server, execute:" ;;
      if_wrong_ip) echo "  # If detected IP is incorrect, specify manually:" ;;
      if_failed) echo "If connection fails, specify server IP manually:" ;;
      press_ctrl_c) echo "Press Ctrl+C to stop server." ;;
      bundle_not_found) echo "Bundle not found:" ;;
      run_export_first) echo "Run 'export' first to create bundle." ;;
      no_ip_warning) echo "Warning: Unable to detect valid IP address, using localhost." ;;
      no_ip_manual) echo "If unable to connect, specify server IP manually: SERVER_HOST=YOUR_IP curl -sSL http://localhost:" ;;
      no_python) echo "Python not found. Install python3 to use HTTP server." ;;
      fix_config) echo "Fixing config:" ;;
      fixed_config) echo "Fixed config:" ;;
      source_not_exists) echo "Source path does not exist:" ;;
      menu_title) echo "Codex Auth Transfer - Interactive Menu" ;;
      menu_1) echo "1) Export credentials (create bundle)" ;;
      menu_2) echo "2) Import credentials (from local file)" ;;
      menu_3) echo "3) Start HTTP server (distribute bundle)" ;;
      menu_4) echo "4) Exit" ;;
      choose) echo "Choose [1-4]:" ;;
      bundle_name_prompt) echo "Bundle filename (Enter for default:" ;;
      bundle_path_prompt) echo "Bundle file path (Enter for default:" ;;
      overwrite_prompt) echo "Overwrite existing files? (y/N):" ;;
      port_prompt) echo "Server port (Enter for default:" ;;
      press_enter) echo "Press Enter to continue..." ;;
      exiting) echo "Exiting..." ;;
      invalid_option) echo "Invalid option." ;;
      unknown_option) echo "Unknown option:" ;;
      *) echo "$key" ;;
    esac
  fi
}

log() { printf '[%s] %s\n' "$PROGRAM" "$*"; }
err() { printf '[%s][%s] %s\n' "$PROGRAM" "$(_ error)" "$*" 1>&2; }
info() { printf '[%s][%s] %s\n' "$PROGRAM" "$(_ info)" "$*"; }

usage() {
  cat <<EOF
$(_ usage_title)
$(_ usage_interactive)
$(_ usage_export)
$(_ usage_import)
$(_ usage_serve)

$(_ options_title)
$(_ opt_export)
$(_ opt_import)
$(_ opt_serve)
$(_ opt_output)
$(_ opt_file)
$(_ opt_port)
$(_ opt_force)
$(_ opt_help)

$(_ notes_title)
$(_ note_bundle)
$(_ note_backup)
$(_ note_backup2)
$(_ note_curl)
EOF
}

# Collect candidate paths containing Codex credentials
# 收集包含 Codex 凭据的候选路径
find_codex_paths() {
  local base_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  local base_data="${XDG_DATA_HOME:-$HOME/.local/share}"

  local candidates=(
    "$base_config/codex"
    "$base_data/codex"
    "$HOME/.codex"
  )

  # If there's a command to point to the directory, try to use it (best effort)
  # 如果有命令可以指向目录，尝试使用它（尽力而为）
  if command -v codex >/dev/null 2>&1; then
    # Some versions may have a subcommand that reveals config; ignore errors
    # 某些版本可能有显示配置路径的子命令；忽略错误
    set +e
    local hinted
    hinted=$(codex config path 2>/dev/null || true)
    set -e
    if [ -n "${hinted:-}" ] && [ -d "$hinted" ]; then
      candidates=("$hinted" "${candidates[@]}")
    fi
  fi

  # Filter existing ones
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

  log "$(_ searching)"
  paths=()
  local tmpfile
  tmpfile=$(mktemp)
  find_codex_paths > "$tmpfile"
  while IFS= read -r line; do
    [ -n "$line" ] && paths+=("$line")
  done < "$tmpfile"
  rm -f "$tmpfile"
  if [ "${#paths[@]}" -eq 0 ]; then
    err "$(_ not_found)"
    exit 1
  fi

  log "$(_ detected)"; printf '  - %s\n' "${paths[@]}"

  # Build structure relative to HOME (.config/.local/...)
  # 构建相对于 HOME 的结构 (.config/.local/...)
  mkdir -p "$tmpdir/stage"

  local listfile="$tmpdir/stage/.codex_auth_paths.txt"
  : > "$listfile"

  for p in "${paths[@]}"; do
    # Convert absolute path to relative to HOME when possible
    # 尽可能将绝对路径转换为相对于 HOME 的路径
    local rel
    if [[ "$p" == "$HOME/"* ]]; then
      rel=".${p#"$HOME"}"
    else
      # If not under $HOME, place in .codex-external/<hash>
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
      # Use cp -a as fallback
      # 使用 cp -a 作为后备
      mkdir -p "$dest"
      cp -a "$p/." "$dest/"
      # Adjust permissions in staging
      # 在暂存区调整权限
      find "$dest" -type d -exec chmod 700 {} +
      find "$dest" -type f -exec chmod 600 {} +
    fi

    printf '%s\n' "$rel" >> "$listfile"
  done

  # Create simple manifest (without user/host data if CODEX_AUTH_TRANSFER_NO_METADATA=1)
  # 创建简单的清单（如果 CODEX_AUTH_TRANSFER_NO_METADATA=1 则不包含用户/主机数据）
  {
    echo "created_at=$(date -Iseconds)"
    echo "paths_file=.codex_auth_paths.txt"
    if [ "${CODEX_AUTH_TRANSFER_NO_METADATA:-0}" != "1" ]; then
      echo "user=$USER"
      echo "host=$(hostname -f 2>/dev/null || hostname)"
    fi
  } > "$tmpdir/stage/.codex_auth_manifest"

  # Package outside the folder being archived to avoid loop
  # 打包到正在归档的文件夹外部以避免循环
  tar -czf "${PWD}/${bundle##*/}" -C "$tmpdir/stage" .
  chmod 600 "${PWD}/${bundle##*/}"
  log "$(_ creating) ${PWD}/${bundle##*/}"
  log "$(_ save_security)"
}

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ]; then
    local bkp="${target}.bak-$(timestamp)"
    log "$(_ backup_existing) $target -> $bkp"
    mv "$target" "$bkp"
  fi
}

do_import() {
  local bundle="$1"
  local force="$2"

  if [ ! -f "$bundle" ]; then
    err "$(_ file_not_found) $bundle"
    exit 1
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'test -n "${tmpdir:-}" && rm -rf "$tmpdir"' EXIT

  log "$(_ extracting)"
  tar -xzf "$bundle" -C "$tmpdir"

  # Determine list of paths to restore
  # 确定要恢复的路径列表
  local listfile="$tmpdir/.codex_auth_paths.txt"
  if [ ! -f "$listfile" ]; then
    # Fallback: infer from content
    # 后备：从内容推断
    log "$(_ paths_not_found)"
    (cd "$tmpdir" && find . -maxdepth 2 -type d \( -path './.config/codex' -o -path './.local/share/codex' -o -path './.codex' -o -path './.codex-external/*' \) | sed 's|^./||' > "$listfile")
  fi

  if [ ! -s "$listfile" ]; then
    err "$(_ no_credentials)"
    exit 1
  fi

  log "$(_ paths_to_restore)"; sed 's/^/  - /' "$listfile"

  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    local src="$tmpdir/$rel"
    local dest="$HOME/$rel"

    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ]; then
      if [ "$force" = "1" ]; then
        backup_if_exists "$dest"
      else
        err "$(_ dest_exists) $dest"
        err "$(_ reexecute_force)"
        exit 1
      fi
    fi

    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --chmod=Du+rwx,Fu+rw "$src/" "$dest/"
    else
      cp -a "$src/." "$dest/"
    fi

    # Secure permissions
    # 安全权限
    find "$dest" -type d -exec chmod 700 {} +
    find "$dest" -type f -exec chmod 600 {} +
  done < "$listfile"

  log "$(_ restored) $HOME."
  log "$(_ warning)"
}

# Generate import script that can be downloaded via curl
# 生成可通过 curl 下载的导入脚本
generate_import_script() {
  local server_host="$1"
  local server_port="$2"
  local bundle_file="$3"
  local bundle_name="${bundle_file##*/}"
  # Use unquoted heredoc, but escape all variables that need to be expanded at runtime
  # 使用不带引号的 heredoc，但转义所有需要在运行时展开的变量
  cat <<IMPORT_SCRIPT_EOF
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=\$'\\n\\t'

PROGRAM="codex-auth-import"
log() { printf '[%s] %s\\n' "\$PROGRAM" "\$*"; }
err() { printf '[%s][ERROR] %s\\n' "\$PROGRAM" "\$*" 1>&2; }

log "Starting Codex credential import..."

# Server address and port (passed from server side)
# 服务器地址和端口（从服务器端传入）
DEFAULT_SERVER_HOST="${server_host}"
DEFAULT_SERVER_PORT="${server_port}"
BUNDLE_NAME="${bundle_name}"

# Allow override via environment variable or command line argument
# 允许通过环境变量或命令行参数覆盖服务器地址
# Usage: SERVER_HOST=192.168.0.12 curl -sSL http://.../import.sh | bash
# 使用方法: SERVER_HOST=192.168.0.12 curl -sSL http://.../import.sh | bash
SERVER_HOST="\${SERVER_HOST:-\${DEFAULT_SERVER_HOST}}"
SERVER_PORT="\${SERVER_PORT:-\${DEFAULT_SERVER_PORT}}"

# If server address is localhost or 127.x.x.x, warn user
# 如果服务器地址是 localhost 或 127.x.x.x，提示用户
if [[ "\${SERVER_HOST}" =~ ^(localhost|127\\.) ]] || [ -z "\${SERVER_HOST}" ]; then
  err "Warning: Server address is \${SERVER_HOST}, may not be accessible from remote."
  err "Please specify correct server IP using environment variable:"
  err "  SERVER_HOST=192.168.0.12 curl -sSL http://\${SERVER_HOST}:\${SERVER_PORT}/import.sh | bash"
  err "Or modify SERVER_HOST variable in the import script directly."
fi

# Build bundle URL
# 构建 bundle 的 URL
BUNDLE_URL="http://\${SERVER_HOST}:\${SERVER_PORT}/bundle"

log "Server: \${SERVER_HOST}:\${SERVER_PORT}"
log "Downloading bundle: \${BUNDLE_NAME} from \${BUNDLE_URL}"

if command -v curl >/dev/null 2>&1; then
  curl -sSL "\${BUNDLE_URL}" -o "\${BUNDLE_NAME}"
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "\${BUNDLE_NAME}" "\${BUNDLE_URL}"
else
  err "curl or wget not found. Please install one of them."
  exit 1
fi

if [ ! -f "\${BUNDLE_NAME}" ]; then
  err "Failed to download bundle."
  exit 1
fi

log "Bundle downloaded. Extracting..."

# Extract and restore
# 解压并恢复
TMPDIR=\$(mktemp -d)
if [ ! -d "\${TMPDIR}" ]; then
  err "Unable to create temporary directory."
  exit 1
fi
trap 'rm -rf "\${TMPDIR}"' EXIT

# Ensure temporary directory exists and is accessible
# 确保临时目录存在且可访问
if [ ! -w "\${TMPDIR}" ]; then
  err "Temporary directory is not writable: \${TMPDIR}"
  exit 1
fi

tar -xzf "\${BUNDLE_NAME}" -C "\${TMPDIR}" || {
  err "Failed to extract bundle."
  exit 1
}

LISTFILE="\${TMPDIR}/.codex_auth_paths.txt"
if [ ! -f "\${LISTFILE}" ]; then
  log "Path list not found; inferring..."
  (cd "\${TMPDIR}" && find . -maxdepth 2 -type d \( -path './.config/codex' -o -path './.local/share/codex' -o -path './.codex' -o -path './.codex-external/*' \) | sed 's|^./||' > "\${LISTFILE}")
fi

if [ ! -s "\${LISTFILE}" ]; then
  err "No credential paths found."
  exit 1
fi

log "Restoring credentials..."
while IFS= read -r rel || [ -n "\${rel}" ]; do
  [ -z "\${rel}" ] && continue
  src="\${TMPDIR}/\${rel}"
  dest="\${HOME}/\${rel}"
  
  if [ ! -e "\${src}" ]; then
    err "Source path does not exist: \${src}"
    continue
  fi
  
  mkdir -p "\$(dirname "\${dest}")"
  if [ -e "\${dest}" ]; then
    bkp="\${dest}.bak-\$(date +%Y%m%d-%H%M%S)"
    log "Backup: \${dest} -> \${bkp}"
    mv "\${dest}" "\${bkp}"
  fi
  
  mkdir -p "\${dest}"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --chmod=Du+rwx,Fu+rw "\${src}/" "\${dest}/"
  else
    cp -a "\${src}/." "\${dest}/"
  fi
  
  find "\${dest}" -type d -exec chmod 700 {} +
  find "\${dest}" -type f -exec chmod 600 {} +
done < "\${LISTFILE}"

# Auto-fix Codex configuration errors
# 自动修复 Codex 配置错误
log "Checking and fixing configuration..."
config_fixed=0

# Fix all restored Codex configuration directories
# 修复所有恢复的 Codex 配置目录中的配置文件
while IFS= read -r rel || [ -n "\${rel}" ]; do
  [ -z "\${rel}" ] && continue
  dest="\${HOME}/\${rel}"
  if [ ! -d "\${dest}" ]; then
    continue
  fi
  
  # Find all config files and fix them
  # 查找所有配置文件并修复
  find "\${dest}" -maxdepth 3 -type f \( -name "*.toml" -o -name "*.json" -o -name "config" \) 2>/dev/null | while read -r config_file; do
    if [ ! -f "\${config_file}" ] || [ ! -w "\${config_file}" ]; then
      continue
    fi
    
    # Check if contains model_reasoning_effort config
    # 检查是否包含 model_reasoning_effort 配置
    if ! grep -q "model_reasoning_effort" "\${config_file}" 2>/dev/null; then
      continue
    fi
    
    # Check if contains invalid value (xhigh or other non-standard values)
    # 检查是否包含无效值（xhigh 或其他非标准值）
    needs_fix=0
    current_value=""
    
    # Extract current value
    # 提取当前值
    if grep -qE 'model_reasoning_effort\s*=' "\${config_file}" 2>/dev/null; then
      # TOML format: model_reasoning_effort = "xhigh"
      current_value=\$(grep -E 'model_reasoning_effort\s*=' "\${config_file}" | \
        sed -E 's/.*model_reasoning_effort\s*=\s*["\047]?([^"\047\s,}]+).*/\1/' | head -1 | tr -d ' ')
    elif grep -qE '"model_reasoning_effort"' "\${config_file}" 2>/dev/null; then
      # JSON format: "model_reasoning_effort": "xhigh"
      current_value=\$(grep -E '"model_reasoning_effort"' "\${config_file}" | \
        sed -E 's/.*"model_reasoning_effort"\s*:\s*"([^"]+)".*/\1/' | head -1)
    fi
    
    # Check if valid value
    # 检查是否为有效值
    if [ -n "\${current_value}" ]; then
      case "\${current_value}" in
        minimal|low|medium|high) needs_fix=0 ;;
        *) needs_fix=1 ;;
      esac
    fi
    
    # If needs fixing
    # 如果需要修复
    if [ "\${needs_fix}" = "1" ]; then
      log "Fixing config: \${config_file} (model_reasoning_effort: \${current_value} -> high)"
      
      # Create temporary file
      # 创建临时文件
      tmp_file="\${config_file}.fix_tmp"
      sed_success=0
      
      # Try to fix TOML format
      # 尝试修复 TOML 格式
      if sed -E 's/(model_reasoning_effort\s*=\s*["\047]?)[^"\047\s,}]+/\1high/g' "\${config_file}" > "\${tmp_file}" 2>/dev/null; then
        sed_success=1
      # Try to fix JSON format
      # 尝试修复 JSON 格式
      elif sed -E 's/("model_reasoning_effort"\s*:\s*")[^"]+/\1high/g' "\${config_file}" > "\${tmp_file}" 2>/dev/null; then
        sed_success=1
      fi
      
      # macOS compatibility: if no -E, try basic sed
      # macOS 兼容性：如果没有 -E，尝试基本 sed
      if [ "\${sed_success}" = "0" ]; then
        if sed 's/xhigh/high/g' "\${config_file}" > "\${tmp_file}" 2>/dev/null; then
          sed_success=1
        fi
      fi
      
      if [ "\${sed_success}" = "1" ] && [ -f "\${tmp_file}" ] && [ -s "\${tmp_file}" ]; then
        mv "\${tmp_file}" "\${config_file}"
        chmod 600 "\${config_file}" 2>/dev/null
        config_fixed=1
      else
        rm -f "\${tmp_file}" 2>/dev/null
      fi
    fi
  done
done < "\${LISTFILE}"

if [ "\${config_fixed}" = "1" ]; then
  log "Configuration fixed."
else
  log "Configuration check completed, no fixes needed."
fi

rm -f "\${BUNDLE_NAME}"
log "Import completed!"
log "Note: Some CLIs bind tokens to host/user; if Codex refuses, use device code login or tunnel."
IMPORT_SCRIPT_EOF
}

# Start simple HTTP server
# 启动简单的 HTTP 服务器
do_serve() {
  local port="$1"
  local bundle_file="$2"
  
  if [ ! -f "$bundle_file" ]; then
    err "$(_ bundle_not_found) $bundle_file"
    err "$(_ run_export_first)"
    exit 1
  fi

  # Detect local IP (exclude all 127.x.x.x loopback addresses, prefer LAN IP)
  # 检测本地 IP（排除所有 127.x.x.x 回环地址，优先选择局域网 IP）
  local local_ip
  if command -v ip >/dev/null 2>&1; then
    # Method 1: Get exit IP of default route
    # 方法1: 获取默认路由的出口 IP
    local_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' 2>/dev/null || \
               ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}' 2>/dev/null || echo "")
    
    # If detected is loopback or empty, get from all interfaces
    # 如果检测到的是回环地址或为空，从所有接口获取
    if [[ "$local_ip" =~ ^127\. ]] || [ -z "$local_ip" ]; then
      # Prefer private addresses (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
      # 优先选择私有地址（192.168.x.x, 10.x.x.x, 172.16-31.x.x）
      local_ip=$(ip -4 addr show 2>/dev/null | grep -oP 'inet \K[0-9.]+' | \
                 grep -vE '^127\.' | \
                 grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | head -1 || \
                 ip -4 addr show 2>/dev/null | grep -oP 'inet \K[0-9.]+' | grep -v '^127\.' | head -1 || echo "")
    fi
  elif command -v ifconfig >/dev/null 2>&1; then
    # Prefer private addresses
    # 优先选择私有地址
    local_ip=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | \
               grep -Eo '([0-9]*\.){3}[0-9]*' | \
               grep -vE '^127\.' | \
               grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' | head -1 || \
               ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | \
               grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '^127\.' | head -1 || echo "")
  fi
  
  # If still not found, use localhost
  # 如果仍然没有找到，使用 localhost
  if [ -z "$local_ip" ] || [[ "$local_ip" =~ ^127\. ]]; then
    local_ip="localhost"
    log "$(_ no_ip_warning)"
    log "$(_ no_ip_manual)${port}/import.sh | bash"
  fi

  # Generate import script
  # 生成导入脚本
  local import_script
  import_script=$(mktemp)
  {
    generate_import_script "$local_ip" "$port" "$bundle_file"
  } > "$import_script"
  trap 'rm -f "$import_script"' EXIT

  log "$(_ starting_server) $port..."
  log "Bundle: $bundle_file"
  log "$(_ detected_ip) $local_ip"
  log ""
  log "$(_ remote_import)"
  if [[ "$local_ip" =~ ^(localhost|127\.) ]]; then
    log "$(_ if_wrong_ip)"
    log "  SERVER_HOST=YOUR_IP curl -sSL http://${local_ip}:${port}/import.sh | bash"
  else
    log "  curl -sSL http://${local_ip}:${port}/import.sh | bash"
    log ""
    log "$(_ if_failed)"
    log "  SERVER_HOST=YOUR_IP curl -sSL http://${local_ip}:${port}/import.sh | bash"
  fi
  log ""
  log "$(_ press_ctrl_c)"
  log ""

  # Simple HTTP server using Python
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
<h1>Codex Auth Transfer Server</h1>
<p>Bundle: <code>${bundle_file##*/}</code></p>
<p>To import, execute:</p>
<pre>curl -sSL http://${local_ip}:${port}/import.sh | bash</pre>
</body></html>'''
            self.wfile.write(html.encode())
        else:
            self.send_response(404)
            self.end_headers()

with socketserver.TCPServer(('', $port), CustomHandler) as httpd:
    print(f'[codex-auth-transfer] Server running on http://0.0.0.0:$port')
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
print('[codex-auth-transfer] Server running on http://0.0.0.0:$port')
httpd.serve_forever()
"
  else
    err "$(_ no_python)"
    exit 1
  fi
}

# Interactive menu
# 交互式菜单
show_menu() {
  clear
  local default_bundle="${DEFAULT_BUNDLE:-codex-auth-bundle.tar.gz}"
  local default_port="${DEFAULT_PORT:-8888}"
  cat <<EOF
╔═══════════════════════════════════════════════════════════╗
║         $(_ menu_title)                  ║
╚═══════════════════════════════════════════════════════════╝

$(_ menu_1)
$(_ menu_2)
$(_ menu_3)
$(_ menu_4)

$(_ choose)
EOF
  read -r choice

  case "$choice" in
    1)
      echo ""
      echo "$(_ bundle_name_prompt) ${default_bundle}):"
      read -r bundle_name
      bundle_name="${bundle_name:-${default_bundle}}"
      do_export "$bundle_name"
      echo ""
      echo "$(_ press_enter)"
      read -r
      show_menu
      ;;
    2)
      echo ""
      echo "$(_ bundle_path_prompt) ${default_bundle}):"
      read -r bundle_file
      bundle_file="${bundle_file:-${default_bundle}}"
      echo ""
      echo "$(_ overwrite_prompt)"
      read -r force_choice
      force=0
      if [[ "$force_choice" =~ ^[sSyY]$ ]]; then
        force=1
      fi
      do_import "$bundle_file" "$force"
      echo ""
      echo "$(_ press_enter)"
      read -r
      show_menu
      ;;
    3)
      echo ""
      echo "$(_ bundle_path_prompt) ${default_bundle}):"
      read -r bundle_file
      bundle_file="${bundle_file:-${default_bundle}}"
      echo ""
      echo "$(_ port_prompt) ${default_port}):"
      read -r port_input
      port="${port_input:-${default_port}}"
      do_serve "$port" "$bundle_file"
      echo ""
      echo "$(_ press_enter)"
      read -r
      show_menu
      ;;
    4)
      log "$(_ exiting)"
      exit 0
      ;;
    *)
      err "$(_ invalid_option)"
      sleep 1
      show_menu
      ;;
  esac
}

main() {
  # If no arguments, show interactive menu
  # 如果没有参数，显示交互式菜单
  if [ $# -eq 0 ]; then
    show_menu
    exit 0
  fi

  local cmd=""
  local bundle=""
  local port="$DEFAULT_PORT"
  local force=0

  # Simple parsing
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
        err "$(_ unknown_option) $1"; usage; exit 1 ;;
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
