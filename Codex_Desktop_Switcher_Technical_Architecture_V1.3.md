# Codex_Desktop_Switcher_Technical_Architecture_V1.3

版本：V1.3 增量（含 V1.1）  
最后更新时间：2026-09-09  
状态：代码已落 / 待实机 POC；此前 V1.1 Completed

---

# 1. 技术目标

## 1.1 产品目标

> 在 Mac 上将 Codex GPT / DeepSeek 的切换变成两个桌面按钮。

## 1.2 技术目标

1. 实现尽可能简单。
2. 不增加后台服务。
3. 不增加数据库。
4. 不依赖 Python / Node / Swift Runtime。
5. 配置切换失败时可恢复。
6. Secret 不进入 Git。
7. 不破坏 Codex.app。

优先级：

> 可恢复 > 自动化

> 简单 > 通用

> 已验证配置 > 动态生成配置

> MVP > 完整配置管理器

---

# 2. 已验证基础

当前已经人工验证：

- DeepSeek API 可以接入 Mac Codex Desktop。
- `deepseek-v4-flash` 可以在 Codex Desktop 中正常使用。
- 官方 Restore 完成后 GPT 配置可正常使用。
- GPT / DeepSeek 两个 Profile 已固化。
- 两个 Shortcut 与真实双向切换已由用户确认通过。

因此：

> DeepSeek 接入原理已经通过 POC，不需要重新设计 Provider 协议。

---

# 3. 最终架构

```text
┌──────────────────────────────┐
│          macOS Dock          │
│                              │
│  🧠 Codex GPT   ⚡ DeepSeek  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│      macOS Shortcuts         │
│  仅负责调用 shell command    │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│      codex-switcher.sh         │
│                              │
│  1. preflight                │
│  2. quit Codex               │
│  3. backup config            │
│  4. copy profile             │
│  5. copy models if needed    │
│  6. launch Codex             │
│  7. silent finish            │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│       ~/.codex/              │
│  config.toml                 │
│  models.json                 │
│  switcher/                   │
└──────────────┬───────────────┘
               │
               ▼
          Codex.app
               │
        ┌──────┴──────┐
        ▼             ▼
       GPT         DeepSeek
```

---

# 4. 技术栈

| 模块 | 技术 | 原因 |
|---|---|---|
| 核心脚本 | zsh | macOS 原生，零额外依赖 |
| 桌面入口 | Shortcuts | 不开发 GUI |
| 退出 Codex | AppleScript | macOS 原生 |
| 启动 Codex | `open -a Codex` | macOS 原生 |
| 文件切换 | `cp` | 两个已验证快照，无需解析 |
| 备份 | `cp` + timestamp | 简单可恢复 |
| 状态 | text file | 不需要 JSON/数据库 |
| 错误输出 | stderr | 成功静默，失败可诊断 |

---

# 5. 为什么不使用 Python

之前考虑：

> Python + TOML parser + 字段级 patch。

当前取消。

原因：

1. 用户要求越简单越好。
2. 已经有两个真实可用状态。
3. 当前不是做通用 Codex 配置管理器。
4. Profile 快照方案已经能解决核心问题。
5. Python 会引入版本、依赖、TOML writer 等额外问题。

代价：

> Profile 之间不会自动同步用户后来新增的 Codex 设置。

处理：

> V1 提供 Profile 刷新方法，而不是做智能 merge。

---

# 6. 文件结构

项目仓库：

```text
codex-desktop-switcher/
│
├── codex-switcher.sh
├── setup.sh
├── README.md
├── AGENTS.md
├── Codex_Desktop_Switcher_PRD_V1.3.md
├── Codex_Desktop_Switcher_Technical_Architecture_V1.3.md
├── Project_Memory.md
├── Change_Log.md
└── tests/
    ├── test-switcher.zsh
    └── test-setup.zsh
```

用户本机私有目录：

```text
~/.codex/switcher/
│
├── profiles/
│   ├── gpt.toml
│   ├── deepseek.toml
│   └── models.deepseek.json
│
├── backups/
│   └── config_YYYYMMDD_HHMMSS.toml
│
├── bin/
│   └── codex-switcher.sh
│
└── state
```

注意：

> `profiles/` 不在 Git 仓库内。

---

# 7. 第一次初始化

## 7.1 DeepSeek Profile

前提：

> Codex 当前已确认处于 DeepSeek 且实际可用。

保存：

```bash
mkdir -p "$HOME/.codex/switcher/profiles"
cp "$HOME/.codex/config.toml"    "$HOME/.codex/switcher/profiles/deepseek.toml"

cp "$HOME/.codex/models.json"    "$HOME/.codex/switcher/profiles/models.deepseek.json"
```

