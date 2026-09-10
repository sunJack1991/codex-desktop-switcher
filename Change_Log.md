# Change Log

项目：codex switcher

---

# Version History

# V1.3.3 — Bootstrap Stale DeepSeek State Recovery

日期：2026-09-10  
状态：已合并 main，待目标 Mac 实机验证

- 修复一键初始化在 `~/.codex/backup-deepseek` 已存在、但 `~/.codex/models.json` 缺失时，DeepSeek 官方 setup 拒绝继续的问题。
- 当前仍是 DeepSeek 且 models 缺失时，bootstrap 会调用 DeepSeek 官方 Restore（选项 9）先恢复，再继续初始化。
- 当前已是 GPT、但残留旧 `backup-deepseek` 时，不覆盖当前 GPT 配置；将旧备份改名保存为 `backup-deepseek.stale-时间戳`，随后让官方 setup 基于当前 GPT 状态创建新备份。
- 修复 `temp_script` 使用函数局部变量配合 EXIT trap，在失败退出时触发 `parameter not set` 的二次错误；改为全局受控临时路径 + 幂等 cleanup。
- `bootstrap.sh` 同时将 `uninstall.sh` 纳入 chmod 初始化，确保本地脚本可直接执行。
- 不删除历史 DeepSeek 官方备份，不自动猜测 GPT 配置。

## 待实机 POC

- 在本次截图所示的“backup-deepseek 已存在 + models.json 缺失”机器上重新执行 README 顶部一键初始化。
- 验证不再出现 `Missing ~/.codex/models.json` 中止。
- 验证失败路径不再出现 `temp_script: parameter not set`。
- 完成 DeepSeek 实际调用后再保存 Profile。

---


# V1.3.2 — GPT Models Restore / Stale Uninstall Hotfix

日期：2026-09-10  
状态：已合并 main，待目标 Mac 实机验证

- 修复旧版 DeepSeek → GPT 只恢复 `config.toml`、可能残留 DeepSeek `models.json` 的问题。
- `setup.sh save-gpt` 新增 GPT models 基线：`models.gpt.json` / `models.gpt.absent` 二选一。
- `codex-switcher.sh gpt` 按已验证基线恢复；旧安装无基线时，仅清理与 `models.deepseek.json` 完全一致的文件，不猜、不删未知 models。
- `uninstall.sh` 改为只恢复/清理可确认归属的配置；当前已是 GPT 时不覆盖现有 GPT config；未知 `models.json` 保留；`auth.json` 永不触碰。
- README 一键卸载改为先下载 GitHub main 最新 `uninstall.sh`，兼容本机旧版本根本没有卸载脚本的情况。
- 新增 `tests/test-uninstall.zsh`；扩充 switcher/setup 测试覆盖 GPT models absent、GPT models snapshot 与 legacy 清理。
- 修正 README 核心路径中误写成字面量 `\\n` 的显示问题。

## 待实机 POC

- 在出现过 `/bin/zsh: can't open input file: .../uninstall.sh` 的旧 Mac 上直接执行 README 新的一键卸载命令。
- 更新后验证 DeepSeek → GPT，确认 `models.json` 按 GPT 基线恢复或删除。
- 运行 `./tests/test-switcher.zsh`、`./tests/test-setup.zsh`、`./tests/test-uninstall.zsh`。

---

# V1.3.1 — Quick Bootstrap / Safe Uninstall / Shortcut Docs

日期：2026-09-10  
状态：已实现，待目标 Mac 实机验证

- 新增 `bootstrap.sh`：从 GitHub 固定安装到 `$HOME/.codex/switcher`，初始化 Switcher，保存 GPT Profile，调用 DeepSeek 官方 Codex setup，并在关键步骤输出成功/失败提示。
- 新增 `uninstall.sh`：优先恢复 GPT Profile，清理本项目 Switcher、DeepSeek models 快照与本地 DeepSeek Profile；明确保留 `auth.json` 和 Codex / ChatGPT Desktop App。
- README 顶部新增三组可直接复制的命令：首次安装、一键卸载、macOS Shortcut。
- 所有 Shortcut 统一引用 `$HOME/.codex/switcher`，不再依赖具体 Mac 用户名。
- 修正 README 中原有 Shortcut Shell 示例的引号写法。
- 首次 DeepSeek 接入仍保留官方 setup 的交互式模型选择与 API Key 输入；日常切换保持一键静默。

