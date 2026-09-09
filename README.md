# Codex Desktop Switcher

用两个 macOS Shortcut，在已经人工验证过的 GPT 与 DeepSeek 配置快照之间安全切换。

## 当前状态

V1.1 已完成。两个私有 Profile、初始化脚本和 Shortcuts 已就绪，真实双向切换已由用户确认通过。正常切换完全静默，失败信息写入 stderr。

## 首次设置

所有 Profile 都保存在 `~/.codex/switcher/`，不会写入本项目。

1. 安装切换脚本：

   ```zsh
   ./setup.sh install
   ```

2. 让 Codex 进入已实际验证可用的 DeepSeek 状态，确认模型调用成功后保存：

   ```zsh
   ./setup.sh save-deepseek --confirmed-working
   ```

3. 使用已验证的官方恢复流程恢复 GPT，确认 GPT 实际调用成功后保存：

   ```zsh
   ./setup.sh save-gpt --confirmed-working
   ```

4. 检查安装状态：

   ```zsh
   ./setup.sh check
   ```

不要在未验证模型可用时执行 `save-deepseek` 或 `save-gpt`。脚本不会猜测或生成 Provider 配置。

## 日常切换

```zsh
"$HOME/.codex/switcher/bin/codex-switch.sh" gpt
"$HOME/.codex/switcher/bin/codex-switch.sh" deepseek
```

每次切换都会：

1. 在退出 Codex 前检查目标 Profile 是否完整。
2. 请求 Codex 正常退出；10 秒内未退出则停止。
3. 将当前 `config.toml` 备份到 `~/.codex/switcher/backups/`。
4. 原子安装目标配置；DeepSeek 的 models 快照会先于配置安装。
5. 保留最近 20 份配置备份。
6. 重新打开 Codex，并静默结束。

## 创建两个 Shortcut

在 macOS「快捷指令」中分别创建两个快捷指令，各添加“运行 Shell 脚本”动作：

- `Codex GPT`：`"$HOME/.codex/switcher/bin/codex-switch.sh" gpt`
- `Codex DeepSeek`：`"$HOME/.codex/switcher/bin/codex-switch.sh" deepseek`

不要添加“显示通知”“显示提醒”“显示结果”或“快速查看”，并保持“以管理员身份运行”关闭。

确认两个命令都通过真实切换测试后，再将快捷指令固定到 Dock 或桌面。

## 本地测试

```zsh
./tests/test-switcher.zsh
```

测试只使用临时目录，不会退出真实 Codex，也不会读写真实 Profile。