权限：

```bash
chmod 700 "$HOME/.codex/switcher"
chmod 700 "$HOME/.codex/switcher/profiles"
chmod 600 "$HOME/.codex/switcher/profiles/deepseek.toml"
```

## 7.2 GPT Profile

前提：

> 官方 Restore 已完成，并实际确认 Codex GPT 可正常使用。

保存：

```bash
cp "$HOME/.codex/config.toml"    "$HOME/.codex/switcher/profiles/gpt.toml"

chmod 600 "$HOME/.codex/switcher/profiles/gpt.toml"
```

原则：

> Profile 必须来自真实可用状态，不手工拼完整配置。

---

# 8. 核心脚本接口

```text
codex-switcher.sh codex
codex-switcher.sh deepseek
```

可选：

```text
codex-switcher.sh status
codex-switcher.sh restore
```

V1 必须：

- `gpt`
- `deepseek`

`status` / `restore` 如果不增加明显复杂度可以保留，否则延后。

---

# 9. DeepSeek 切换流程

```text
用户点击 DeepSeek Shortcut
↓
codex-switcher.sh deepseek
↓
检查 deepseek.toml
↓
检查 models.deepseek.json
↓
正常退出 Codex
↓
备份当前 config.toml
↓
复制 deepseek.toml
↓
复制 models.deepseek.json → ~/.codex/models.json
↓
写 state=deepseek
↓
启动 Codex
↓
静默结束
```

伪代码：

```bash
set -euo pipefail

PROFILE="$HOME/.codex/switcher/profiles/deepseek.toml"
MODELS="$HOME/.codex/switcher/profiles/models.deepseek.json"

# preflight
test -f "$PROFILE"
test -f "$MODELS"

# quit Codex
osascript -e 'tell application "Codex" to quit'

# wait
# if still running after timeout -> exit

# backup
cp "$HOME/.codex/config.toml"    "$HOME/.codex/switcher/backups/config_TIMESTAMP.toml"

# switch
cp "$PROFILE" "$HOME/.codex/config.toml"
cp "$MODELS" "$HOME/.codex/models.json"

# state
echo "deepseek" > "$HOME/.codex/switcher/state"

# open
open -a Codex
```

---

# 10. GPT 切换流程

```text
用户点击 GPT Shortcut
↓
codex-switcher.sh codex
↓
检查 gpt.toml
↓
正常退出 Codex
↓
备份当前 config.toml
↓
复制 gpt.toml
↓
写 state=gpt
↓
启动 Codex
↓
静默结束
```

重要：

> V1 不删除 `~/.codex/models.json`。

原因：

- GPT Profile 如果不引用它，它不会参与模型配置。
- 删除用户文件的风险高于保留一个未使用文件。
- 避免误删未来由其它功能生成的 `models.json`。

---

# 11. 备份策略

每次切换前：

```text
~/.codex/config.toml
↓
~/.codex/switcher/backups/config_YYYYMMDD_HHMMSS.toml
```

保留：

> 最近 20 个备份。

超过：

> 删除最旧备份。

V1 不备份：

- session history
- Codex 数据库
- 项目源码

原因：

> Switcher 只修改 `config.toml` 与 DeepSeek 使用的模型 catalog。

---

# 12. Process Control

退出：

```bash
osascript -e 'tell application "Codex" to quit'
```

等待：

> 最长 5～10 秒。

如果 Codex 仍未退出：

> 中止切换。

V1 默认禁止：

```bash
kill -9
```

原因：

> 避免破坏 Codex 正在写入的本地状态。

启动：

```bash
open -a Codex
```

---

# 13. Shortcuts

Shortcut 1：

名称：

> Codex GPT

执行：

```bash
"$HOME/.codex/switcher/bin/codex-switcher.sh" gpt
```

Shortcut 2：

名称：

> Codex DeepSeek

执行：

```bash
"$HOME/.codex/switcher/bin/codex-switcher.sh" deepseek
```

两个 Shortcut 只保留 Shell 调用，不增加通知、提醒、显示结果、快速查看或管理员权限。

两个 Shortcut 可：

- 放桌面
- 放 Dock
- 使用 Spotlight
- 分配键盘快捷键

---

# 14. Secret 管理

DeepSeek API Key 当前存在：

```text
deepseek.toml
```

因此：

```bash
chmod 600 deepseek.toml
```

Switcher 根目录：

```bash
chmod 700 ~/.codex/switcher
```

禁止：

