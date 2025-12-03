# Codex Auth Transfer Tool / Codex 凭据传输工具

[English](#english) | [中文](#中文)

---

## English

### Overview

- **Purpose**: Export Codex CLI authentication data from a machine that can log in with a browser and import it on a headless/remote server.
- **Why**: Codex CLI sign-in requires a local browser. This script lets you authorize on one host and securely transfer the credentials to another.
- **Scope**: Only operates on your local user's Codex CLI data under your home directory.

### Features

- **Export**: Collects `~/.config/codex`, `~/.local/share/codex`, and `~/.codex` (if they exist), stages them with restrictive permissions, writes a simple manifest, and packs everything into a tarball.
- **Import**: Extracts, optionally backs up existing destinations with suffix `.bak-YYYYmmdd-HHMMSS` (when using `--force`), copies directories into `$HOME`, and enforces `700` on folders and `600` on files.
- **Detection**: When available, uses `codex config path` as an additional hint for where Codex stores data.
- **Security**: The exported bundle is created with permission `600`. Transport it only over secure channels such as `scp`, `rsync` over SSH, or similar.
- **Auto-fix Configuration**: Automatically detects and fixes invalid `model_reasoning_effort` values (e.g., `xhigh` → `high`) in Codex configuration files.
- **Multi-language Support**: Automatically detects system language and displays messages in English or Chinese.

### Background

- **Context**: Codex CLI's sign-in flow requires a local browser, which blocks straightforward installation on headless or remote servers.
- **Why this script exists**: This script allows you to export Codex CLI auth from a workstation that can complete browser-based login and then import it on a headless server.
- **Development platforms**: Export crafted on Linux Mint; import successfully tested on AlmaLinux.
- **Provenance**: The script itself was drafted with Codex CLI.

### Requirements

- Bash on Linux (tested with Linux Mint as source and AlmaLinux as target).
- Optional: `rsync` for faster and permission-aware copies (falls back to `cp -a`).
- For HTTP server mode: Python 3 (or Python 2) is required.

### Usage

#### Interactive Menu (Recommended)

Run without arguments to show interactive menu:
```bash
./codex-auth-transfer.sh
```

#### Command Line

- **Export** (on the source host already signed in):
  ```bash
  ./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz
  ```

- **Import** (on the headless/remote host):
  ```bash
  ./codex-auth-transfer.sh import -f codex-auth-bundle.tar.gz --force
  ```

- **Start HTTP server to distribute bundle**:
  ```bash
  ./codex-auth-transfer.sh serve --port 8888 --bundle codex-auth-bundle.tar.gz
  ```

- **Help**:
  ```bash
  ./codex-auth-transfer.sh --help
  ```

#### HTTP Server Mode

1. Export credentials: `./codex-auth-transfer.sh export`
2. Start server: `./codex-auth-transfer.sh serve`
3. On remote server, import via curl:
   ```bash
   curl -sSL http://YOUR_IP:8888/import.sh | bash
   ```

   The import script automatically detects and constructs the server address, no need to manually enter IP.

#### Language Selection

The script automatically detects system language via `LANG` environment variable. You can also manually specify:

```bash
# Force English
CODEX_AUTH_TRANSFER_LANG=en ./codex-auth-transfer.sh

# Force Chinese
CODEX_AUTH_TRANSFER_LANG=zh ./codex-auth-transfer.sh
```

### Notes and Safety

- **Never commit or publish the exported bundle**. It contains your Codex credentials. Add it to `.gitignore` and store/transfer it securely.
- Some CLIs may bind tokens to a specific machine/hostname. If Codex refuses credentials after transfer, try device-code login or use a secure SSH tunnel to complete login.
- **Metadata in bundle**: By default, the manifest includes creation time and, unless disabled, `user` and `host` for traceability.
  - To omit user/host metadata, set `CODEX_AUTH_TRANSFER_NO_METADATA=1` when exporting, e.g.:
    ```bash
    CODEX_AUTH_TRANSFER_NO_METADATA=1 ./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz
    ```
- **Repository contents**: This repository intentionally includes only the script and this README. No exported bundle (e.g., `codex-auth-bundle.tar.gz`) is included.

---

## 中文

### 概述

- **目的**: 从可以浏览器登录的机器导出 Codex CLI 认证数据，并在无头/远程服务器上导入
- **原因**: Codex CLI 登录需要本地浏览器。此脚本允许您在一个主机上授权，然后安全地将凭据传输到另一个主机
- **范围**: 仅操作您本地用户主目录下的 Codex CLI 数据

### 功能

- **导出**: 收集 `~/.config/codex`、`~/.local/share/codex` 和 `~/.codex`（如果存在），使用限制性权限进行暂存，写入简单清单，并将所有内容打包到 tarball 中
- **导入**: 解压，可选择备份现有目标（使用 `--force` 时后缀为 `.bak-YYYYmmdd-HHMMSS`），将目录复制到 `$HOME`，并对文件夹强制执行 `700` 权限，文件 `600` 权限
- **检测**: 可用时，使用 `codex config path` 作为 Codex 存储数据位置的额外提示
- **安全性**: 导出的 bundle 以权限 `600` 创建。仅通过安全通道传输，如 `scp`、通过 SSH 的 `rsync` 等
- **自动修复配置**: 自动检测并修复 Codex 配置文件中的无效 `model_reasoning_effort` 值（例如 `xhigh` → `high`）
- **多语言支持**: 自动检测系统语言，显示英文或中文消息

### 背景

- **上下文**: Codex CLI 的登录流程需要本地浏览器，这阻碍了在无头或远程服务器上的直接安装
- **为什么存在此脚本**: 此脚本允许您从可以完成基于浏览器的登录的工作站导出 Codex CLI 认证，然后在无头服务器上导入
- **开发平台**: 导出在 Linux Mint 上创建；导入在 AlmaLinux 上成功测试
- **来源**: 脚本本身是在 Codex CLI 的帮助下起草的

### 要求

- Linux 上的 Bash（在 Linux Mint 作为源和 AlmaLinux 作为目标上测试）
- 可选: `rsync` 用于更快和权限感知的复制（回退到 `cp -a`）
- HTTP 服务器模式: 需要 Python 3（或 Python 2）

### 使用方法

#### 交互式菜单（推荐）

运行时不带参数以显示交互式菜单:
```bash
./codex-auth-transfer.sh
```

#### 命令行

- **导出**（在已登录的源主机上）:
  ```bash
  ./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz
  ```

- **导入**（在无头/远程主机上）:
  ```bash
  ./codex-auth-transfer.sh import -f codex-auth-bundle.tar.gz --force
  ```

- **启动 HTTP 服务器以分发 bundle**:
  ```bash
  ./codex-auth-transfer.sh serve --port 8888 --bundle codex-auth-bundle.tar.gz
  ```

- **帮助**:
  ```bash
  ./codex-auth-transfer.sh --help
  ```

#### HTTP 服务器模式

1. 导出凭据: `./codex-auth-transfer.sh export`
2. 启动服务器: `./codex-auth-transfer.sh serve`
3. 在远程服务器上，通过 curl 导入:
   ```bash
   curl -sSL http://你的IP:8888/import.sh | bash
   ```

   导入脚本会自动检测并拼接服务器地址，无需手动输入 IP。

#### 语言选择

脚本通过 `LANG` 环境变量自动检测系统语言。您也可以手动指定：

```bash
# 强制使用英文
CODEX_AUTH_TRANSFER_LANG=en ./codex-auth-transfer.sh

# 强制使用中文
CODEX_AUTH_TRANSFER_LANG=zh ./codex-auth-transfer.sh
```

### 注意事项和安全

- **永远不要提交或发布导出的 bundle**。它包含您的 Codex 凭据。将其添加到 `.gitignore` 并安全存储/传输
- 某些 CLI 可能将令牌绑定到特定机器/主机名。如果 Codex 在传输后拒绝凭据，请尝试设备代码登录或使用安全的 SSH 隧道完成登录
- **Bundle 中的元数据**: 默认情况下，清单包括创建时间，除非禁用，否则还包括 `user` 和 `host` 以便追踪
  - 要省略用户/主机元数据，在导出时设置 `CODEX_AUTH_TRANSFER_NO_METADATA=1`，例如:
    ```bash
    CODEX_AUTH_TRANSFER_NO_METADATA=1 ./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz
    ```
- **仓库内容**: 此仓库有意仅包含脚本和此 README。不包含任何导出的 bundle（例如 `codex-auth-bundle.tar.gz`）

---

## License Suggestion

- **Goal**: Allow anyone to use, modify, and share the script, but prohibit commercial use.
- **Note**: This restriction means it is not an OSI-approved "open source" license. If true open source is required, you must allow commercial use.
- **Recommended for non-commercial software**: PolyForm Noncommercial License 1.0.0.
  - **Summary**: Permits private/internal use, modification, and distribution; forbids commercial use.
  - **How to apply**: Add a `LICENSE` file with the PolyForm Noncommercial 1.0.0 text and reference it in this README.
- **Alternative** (less ideal for code): Creative Commons BY-NC 4.0. Better suited for content, not software.
