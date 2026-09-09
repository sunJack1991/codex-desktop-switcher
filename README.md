# Codex Desktop Switcher

用两个 macOS Shortcut，在已经人工验证过的 Codex/OpenAI 与 DeepSeek 配置快照之间一键切换。

## 当前状态

V1.3 代码已就位，待目标 Mac 实机 POC。核心切换逻辑已完成：完整退出 Codex.app、并发锁、原子替换、配置备份轮转、静默成功 / 失败写 stderr。

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
```

## 首次设置

所有 Profile 保存在 `~/.codex/switcher/profiles/`，不会进入 Git。

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
5. 原子安装目标配置；DeepSeek 的 models 快照先于 config 落盘。
6. 保留最近 20 份配置备份。
7. 重新打开 Codex，静默结束。

确认无 Codex.app 残留才修改配置；任何残留都会中止，不破坏现有配置。

## 创建两个 Shortcut

在 macOS「快捷指令」中分别创建两个，各添加“运行 Shell 脚本”动作：

- `Codex GPT`：`"/bin/zsh $HOME/.codex/switcher/bin/codex-switcher.sh" gpt`
- `Codex DeepSeek`：`"/bin/zsh $HOME/.codex/switcher/bin/codex-switcher.sh" deepseek`

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
```

测试只使用临时目录，不会退出真实 Codex，也不会读写真实 Profile。

## 更新

```zsh
"$HOME/.codex/switcher/install.sh"
```

`install.sh` 执行 `git pull --ff-only` 后再调用 `setup.sh install`，不覆盖本机 Profile。

## 验收

必须完成：`Codex -> DeepSeek -> Codex` 连续 20 轮；第二台用户名不同的 Mac `clone + setup`；Shortcut 不改路径。
