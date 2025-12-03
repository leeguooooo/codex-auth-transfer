# Codex Auth Transfer Tool / Codex 凭据传输工具

[English](#english) | [中文](#中文)

---

## English

### What this script does
- Export Codex CLI auth data from a machine where browser login works and re-import it on a headless/remote host.
- Only touches Codex data under your home (`~/.config/codex`, `~/.local/share/codex`, `~/.codex`) plus any path hinted by `codex config path`.
- Provides an interactive menu and direct subcommands (`export`, `import`, `serve`).
- Auto-fixes invalid `model_reasoning_effort` values during import.
- Bilingual output with auto-detection (or force via env vars).

### Requirements
- Bash on a POSIX system (export tested on Linux Mint; import tested on AlmaLinux; works in typical Linux/macOS shells).
- Optional: `rsync` for faster, permission-aware copies (falls back to `cp -a`).
- Optional for HTTP server mode: `python3` (or `python`).

### Quick start
1) On the signed-in source machine:
```bash
./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz
```
2) Copy the bundle securely to the target (e.g., `scp codex-auth-bundle.tar.gz user@server:`).
3) On the headless/remote target:
```bash
./codex-auth-transfer.sh import -f codex-auth-bundle.tar.gz --force
```

### CLI usage
- Interactive menu:
```bash
./codex-auth-transfer.sh
```
- Export bundle:
```bash
./codex-auth-transfer.sh export [-o codex-auth-bundle.tar.gz]
```
- Import bundle (`--force` backs up then overwrites):
```bash
./codex-auth-transfer.sh import [-f codex-auth-bundle.tar.gz] [--force]
```
- Serve bundle over HTTP for one-line remote import:
```bash
./codex-auth-transfer.sh serve [--port 8888] [--bundle codex-auth-bundle.tar.gz]
```
- Help:
```bash
./codex-auth-transfer.sh --help
```

### HTTP server workflow
1. Export the bundle on the source host.  
2. Start the server (defaults: port 8888, bundle `codex-auth-bundle.tar.gz`):
```bash
./codex-auth-transfer.sh serve
```
3. On the remote host, import in one line:
```bash
curl -sSL http://SERVER_IP:8888/import.sh | bash
```
   - If the auto-detected IP is wrong, override: `SERVER_HOST=your.ip curl -sSL http://localhost:8888/import.sh | bash`.

### Environment knobs
- `CODEX_AUTH_TRANSFER_LANG=en|zh` forces output language (otherwise uses `LANG`).
- `CODEX_AUTH_TRANSFER_NO_METADATA=1` omits `user`/`host` metadata from the manifest.
- `SERVER_HOST` / `SERVER_PORT` override the address used by the downloaded import script.

### Safety and notes
- The bundle contains credentials. Keep it private, do not commit it, and delete it after use.
- Bundle is created with `600` permissions; restored directories are `700` and files `600`.
- Some CLIs bind tokens to machine/hostname. If Codex rejects the imported login, use device-code login or tunnel to a browser.
- Importing with `--force` creates `.bak-YYYYmmdd-HHMMSS` backups before overwrite.
- Repository intentionally ships only the script and this README; no bundle is tracked.

### Files packaged
- `~/.config/codex`
- `~/.local/share/codex`
- `~/.codex`
- Any path reported by `codex config path` if available.

### License
- For non-commercial terms, consider PolyForm Noncommercial License 1.0.0 (not OSI open source).
- For true open source, pick a license that allows commercial use (permissive or copyleft).

---

## 中文

### 脚本能做什么
- 在能用浏览器登录的机器上导出 Codex CLI 凭据，并在无头/远程主机上导入。
- 仅触碰你主目录下的 Codex 数据（`~/.config/codex`、`~/.local/share/codex`、`~/.codex`），也会尝试 `codex config path` 提示的目录。
- 提供交互式菜单和 `export` / `import` / `serve` 子命令。
- 导入时自动修复无效的 `model_reasoning_effort`。
- 中英文自动检测，可用环境变量强制。

### 依赖
- POSIX 环境下的 Bash（已在 Linux Mint 导出、AlmaLinux 导入验证，常见 Linux/macOS shell 可用）。
- 可选：`rsync` 加速并保留权限（否则回退 `cp -a`）。
- HTTP 模式可选：`python3`（或 `python`）。

### 快速上手
1) 在已登录的源机器执行：
```bash
./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz
```
2) 通过安全方式拷贝到目标（如 `scp codex-auth-bundle.tar.gz user@server:`）。
3) 在无头/远程目标执行：
```bash
./codex-auth-transfer.sh import -f codex-auth-bundle.tar.gz --force
```

### 命令用法
- 交互式菜单：
```bash
./codex-auth-transfer.sh
```
- 导出 bundle：
```bash
./codex-auth-transfer.sh export [-o codex-auth-bundle.tar.gz]
```
- 导入 bundle（`--force` 会先备份再覆盖）：
```bash
./codex-auth-transfer.sh import [-f codex-auth-bundle.tar.gz] [--force]
```
- 启动 HTTP 服务分发 bundle：
```bash
./codex-auth-transfer.sh serve [--port 8888] [--bundle codex-auth-bundle.tar.gz]
```
- 查看帮助：
```bash
./codex-auth-transfer.sh --help
```

### HTTP 服务流程
1. 在源机器先导出 bundle。  
2. 启动服务（默认端口 8888，默认 bundle 名 `codex-auth-bundle.tar.gz`）：
```bash
./codex-auth-transfer.sh serve
```
3. 在远程主机一行导入：
```bash
curl -sSL http://服务器IP:8888/import.sh | bash
```
   - 如果自动检测到的 IP 不对，可覆盖：`SERVER_HOST=你的IP curl -sSL http://localhost:8888/import.sh | bash`。

### 环境变量
- `CODEX_AUTH_TRANSFER_LANG=en|zh` 强制语言（默认取 `LANG`）。
- `CODEX_AUTH_TRANSFER_NO_METADATA=1` 导出时不写入 `user` / `host` 元数据。
- `SERVER_HOST` / `SERVER_PORT` 覆盖下载的导入脚本使用的地址。

### 安全与提示
- bundle 含有凭据，不要提交或泄露，用完请删除。
- bundle 默认权限 `600`，导入后目录 `700`，文件 `600`。
- 某些 CLI 会将 token 绑定主机/用户，若 Codex 拒绝导入后的登录，请用设备码登录或通过隧道完成登录。
- 使用 `--force` 导入会先生成 `.bak-YYYYmmdd-HHMMSS` 备份再覆盖。
- 仓库只包含脚本和 README，不包含任何 bundle。

### 打包的内容
- `~/.config/codex`
- `~/.local/share/codex`
- `~/.codex`
- 如存在，`codex config path` 提示的目录。

### 许可说明
- 如需非商业条款，可考虑 PolyForm Noncommercial License 1.0.0（非 OSI 开源）。
- 若需要真正的开源许可，请选择允许商业使用的宽松或共软许可。
