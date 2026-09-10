# codex-switcher-Technical-Architecture-V1.3

版本：V1.3.6 Hotfix（基于 V1.3）  
最后更新时间：2026-09-10  
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
- 两个 Shortcut 与真实双向切换已由用户确认通过（V1.1 确认项）。

以上为 V1.1 阶段的确认结果；V1.3 变更（完整退出升级为 P0、并发锁、models 先行落盘）后的真实 20 次双向切换与第二台 Mac clone+setup 仍属待实机 POC。

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
codex-switcher/
│
├── bin/
│   ├── codex-switcher.sh
│   └── test-deepseek.sh
├── install.sh
├── setup.sh
├── README.md
├── AGENTS.md
├── codex-switcher-PRD-V1.3.md
├── codex-switcher-Technical-Architecture-V1.3.md
├── Project_Memory.md
├── Change_Log.md
├── .gitignore
├── 人工测试操作流程.md
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
│   ├── models.gpt.json        # GPT 有 models.json 时
│   ├── models.gpt.absent      # GPT 无 models.json 时（二选一）
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

# 若 GPT 当前存在 models.json：保存 models.gpt.json
# 若不存在：保存 models.gpt.absent 标记

chmod 600 "$HOME/.codex/switcher/profiles/gpt.toml"
```

原则：

> Profile 必须来自真实可用状态，不手工拼完整配置。

---

## 7.3 DeepSeek 官方 setup 来源与能力校验

V1.3.6 的原则是与 DeepSeek 官方当前 Codex 安装命令完全同源。

唯一下载 URL：

```text
https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh
```

流程：

```text
官方原始 URL
↓
curl -fsSL（不加 query/header）
↓
保存到临时文件
↓
grep deepseek-v4-flash-vision-exp
├─ 有 → 执行同一文件
└─ 无 → 安全停止，并提示直接运行官方命令做 A/B 对照
```

当前最低能力断言：

> 被执行的官方 setup 必须包含 `deepseek-v4-flash-vision-exp`，因为 DeepSeek 当前官方 Codex 文档明确列出 1=Flash、2=Pro、3=Vision、9=Restore。

原则：

- 不追加 cache-buster query。
- 不添加自定义缓存请求头。
- 不猜测或尝试未由当前官方文档明确给出的备用 shell endpoint。
- 不在 Switcher 中复制、patch 或重写 DeepSeek 官方模型菜单。
- 不自行生成 Vision 模型配置。
- 如果同一机器上的官方命令和 bootstrap 结果不一致，后续诊断必须比较实际响应/哈希，而不是继续猜 CDN 行为。

## 7.4 DeepSeek 官方状态预检

DeepSeek 官方 setup 自身维护：

```text
~/.codex/backup-deepseek/
```

V1.3.3 在首次/重入初始化时增加最小状态修复：

1. 没有 `backup-deepseek`：直接执行官方 setup。
2. 当前为完整 DeepSeek（config 为 DeepSeek 且 models.json 存在）：交给官方 setup 自己处理。
3. 当前为 DeepSeek 但 models.json 缺失：调用同一份官方 setup 的 Restore 选项 9，成功恢复后再继续。
4. 当前不是 DeepSeek但仍残留 `backup-deepseek`：将目录改名为 `backup-deepseek.stale-时间戳` 保留，不覆盖当前 GPT；随后官方 setup 创建新的备份。

禁止：

- 直接删除未知官方备份。
- 手工伪造 DeepSeek 官方 manifest/backup 状态。
- 为绕过保护逻辑而强制覆盖当前配置。

临时官方 setup 脚本使用全局受控临时路径，并由幂等 cleanup 处理 EXIT/HUP/INT/TERM，避免 `set -u` 下局部变量离开作用域后触发二次异常。

---

# 8. 核心脚本接口

```text
codex-switcher.sh gpt
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

> V1 代码实际只实现 `gpt` / `deepseek`（兼容别名 `openai|codex` -> gpt、`deep` -> deepseek）。`status` / `restore` 未实现，延后考虑。

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
codex-switcher.sh gpt
↓
检查 gpt.toml
↓
读取 GPT models 基线
↓
正常退出 Codex
↓
备份当前 config.toml
↓
复制 gpt.toml
↓
恢复 models.gpt.json，或按 models.gpt.absent 删除 DeepSeek models.json
↓
写 state=gpt
↓
启动 Codex
↓
静默结束
```

V1.3.2 规则：

- 新安装必须把 GPT 的 `models.json` **存在/不存在** 都记录为已验证基线。
- 若存在 `models.gpt.json`，切回 GPT 时恢复该快照。
- 若存在 `models.gpt.absent`，切回 GPT 时删除当前 `models.json`。
- 旧安装没有上述基线时，不猜 GPT 默认配置；仅当当前 `models.json` 与 `models.deepseek.json` 逐字节一致时才删除。
- 无法确认归属的 `models.json` 一律保留。

这样同时满足：

> GPT 恢复完整性 > 不误删未知用户文件。

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

完整退出序列（V1.3 P0，与代码一致）：

1. Stage A — graceful：`osascript` 触发 `quit`，等待最多 5 秒。
2. Stage B — TERM：`pkill -TERM`，再等待最多 5 秒。
3. Stage C — KILL（兜底）：`pkill -KILL` 后等待 1 秒。

如果执行完 Stage C 后仍有残留：

> 中止切换。

并且本次切换停止、不修改任何配置。

> `KILL` 只在 graceful 与 TERM 均失败后作为最后手段使用；正常退出优先，避免破坏 Codex 正在写入的本地状态。

启动：

```bash
open -a Codex
```

当前限制：

> `codex://space` 在当前 Codex Desktop 中不是可消费的外部导航路由，只会唤起应用；`codex://threads/new` 属于未公开的内部深链，只能 best-effort 新建 Codex 任务，不能保证打开工作区首页。

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
- GPT models 快照 / absent 基线捕获与恢复。
- 旧安装 DeepSeek models 安全清理。
- 安全卸载保留未知 models.json 与 auth.json。
- bootstrap 严格使用 DeepSeek 官方文档当前给出的 `codex-deepseek-setup-en.sh`，不允许旧两模型脚本继续执行。
- README zsh wrapper 使用 `rc` 保存退出码，避免只读 `status` 变量。
- bootstrap 对 DeepSeek 官方 stale backup 状态进行 Restore/归档，不直接删除。
- bootstrap 失败退出时临时脚本 cleanup 不产生二次 `parameter not set`。
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

> V1.1 已 PASS（用户确认 Profile、Shortcuts 与真实切换均已完成）。V1.3 变更后的真实 20 次双向切换与第二台 Mac clone+setup：未验证（待实机 POC）。

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
2. codex-switcher-PRD-V1.3.md
↓
3. codex-switcher-Technical-Architecture-V1.3.md
↓
4. Project_Memory.md
↓
5. Change_Log.md
↓
6. 实际代码
```

最终原则：

> 这个项目不是“多模型平台”，只是一个可靠的本地模型切换器。