- 项目仓库保存真实 Profile。
- README 保存 API Key。
- Change Log 保存 API Key。
- shell log 输出配置全文。
- 终端 `echo` API Key。

V1 暂不做 Keychain。

---

# 15. 配置变更问题

快照方案的唯一主要技术债：

> 用户后来修改 Codex 配置时，两个 Profile 可能出现差异。

例如：

- 新增 MCP
- 新增 project trust
- 改权限
- 改通知
- 改其它 Codex 设置

V1 解决方法：

> 提供手工刷新 Profile 的明确流程。

不做：

> 自动 TOML merge。

升级自动 merge 的触发条件：

> Profile 失同步真实发生至少 2～3 次，并已经影响日常使用。

---

# 16. 错误处理

| 场景 | 行为 |
|---|---|
| Profile 不存在 | 停止，不退出 Codex |
| models snapshot 不存在 | DeepSeek 切换停止 |
| config.toml 不存在 | 停止 |
| 私有目录或目标文件是符号链接/错误类型 | 停止，不退出 Codex |
| 无法可靠读取 Codex 进程状态 | 停止，不切换 |
| 备份失败 | 停止 |
| Codex 无法退出 | 停止 |
| 暂存或替换失败 | 保留时间戳备份，不启动 Codex |
| `open -a Codex` 返回失败 | 配置保留为目标 Profile，通过 stderr 报错 |

原则：

> 配置失败比“没有自动启动 Codex”严重得多。

---

# 17. 性能

目标：

| 指标 | 目标 |
|---|---:|
| Switcher 自身操作 | < 2 秒 |
| Codex 退出等待 | < 10 秒 |
| 配置切换 | < 1 秒 |
| 切换成功率 | ≥ 99% |
| 配置损坏 | 0 |

---

# 18. POC

## POC 1：DeepSeek API

状态：

> PASS

## POC 2：DeepSeek V4 Flash

状态：

> PASS

## POC 3：GPT Restore

状态：

> PASS（用户确认）

## POC 4：Profile Switcher

自动化状态：

> PASS（临时目录测试，不操作真实 Codex）

已覆盖：

- GPT → DeepSeek。
- DeepSeek → GPT。
- 连续 20 次交替切换。
- 最近 20 份备份轮转。
- 缺少 models 快照时不修改配置。
- 提交 config 前中断时保留原配置。
- Profile 捕获与 700 / 600 权限。

真实端到端目标仍为：

> 连续 20 次：

```text
GPT
↓
DeepSeek
↓
GPT
```

验收：

- 两端均可正常发起 Codex 任务。
- 配置无损坏。
- API Key 无泄漏。
- 不需要 Terminal。

真实端到端状态：

> PASS（用户确认 Profile、Shortcuts 与真实切换均已完成）

---

# 19. 版本演进

## V1

```text
zsh
+
Shortcuts
+
2 Profiles
```

当前推荐。

## V1.1

已完成：

- 删除正常切换通知与成功输出。
- 删除启动确认检测。
- Shortcuts 只保留 Shell 调用。
- 保留 stderr 错误、备份、原子替换、状态文件和自动重启。

后续触发后再做：

- DeepSeek Pro Profile。
- status。
- refresh-profile。

## V2

只有真实高频需求才做：

```text
Swift Menu Bar App
```

## V3

暂不规划：

> 自动 Router。

---

# 20. 技术决策总结

## 最优体验方案

Swift 菜单栏 App：

边际收益：

- 更漂亮。
- 当前 Provider 更直观。
- 可做 Keychain。

边际成本：

- 明显增加代码、签名、维护和 UI 工作。

当前：

> 不值得。

## 最低成本 MVP

zsh + Shortcuts：

边际收益：

- 已解决核心问题。
- 几乎零依赖。
- 代码量低。
- 排错简单。

边际成本：

- Profile 不自动同步。

当前选择：

> 最低成本 MVP。

---

# 21. 文档维护

产品变化：

> PRD。

架构变化：

> Technical Architecture。

重大取舍：

> Project Memory。

具体实现变化：

> Change Log。

Agent 行为：

> AGENTS.md。

---

# 22. 给 Codex 的阅读顺序

```text
1. AGENTS.md
↓
2. Codex_Desktop_Switcher_PRD_V1.3.md
↓
3. Codex_Desktop_Switcher_Technical_Architecture_V1.3.md
↓
4. Project_Memory.md
↓
5. Change_Log.md
↓
6. 实际代码
```

最终原则：

> 这个项目不是“多模型平台”，只是一个可靠的本地模型切换器。
