# codex switcher

用两个 macOS Shortcut，在已经人工验证过的 Codex GPT 与 DeepSeek 配置快照之间一键切换。

## 🚀 最常用的 3 组命令

### 1. 新 Mac 首次安装：从 GitHub 下载 + 初始化 + DeepSeek 官方接入

先确保 **Codex / ChatGPT Desktop 已安装并至少启动过一次**，且当前 GPT 可以正常使用。

然后在 macOS Terminal 直接运行：

```zsh
/bin/zsh -c 'tmp="$(mktemp -t codex-switcher-bootstrap)"; curl -fsSL https://raw.githubusercontent.com/sunJack1991/codex-switcher/main/bootstrap.sh -o "$tmp" && /bin/zsh "$tmp"; rc=$?; rm -f "$tmp"; exit $rc'
```

该命令会：

1. 从 GitHub 下载仓库到所有 Mac 通用的固定目录：

   ```text
   $HOME/.codex/switcher
   ```

2. 初始化 codex-switcher。
3. 保存当前已确认可用的 GPT Profile。
4. 严格按 DeepSeek 官方文档当前给出的原始 `codex-deepseek-setup-en.sh` URL 下载并校验 **DeepSeek Codex setup**；不追加 query/header。脚本必须实际包含 Flash / Pro / Vision 三个模型才继续。若发现上次失败留下的 `backup-deepseek` 状态，会先安全恢复或隔离旧备份。
5. 提示选择 DeepSeek 模型（1=Flash、2=Pro、3=Vision）并输入 API Key。
6. 检查 `config.toml` / `models.json` 和本地 Profile。
7. 在安装、DeepSeek 接入、Profile 保存及最终初始化成功时分别输出 `✅` 提示。

> DeepSeek 官方 setup 仍然需要首次人工选择模型并输入 API Key。当前官方文档列出三个 Codex 模型：`deepseek-v4-flash`、`deepseek-v4-pro`、`deepseek-v4-flash-vision-exp`，并明确给出 `codex-deepseek-setup-en.sh` 作为 macOS/Linux 一键安装脚本。V1.3.6 与官方命令保持同一原始 URL；如果同一台机器直接运行官方命令能看到 3 个模型，而 bootstrap 校验仍失败，就说明需要继续比较两次 curl 的实际响应，不能再靠猜测修复。若检测到旧 `backup-deepseek` 与当前 GPT 状态冲突，旧备份不会被直接删除，而是改名保留为 `~/.codex/backup-deepseek.stale-时间戳`。

安装成功后，本机固定使用：

```text
$HOME/.codex/switcher/
```

因此快捷指令永远引用 `$HOME`，不要写 `/Users/某个用户名`。更换 Mac 后重新运行一次上面的初始化命令即可，快捷指令本身无需修改。

---

### 2. 一键卸载：删除 codex-switcher + 清理本项目 DeepSeek 接入

已安装时运行：

```zsh
/bin/zsh -c 'tmp="$(mktemp -t codex-switcher-uninstall)"; curl -fsSL https://raw.githubusercontent.com/sunJack1991/codex-switcher/main/uninstall.sh -o "$tmp" && /bin/zsh "$tmp"; rc=$?; rm -f "$tmp"; exit $rc'
```

> 这条命令会先下载 **GitHub main 上最新的卸载脚本** 再执行，因此即使本机是旧版本、`$HOME/.codex/switcher/uninstall.sh` 还不存在，也能卸载。若本机已更新，也可以直接运行 `/bin/zsh "$HOME/.codex/switcher/uninstall.sh"`。

卸载脚本会：

- 当前处于 DeepSeek 时，优先使用本项目保存的 GPT Profile 恢复 GPT 配置；
- 按 GPT 的 `models.json` 基线恢复：恢复 GPT 快照，或在 GPT 基线原本无 `models.json` 时清理 DeepSeek 文件；
- 旧版本没有 GPT models 基线时，只删除与本项目 DeepSeek 快照逐字节一致的 `models.json`，未知文件一律保留；
- 删除 `$HOME/.codex/switcher` 整个目录；
- 删除本项目 Profile 中保存的 DeepSeek API Key；
- 保留 `$HOME/.codex/auth.json`；
- 不删除 Codex / ChatGPT Desktop App；
- 完成后输出明确的 `✅ 卸载完成` 提示。

> 标准安装流程一定会先保存 GPT Profile，因此正常情况下卸载可以先恢复 GPT 再清理 DeepSeek。若 GPT Profile 缺失，卸载脚本不会盲目覆盖用户其他 Codex 配置。

卸载后如需重装，重新执行上面的“新 Mac 首次安装”命令即可。

---

### 3. macOS 快捷指令：两颗按钮一键切换

在 macOS「快捷指令」中分别创建两个 Shortcut，各添加一个 **运行 Shell 脚本** 动作。

**Codex GPT**

```zsh
/bin/zsh "$HOME/.codex/switcher/bin/codex-switcher.sh" gpt
```

**Codex DeepSeek**

```zsh
/bin/zsh "$HOME/.codex/switcher/bin/codex-switcher.sh" deepseek
```

建议：

- Shortcut 名称分别使用 `Codex GPT` 和 `Codex DeepSeek`；
- 不启用“以管理员身份运行”；
- 不添加“显示结果”“快速查看”等额外动作；
- 可固定到菜单栏、Dock、桌面或设置键盘快捷键；
- iCloud 同步 Shortcut 时，由于路径只使用 `$HOME`，不同 Mac 用户名不会导致脚本路径失效。