## 待实机 POC

- 全新 Mac / 新用户目录执行 README 顶部 bootstrap 命令；
- DeepSeek 官方 setup 完成后，验证 Codex 实际回复与 Profile 捕获；
- 执行 `uninstall.sh` 后确认 GPT 恢复、Switcher 与 DeepSeek 本地文件清理；
- iCloud 同步 Shortcut 到不同用户名 Mac，确认无需修改路径。

---


# V1.3 — 回退确认 + V1.3 测试重跑

日期：2026-09-10  
状态：V1.3 Stable 确认为当前版本

- 产品负责人决定终止 V1.5「多 Runtime 物理会话隔离」方向，本机不合并 V1.5 POC，确认 **V1.3 Stable** 为当前版本。
- 已回退 V1.5 POC 临时内容（移除 `poc/` 与相关文档条目），工作区回到 V1.3 基线。
- 命名/软件名一致性检查：全仓统一 `codex-switcher`（无残留旧名 `codex-switch` 的实际使用），软件名统一为「codex switcher」。
- 已严格重跑 V1.3 自动化测试：`tests/test-switcher.zsh`（静默成功、可见错误、双向、20 次连续切换、备份轮转、预检保护、中断安全、auth.json 不变式）与 `tests/test-setup.zsh`（安装、Profile 捕获、权限、人工确认保护）均 **PASS**；`./setup.sh check` 五项均 OK；备份 20 份；权限正确；Git 未跟踪/未暂存任何 Profile 或 Secret。

## 待实机 POC（未在本机会话内执行）

- 真实 Codex 完整退出 → 切换 → 重启；
- 20 次真实双向切换；
- 第二台用户名不同 Mac clone + setup；
- Shortcut 一键切换 + 真实模型调用确认。

说明：以上需要真实退出并重启 Codex Desktop 与人工确认模型调用，无法从正在运行的 Codex 会话内执行。

---

# V1.4 评估 — 拒绝架构扩展，确认 auth.json 不变式

日期：2026-09-09  
状态：评估完成，未实施 V1.4 架构

结论：

> V1.4 文档的 Provider Adapter、lib/scripts/logs/state.json 目录结构、字段级 Patch、Session Namespace 隔离与 CC Switch 预留与范围约束冲突，**不实施**。只采纳 P0「Switcher 永不触碰 `~/.codex/auth.json`」。

变更：

- `tests/test-switcher.zsh`：新增 `auth.json` 哨兵不变式测试，验证正常切换、连续切换与中断路径均不创建 / 改写 / 删除 `~/.codex/auth.json`。
- 对原上传版 V1.4 文档做了基于实机证据的核对与修正（auth.json / Session Namespace / GPT model_provider / 命名 / 目录结构），并以 V1.3 对齐；V1.4 文档文件已随回退移除。
- 实机只读证据：`~/.codex/sessions` 为按日期扁平树；`session_index.jsonl` 仅含 `id`、`thread_name`、`updated_at`，无 provider；单会话文件内记录 `model` 与 `model_provider` 元数据 → 会话存储不按 Provider 分区，原 V1.4「Session Namespace」机制不成立。

未采纳项（保留在产品决策，需产品负责人确认）：

- Provider Adapter / CC Switch 预留。
- `lib/`、`scripts/`、`logs/`、`state/state.json` 目录结构。
- 字段级配置 Patch（当前保持已验证快照整体替换）。
- Session Namespace 隔离（通过 `model_provider` 区分 GPT / DeepSeek 会话，未经验证）。

---

# V1.3 — Reliability P0 + Unified Naming

日期：2026-09-09  
状态：代码已落 / 待目标 Mac 实机 POC

