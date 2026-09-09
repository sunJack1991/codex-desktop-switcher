# Change Log

项目：Codex Desktop Switcher

---

# Version History

# V1.3 — Reliability P0 + Unified Naming

日期：2026-09-09  
状态：代码已落 / 待目标 Mac 实机 POC

## 变更

- 主脚本统一命名为 `bin/codex-switcher.sh`（不再使用 `codex-switch.sh`）。
- 切换彻底退出升级为 P0：graceful -> TERM -> KILL -> 确认 `/Codex.app/Contents/` 零残留；有残留则中止，不修改配置。
- 新增并发锁 `$HOME/.codex/switcher/.switch.lock`，避免 Shortcut 连点竞态。
- 修正备份轮转：按修改时间保留最近 20 份。
- 目标参数统一为 `codex` / `deepseek`，保留别名 `gpt|openai`（-> codex）、`deep`（-> deepseek）。
- 新增 `bin/test-deepseek.sh`：首次 DeepSeek 配置前的 Responses API 人工 POC。
- 新增 `install.sh`：固定根目录 `$HOME/.codex/switcher` 的 Git 分发/更新入口。
- 更新 `setup.sh`、README、AGENTS、.gitignore、测试脚本，统一命名与约束。
- PRD / Technical Architecture 文档名统一为 `codex-switcher-*-V1.3.md`（不再使用 `Codex_Desktop_Switcher_` 前缀）。

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

暂无。

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
