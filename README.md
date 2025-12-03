# Codex 凭据传输工具

## 概述

- **目的**: 从可以浏览器登录的机器导出 Codex CLI 认证数据，并在无头/远程服务器上导入
- **原因**: Codex CLI 登录需要本地浏览器。此脚本允许您在一个主机上授权，然后安全地将凭据传输到另一个主机
- **范围**: 仅操作您本地用户主目录下的 Codex CLI 数据

## 功能

- **导出**: 收集 `~/.config/codex`、`~/.local/share/codex` 和 `~/.codex`（如果存在），使用限制性权限进行暂存，写入简单清单，并将所有内容打包到 tarball 中
- **导入**: 解压，可选择备份现有目标（使用 `--force` 时后缀为 `.bak-YYYYmmdd-HHMMSS`），将目录复制到 `$HOME`，并对文件夹强制执行 `700` 权限，文件 `600` 权限
- **检测**: 可用时，使用 `codex config path` 作为 Codex 存储数据位置的额外提示
- **安全性**: 导出的 bundle 以权限 `600` 创建。仅通过安全通道传输，如 `scp`、通过 SSH 的 `rsync` 等

## 背景

- **上下文**: Codex CLI 的登录流程需要本地浏览器，这阻碍了在无头或远程服务器上的直接安装
- **为什么存在此脚本**: 我创建此脚本是为了从可以完成基于浏览器的登录的工作站导出 Codex CLI 认证，然后在无头服务器上导入
- **开发平台**: 导出在 Linux Mint 上创建；导入在 AlmaLinux 上成功测试
- **来源**: 脚本本身是在 Codex CLI 的帮助下起草的

## 要求

- Linux 上的 Bash（在 Linux Mint 作为源和 AlmaLinux 作为目标上测试）
- 可选: `rsync` 用于更快和权限感知的复制（回退到 `cp -a`）
- HTTP 服务器模式: 需要 Python 3（或 Python 2）

## 使用方法

### 交互式菜单（推荐）

运行时不带参数以显示交互式菜单:
```bash
./codex-auth-transfer.sh
```

### 命令行

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

### HTTP 服务器模式

1. 导出凭据: `./codex-auth-transfer.sh export`
2. 启动服务器: `./codex-auth-transfer.sh serve`
3. 在远程服务器上，通过 curl 导入:
   ```bash
   curl -sSL http://你的IP:8888/import.sh | bash
   ```

   导入脚本会自动检测并拼接服务器地址，无需手动输入 IP。

## 注意事项和安全

- **永远不要提交或发布导出的 bundle**。它包含您的 Codex 凭据。将其添加到 `.gitignore` 并安全存储/传输
- 某些 CLI 可能将令牌绑定到特定机器/主机名。如果 Codex 在传输后拒绝凭据，请尝试设备代码登录或使用安全的 SSH 隧道完成登录
- **Bundle 中的元数据**: 默认情况下，清单包括创建时间，除非禁用，否则还包括 `user` 和 `host` 以便追踪
  - 要省略用户/主机元数据，在导出时设置 `CODEX_AUTH_TRANSFER_NO_METADATA=1`，例如:
    ```bash
    CODEX_AUTH_TRANSFER_NO_METADATA=1 ./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz
    ```
- **仓库内容**: 此仓库有意仅包含脚本和此 README。不包含任何导出的 bundle（例如 `codex-auth-bundle.tar.gz`）

## 许可证建议

- **目标**: 允许任何人使用、修改和分享脚本，但禁止商业使用
- **注意**: 此限制意味着它不是 OSI 批准的"开源"许可证。如果需要真正的开源，必须允许商业使用
- **非商业软件推荐**: PolyForm Noncommercial License 1.0.0
  - **摘要**: 允许私人/内部使用、修改和分发；禁止商业使用
  - **如何应用**: 添加包含 PolyForm Noncommercial 1.0.0 文本的 `LICENSE` 文件，并在此 README 中引用
- **替代方案**（对代码不太理想）: Creative Commons BY-NC 4.0。更适合内容，而不是软件