## 变更

- 主脚本统一命名为 `bin/codex-switcher.sh`（不再使用 `codex-switch.sh`）。
- 切换彻底退出升级为 P0：graceful -> TERM -> KILL -> 确认 `/Codex.app/Contents/` 零残留；有残留则中止，不修改配置。
- 新增并发锁 `$HOME/.codex/switcher/.switch.lock`，避免 Shortcut 连点竞态。
- 修正备份轮转：按修改时间保留最近 20 份。
- 目标参数保留 `gpt` / `deepseek`，兼容别名 `openai|codex`（-> gpt）、`deep`（-> deepseek）。
- 新增 `bin/test-deepseek.sh`：首次 DeepSeek 配置前的 Responses API 人工 POC。
- 新增 `install.sh`：固定根目录 `$HOME/.codex/switcher` 的 Git 分发/更新入口。
- 更新 `setup.sh`、README、AGENTS、.gitignore、测试脚本，统一命名与约束。
- PRD / Technical Architecture 文档名统一为 `codex-switcher-*-V1.3.md`（不再使用 `Codex_Desktop_Switcher_` 前缀）。
- 修复进程匹配：Codex Desktop 实际为 `/Applications/ChatGPT.app`，改用 `Contents/(MacOS|Frameworks)` 匹配，切换脚本可自动退出 Codex，无需手动退出。
- 切换启动后 best-effort 调用内部深链 `codex://threads/new` 新建 Codex 任务；该内部路由不保证应用冷启动时的最终落点。

## 验证

- `zsh -n`：PASS（全部 shell 文件）。
- 临时目录自动测试（静默成功、可见错误、双向切换、20 次连续切换、备份轮转、预检保护、中断安全、安装与 Profile 捕获）：PASS。
- 真实 Codex 完整退出、20 次真实双向切换、第二台 Mac clone+setup：未验证（待实机 POC）。

## 约束

> 所有相关文件统一命名为 `codex-switcher`。

---

# V1.1 — Silent Switching

日期：2026-09-09

## 修改

- 移除 GPT / DeepSeek 正常切换时的 macOS Notification。
- 移除正常切换成功时的终端输出。
- 移除 Codex 启动确认检测及“请手动检查”提示。
- macOS Shortcuts 由用户确认只保留 Shell 调用。
- 正常切换现在完全静默。

## 保留

- 所有异常继续通过 stderr 输出。
- Codex 正常退出和 `open -a Codex` 自动启动。
- 配置预检、时间戳备份、原子替换和最近 20 份轮转。
- DeepSeek models 快照、`state` 文件和 Secret 安全规则。

## 验证

- `zsh -n`：PASS。
- 成功切换零输出：PASS。
- 失败切换保留错误：PASS。
- 双向切换、连续 20 次、备份轮转、缺文件保护和中断安全自动测试：PASS。
- GPT Restore、两个真实 Profile、Shortcuts 与真实双向切换：用户确认 PASS。

## 原因

> 用户可以直接在 Codex 页面确认当前模型。设计原则：成功静默，失败提示。

---

# V1.0 — MVP Implementation

日期：2026-09-09

## 新增

- 新增 `codex-switcher.sh`，支持 `gpt` 与 `deepseek` 两个显式目标。
- 新增切换前完整预检、Codex 正常退出与 10 秒超时保护。
- 新增 `config.toml` 时间戳备份，并自动保留最近 20 份。
- 新增同文件系统暂存与原子替换；DeepSeek models 先安装，config 最后提交。
- 新增不安全路径保护，拒绝符号链接、目录或错误文件类型。
- 新增 Codex 重启、进程出现检查与 macOS Notification。
- 新增 `setup.sh`，负责私有目录初始化、脚本安装和人工确认后的 Profile 捕获。
- 新增 `README.md` 和两个纯 zsh 测试脚本。
- 新增 `人工测试操作流程.md`，覆盖 Profile 固化、Shortcut、20 次真实切换、安全检查和故障记录。

## 验证