> 首次安装仍建议在 Terminal 中执行，因为 DeepSeek 官方 setup 需要交互式选择模型和输入 API Key；完成初始化后，日常 GPT / DeepSeek 切换才是真正的一键操作。

---

## 当前状态

V1.3.6 Hotfix 已合并到 main，待目标 Mac 实机 POC。初始化现在严格使用 DeepSeek 官方文档当前给出的原始 `codex-deepseek-setup-en.sh` URL，不加 query、不加缓存请求头、不猜其他脚本地址；下载后仅做三模型能力校验。同时保留 V1.3.5 对 zsh 只读变量 `status` 的修复，退出码统一使用 `rc`。

正常切换完全静默，失败信息写入 stderr。

## 核心路径

所有 Mac 统一：

```text
$HOME/.codex/switcher/
```

Shortcut 永远只引用 `$HOME`，不写具体用户名。

仓库本身即运行目录（Git working tree = runtime root）。关键脚本：

```text
$HOME/.codex/switcher/bin/codex-switcher.sh    # 日常切换
$HOME/.codex/switcher/bin/test-deepseek.sh     # 首次 DeepSeek API POC
$HOME/.codex/switcher/setup.sh                 # 本机幂等初始化
$HOME/.codex/switcher/install.sh               # Git 分发 / 更新
$HOME/.codex/switcher/bootstrap.sh             # 新 Mac 引导式一键初始化
$HOME/.codex/switcher/uninstall.sh             # 安全卸载 / 清理
```

## 首次设置

所有 Profile 保存在 `~/.codex/switcher/profiles/`，不会进入 Git。GPT 还会记录 `models.json` 基线：若 GPT 当时存在该文件则保存为 `models.gpt.json`；若不存在则保存 `models.gpt.absent` 标记。

如果仓库尚未 clone 到固定目录，先安装/更新：

```zsh
/bin/zsh install.sh --repo <YOUR_GIT_REPO_URL>
```

然后初始化本机：

```zsh
"$HOME/.codex/switcher/setup.sh" install
```

首次初始化 DeepSeek（当 `profiles/` 还没有 `deepseek.toml` 时）：

```zsh
"$HOME/.codex/switcher/setup.sh" init-deepseek
```

它会提示输入 DeepSeek API Key（不回显），先做一次 Responses API 验证，通过后才从当前 DeepSeek 态捕获 Profile。API Key 只存在本机 `profiles/deepseek.toml`，**不会进入 Git**。

首次配置 DeepSeek Profile 前，先做 API POC：

```zsh
"$HOME/.codex/switcher/bin/test-deepseek.sh"
```

默认测试 `deepseek-v4-flash`，可指定 Pro：

```zsh
"$HOME/.codex/switcher/bin/test-deepseek.sh" deepseek-v4-pro
```

API Key 通过 `read -s` 读取，不回显、不写日志、不进 Git。

## 日常切换

```zsh
"$HOME/.codex/switcher/bin/codex-switcher.sh" gpt
"$HOME/.codex/switcher/bin/codex-switcher.sh" deepseek
```

向后兼容别名：`openai|codex` -> gpt，`deep` -> deepseek。

每次切换都会：

1. 预检目标 Profile 与配置可写。
2. 获取并发锁，避免 Shortcut 连点竞态。
3. 完整退出 Codex.app（graceful -> TERM -> KILL -> 确认零残留）。
4. 备份当前 `config.toml` 到 `~/.codex/switcher/backups/`。
5. 原子安装目标配置；DeepSeek 使用自己的 models 快照；GPT 按已验证基线恢复 / 清理 models.json。旧安装没有 GPT models 基线时，仅清理与 DeepSeek 快照完全一致的文件。
6. 保留最近 20 份配置备份。
7. 重新打开 Codex，静默结束。

确认无 Codex.app 残留才修改配置；任何残留都会中止，不破坏现有配置。

## 创建两个 Shortcut

在 macOS「快捷指令」中分别创建两个，各添加“运行 Shell 脚本”动作：

- `Codex GPT`：`/bin/zsh "$HOME/.codex/switcher/bin/codex-switcher.sh" gpt`
- `Codex DeepSeek`：`/bin/zsh "$HOME/.codex/switcher/bin/codex-switcher.sh" deepseek`

不要添加“显示通知”“显示提醒”“显示结果”或“快速查看”，并保持“以管理员身份运行”关闭。

> 若之前用的是 `codex-switch.sh`，请更新 Shortcut 命令为 `codex-switcher.sh`，目标参数保持 `gpt` / `deepseek`。

## 本机私有数据

不进入 Git：

```text
profiles/
backups/
logs/
state
.switch.lock
```

尤其 `profiles/deepseek.toml` 可能含 API Key，必须 `chmod 600`。

## 本地测试

```zsh
./tests/test-switcher.zsh
./tests/test-setup.zsh
./tests/test-uninstall.zsh
```

测试只使用临时目录，不会退出真实 Codex，也不会读写真实 Profile。

## 更新

```zsh
"$HOME/.codex/switcher/install.sh"
```

`install.sh` 执行 `git pull --ff-only` 后再调用 `setup.sh install`，不覆盖本机 Profile。

## 验收

必须完成：`Codex -> DeepSeek -> Codex` 连续 20 轮；第二台用户名不同的 Mac `clone + setup`；Shortcut 不改路径。
