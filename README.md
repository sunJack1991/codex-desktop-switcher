# codex switcher

用两个 macOS Shortcut，在已经人工验证过的 Codex GPT 与 DeepSeek 官方配置快照之间一键切换。

## 1. 新 Mac 首次安装

前提：Codex / ChatGPT Desktop 已安装并至少启动过一次，当前 GPT 可以正常使用。

```zsh
/bin/zsh -c 'tmp="$(mktemp -t codex-switcher-bootstrap)"; curl -fsSL https://raw.githubusercontent.com/sunJack1991/codex-switcher/main/bootstrap.sh -o "$tmp" && /bin/zsh "$tmp"; rc=$?; rm -f "$tmp"; exit $rc'
```

流程：

1. 仓库安装到 `$HOME/.codex/switcher`。
2. 保存当前已确认可用的 GPT Profile。
3. 从 DeepSeek 官方 CDN 下载 `codex-deepseek-setup.sh`。
4. **原样执行官方脚本。** 模型菜单、API Key、`config.toml`、`models.json`、Restore 全部由 DeepSeek 官方处理。
5. 官方脚本结束后，Switcher 只检查 `config.toml` / `models.json` 是否存在且 Provider 为 DeepSeek。
6. 打开 Codex，由用户实际验证 DeepSeek 可用。
7. 验证成功后，原样保存 DeepSeek Profile。

如果官方脚本报错或官方菜单异常，初始化直接停止。请直接运行官方命令处理：

```zsh
bash <(curl -fsSL https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh)
```

Switcher 不做第三方修补。

---

## 2. 一键卸载

```zsh
/bin/zsh -c 'tmp="$(mktemp -t codex-switcher-uninstall)"; curl -fsSL https://raw.githubusercontent.com/sunJack1991/codex-switcher/main/uninstall.sh -o "$tmp" && /bin/zsh "$tmp"; rc=$?; rm -f "$tmp"; exit $rc'
```

卸载会优先恢复已保存的 GPT Profile，清理本项目 Profile / runtime 文件；保留 `~/.codex/auth.json`，不删除 Codex / ChatGPT Desktop App。

---

## 3. macOS 快捷指令

**Codex GPT**

```zsh
/bin/zsh "$HOME/.codex/switcher/bin/codex-switcher.sh" gpt
```

**Codex DeepSeek**

```zsh
/bin/zsh "$HOME/.codex/switcher/bin/codex-switcher.sh" deepseek
```

Shortcut 始终使用 `$HOME`，不同 Mac 用户名无需修改路径。

---

## 4. 更新 DeepSeek 模型（只走官方渠道）

当 DeepSeek 发布新模型、更新 Codex 模型目录，或者你希望重新选择当前 DeepSeek 模型时，不修改 codex-switcher 代码，直接重新运行 DeepSeek 官方 setup。

### 中文官方脚本

```zsh
bash <(curl -fsSL https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh)
```

### 英文官方脚本

```zsh
bash <(curl -fsSL https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh)
```

中文 / 英文脚本二选一即可，不需要连续执行两遍。模型列表、模型参数、API Key、`config.toml` 和 `models.json` 都以 DeepSeek 官方脚本实际生成结果为准。

官方更新完成后：

1. 打开 Codex，实际确认新的 DeepSeek 模型可以正常回复。
2. 确认可用后，刷新 codex-switcher 保存的 DeepSeek Profile：

```zsh
"$HOME/.codex/switcher/setup.sh" save-deepseek --confirmed-working
```

`save-deepseek` 会先备份旧的 `deepseek.toml` / `models.deepseek.json`，再把当前 DeepSeek 官方生成的 `config.toml` / `models.json` 原样保存为新的 Profile。

这样之后再点击 `Codex DeepSeek` Shortcut，使用的就是最新一次**官方安装 + 人工验证**后的 DeepSeek 模型配置，而不会切回旧模型目录。

如果更新完成后希望继续使用 GPT，直接点击 `Codex GPT` Shortcut 即可。

---

## 日常切换逻辑

每次切换：

1. 预检目标 Profile。
2. 获取并发锁。
3. 完整退出 Codex。
4. 备份当前 `config.toml`。
5. 原子安装目标 Profile；DeepSeek 使用**已经由官方安装并人工验证过**的 `models.deepseek.json` 快照。
6. GPT 按已保存基线恢复 `models.json`。
7. 重新打开 Codex。

正常切换静默，失败输出 stderr。

---

## 本机私有数据

```text
$HOME/.codex/switcher/
├── profiles/
│   ├── gpt.toml
│   ├── models.gpt.json / models.gpt.absent
│   ├── deepseek.toml
│   └── models.deepseek.json
├── backups/
└── state
```

`profiles/`、`backups/`、API Key 不进入 Git。

---

## 本地测试

```zsh
./tests/test-switcher.zsh
./tests/test-setup.zsh
./tests/test-uninstall.zsh
./tests/test-bootstrap.zsh
```

## 当前状态

版本：**V1.3.8 Hotfix**  
状态：代码已合并 / 待目标 Mac 实机 POC。

V1.3.8 的核心变化：撤销 V1.3.7 的本地 Vision 派生和 CDN 版本匹配，恢复到严格的 **DeepSeek official-only installation boundary**。README 已补充中文 / 英文官方模型更新流程；更新后通过 `save-deepseek --confirmed-working` 刷新已验证 Profile。