- `zsh -n`：PASS。
- GPT → DeepSeek 临时目录切换：PASS。
- DeepSeek → GPT 临时目录切换：PASS。
- 连续 20 次交替切换与备份轮转：PASS。
- 缺少 models 快照时配置不变：PASS。
- config 提交前模拟中断时原配置不变：PASS。
- setup 安装、Profile 捕获、权限与确认保护：PASS。
- 真实 Codex 退出、启动、模型调用、Shortcut 点击和连续 20 次切换：未验证。

## 当时阻塞

- 本机尚无 `~/.codex/models.json`。
- 本机尚无 `~/.codex/switcher/profiles/gpt.toml`、`deepseek.toml` 和 `models.deepseek.json`。
- GPT Restore 的最终实际可用性仍需用户确认。

---

# V1.0 — MVP Baseline

日期：2026-09-09

## 新增

- 完成 DeepSeek API 在 Mac Codex Desktop 的人工接入验证。
- 完成 `deepseek-v4-flash` 可用性验证。
- 明确最终 MVP 为：
  - 一个 zsh 脚本
  - 两个 macOS Shortcuts
  - 两个已验证 Profile
  - 自动备份
  - 自动重启 Codex
- 增加本地 Profile 目录规范。
- 增加本地 Secret 权限要求。
- 增加 20 次双向切换验收标准。

## 修改

### Change #001

原方案：

> Python 脚本 + Shortcuts + TOML 字段级 Patch。

新方案：

> zsh + Shortcuts + 已验证配置快照切换。

原因：

- 用户明确要求越简单越好。
- DeepSeek 接入已经人工验证成功。
- 当前只需要在两个确定状态之间切换。
- 暂时没有必要引入 TOML parser 或运行时依赖。

边际收益：

> 代码量更低、依赖更少、开发更快、排查更简单。

边际成本：

> 用户后续手工修改 Codex 配置时，需要刷新两个 Profile，否则配置快照可能变旧。

当前判断：

> 对个人 MVP 可接受。

---

### Change #002

原方案：

> 直接复制静态 config 文件。

新方案：

> 每次切换前先自动备份当前 `config.toml`，再复制 Profile。

原因：

> 用非常低的实现成本解决配置损坏的 P0 风险。

---

### Change #003

DeepSeek API Key：

> 不进入项目代码与 Git。

保存位置：

```text
~/.codex/switcher/profiles/deepseek.toml
```

权限：

```text
chmod 600
```

目录：

```text
chmod 700 ~/.codex/switcher
```

---

# POC 状态

## POC #001 — DeepSeek 接入

日期：2026-09-09

状态：

> PASS

验证内容：

- DeepSeek API Key 可接入。
- Codex Desktop 可使用 DeepSeek。
- `deepseek-v4-flash` 可运行。

---

## POC #002 — GPT Restore

日期：2026-09-09

状态：

> PASS（用户确认）

确认结果：

- 官方 `Restore the default Codex configuration` 流程已完成。
- GPT 实际调用已通过用户测试。

---

## POC #003 — 连续双向切换

状态：

> PASS（用户确认）

目标：

> 连续 20 次 GPT ↔ DeepSeek 切换，无配置损坏。

---

# Bug 记录

## Bug #001 — 无法稳定直达 Codex 工作区首页

日期：2026-09-09

状态：不修复（当前 Codex Desktop 能力限制）

- `codex://space` 实机验证仍进入 GPT 默认聊天区。
- 本机应用包检查确认该 URL 不是可消费的外部导航路由。
- 已回退无效实现，不继续扩大 MVP。

---

# 下一版本计划

## V1.0 Implementation

已完成：

- `codex-switcher.sh`
- `setup.sh`
- backup
- macOS Notification
- GPT Profile
- DeepSeek Profile
- DeepSeek models snapshot
- 两个 Shortcut
- 真实端到端验收

V1.1 已移除 macOS Notification，其余项目均已完成。

不做：

- Python
- Swift
- 自动 Router
- 菜单栏
- Token 统计
