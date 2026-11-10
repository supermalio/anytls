#!/usr/bin/env bash
set -Eeuo pipefail

# Interactive installer wrapper for an XBoard AnyTLS node.
# Run this on the node server as root, not on the panel server.

readonly DEFAULT_PANEL_URL="https://45.66.218.141"
readonly INSTALLER_URL="https://raw.githubusercontent.com/cedar2025/xboard-node/dev/install.sh"

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

[[ "${EUID:-$(id -u)}" -eq 0 ]] || fail '请用 root 运行此脚本（例如：bash install-xboard-anytls-node.sh）'
[[ -d /run/systemd/system ]] || fail '此安装器要求 systemd；当前系统未检测到 systemd。'
command -v curl >/dev/null 2>&1 || fail '缺少 curl。请先通过系统包管理器安装 curl。'
command -v systemctl >/dev/null 2>&1 || fail '缺少 systemctl，无法安装 systemd 服务。'

printf '%s\n' 'XBoard AnyTLS 节点安装' \
  '请在“节点服务器”上运行，不要在面板服务器上运行。' \
  '先在 XBoard 后台创建 AnyTLS 节点，并准备好该节点的数字 ID 和节点密钥。' \
  ''

read -r -p "面板 API 地址 [${DEFAULT_PANEL_URL}]: " PANEL_URL
PANEL_URL="${PANEL_URL:-$DEFAULT_PANEL_URL}"
PANEL_URL="${PANEL_URL%/}"
[[ "$PANEL_URL" =~ ^https?://[^[:space:]]+$ ]] || fail '面板地址格式不正确，需以 http:// 或 https:// 开头。'

read -r -p 'AnyTLS 节点 ID: ' NODE_ID
[[ "$NODE_ID" =~ ^[1-9][0-9]*$ ]] || fail '节点 ID 必须是正整数。'

read -r -s -p '节点密钥（输入不会显示）: ' NODE_TOKEN
printf '\n'
[[ -n "$NODE_TOKEN" ]] || fail '节点密钥不能为空。'

printf '\n将安装 XBoard-Node，参数如下：\n  面板：%s\n  节点 ID：%s\n  协议运行内核：sing-box（用于 AnyTLS）\n' "$PANEL_URL" "$NODE_ID"
read -r -p '确认继续？[y/N] ' CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || fail '已取消，未进行安装。'

TMP_DIR="$(mktemp -d)"
cleanup() {
  unset NODE_TOKEN
  rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

printf '[INFO] 正在下载 XBoard-Node 官方安装器...\n'
curl --fail --silent --show-error --location \
  --proto '=https' --tlsv1.2 \
  "$INSTALLER_URL" \
  --output "$TMP_DIR/install.sh" || fail '下载官方安装器失败，请检查网络和 GitHub 连通性。'

bash -n "$TMP_DIR/install.sh" || fail '官方安装器语法检查未通过，已停止。'

printf '[INFO] 开始安装 AnyTLS 节点...\n'
bash "$TMP_DIR/install.sh" \
  --mode node \
  --kernel singbox \
  --panel "$PANEL_URL" \
  --token "$NODE_TOKEN" \
  --node-id "$NODE_ID"

printf '\n[OK] 安装器已完成。可用以下命令检查节点服务：\n'
printf '  systemctl status xboard-node --no-pager\n'
printf '  journalctl -u xboard-node -f\n'
