# Project Memory

项目：Codex Desktop Switcher  
最后更新时间：2026-09-09

---

# 1. 项目背景

用户希望：

> 在 Mac Codex Desktop 中，根据任务复杂度在 GPT 与 DeepSeek 之间快速切换。

最开始考虑过：

- Codex Profile
- 双 Codex App
- Python Switcher
- 自动 Router
- 菜单栏 App

当前已经收敛为：

> 一个 zsh 脚本 + 两个 macOS Shortcuts。

---

# 2. 当前状态

当前版本：

> V1.1 Completed

已完成：

- DeepSeek API 接入人工验证。
- `deepseek-v4-flash` 人工验证可用。
- 官方 DeepSeek Codex 配置流程已跑通到 DeepSeek 使用阶段。
- 产品方案已经收敛到最小版本。
- 5 个项目文档已更新。
- 已实现 `codex-switch.sh`：预检、正常退出、备份、原子替换、备份轮转和静默重启。
- 已实现 `setup.sh`：安装脚本并在人工确认后捕获私有 Profile。
- 已增加纯 zsh 自动测试，不读写真实 Codex 配置。
- 已通过临时目录中的双向切换、20 次连续切换、备份轮转、缺文件保护和中断安全测试。
- GPT、DeepSeek 与 DeepSeek models 三个私有快照已存在且权限正确。
- GPT Restore、Shortcut 和真实双向切换已由用户确认通过。
- V1.1 已移除正常通知、成功输出和启动确认检测，错误仍输出到 stderr。

当前无需继续开发：

- 保持 MVP 稳定使用。
- Codex 配置变化后，按已验证流程刷新 Profile。
- 只有出现真实问题或高频新需求时再进入下一版本。

---

# 3. 关键决策记录

## Decision 001 — 不开发 Mac 原生软件

日期：2026-09-09

决策：

> V1 不使用 Swift、Electron、Tauri。

原因：

- 当前核心问题不是 UI。
- macOS Shortcut 已经可以提供桌面/Dock 入口。
- 原生 App 的边际收益很低。
- 会明显增加开发、签名、升级与维护成本。

最终方案：

> Shortcuts 只负责入口，zsh 负责核心逻辑。

---

## Decision 002 — 从 Python 进一步收敛到 zsh

日期：2026-09-09

原方案：

> Python 读取和修改 TOML。

新方案：

> 保存两个已经人工验证的配置快照，zsh 负责切换。

原因：

- 用户要求越简单越好。
- 目前只有两个明确状态。
- 不需要动态生成复杂配置。
- 不需要数据库。
- 不需要自动模型判断。

代价：

> 如果 Codex 配置后来发生手工变化，需要刷新 Profile。

当前判断：

> 个人 MVP 阶段值得接受。

---

## Decision 003 — 不使用 DeepSeek 官方远程脚本作为日常 Switcher

日期：2026-09-09

官方脚本用途：

> 第一次接入、验证、恢复。

日常切换不直接每次下载并执行官方脚本。

原因：

- 官方脚本是交互式。
- 远程脚本未来内容可能变化。
- 每次执行需要用户选择。
- 无法形成真正的一键体验。

最终方案：

> 只把官方脚本作为 POC 和首次配置工具。

---

## Decision 004 — Profile 必须来自“真实验证后的配置”

日期：2026-09-09

DeepSeek Profile：

> 从已经实际成功运行的 DeepSeek `config.toml` 保存。

GPT Profile：

> 从恢复成功、实际确认可用的 Codex GPT `config.toml` 保存。

禁止：

> 根据文档手写一份“理论上应该能用”的完整配置，然后直接作为生产 Profile。

原因：

> 当前项目最重要的是可靠，不是配置优雅。

---

## Decision 005 — API Key 本机明文保存是 V1 可接受取舍

日期：2026-09-09

位置：

```text
~/.codex/switcher/profiles/deepseek.toml
```

要求：

- 目录权限 700。
- 文件权限 600。
- 不进入 Git。
- 不输出日志。

考虑过：

> macOS Keychain。

暂缓原因：

> 对个人本机 MVP，Keychain 增加的实现成本高于当前边际收益。

触发升级：

> 工具对外分发，或用户明确要求更高 Secret 安全级别。

---

## Decision 006 — 配置文件最后提交

日期：2026-09-09

决策：

> 所有目标文件先在 `~/.codex` 同一文件系统内暂存；DeepSeek models 先安装，`config.toml` 最后通过 `mv` 原子替换。

原因：

- 预检或暂存失败时不退出 Codex、不修改当前配置。
- 中断发生在 config 提交前时，当前 Provider 仍然保持可用。
- DeepSeek config 生效时，对应 models 快照已经存在。
- 不需要引入事务框架或额外运行时。

---

## Decision 007 — 成功静默，失败提示

日期：2026-09-09

决策：

> V1.1 删除正常切换中的 Notification、成功输出和启动确认检测，只保留 stderr 错误。

原因：

- 用户可以直接在 Codex 页面确认当前模型。
- 正常提示没有新增价值，反而打断操作。
- Shortcuts 只负责调用 Shell，交互更接近无感切换。
- 配置安全逻辑与可诊断错误保持不变。

---

# 4. 产品取舍

## 当前主动放弃

- 自动 Router。
- 双实例。
- 多模型并发。
- Swift UI。
- 菜单栏。
- Keychain。
- Token 统计。
- 配置智能 merge。
- 远程服务。
- 账号系统。

核心判断：

> 这些功能都不能显著提高“一键切换是否可用”这一核心价值。

---

# 5. 当前架构

```text
macOS Shortcut
      ↓
codex-switch.sh
      ↓
退出 Codex
      ↓
备份当前 config
      ↓
选择目标 Profile
      ↓
复制到 ~/.codex/config.toml
      ↓
需要时复制 models.json
      ↓
启动 Codex
      ↓
静默结束
```

无：

- 后台服务
- 数据库
- 网络服务
- GUI App

---

# 6. 已知风险

## 风险 1：Profile 变旧

场景：

> 用户在 GPT 模式下增加 MCP 或修改 Codex 设置，随后切到旧 DeepSeek Profile。

影响：

> 新配置可能不出现在 DeepSeek Profile。

V1 处理：

> 提供“重新生成 Profile”流程，不做自动 merge。

## 风险 2：API Key 明文

处理：

- 本机目录。
- 700 / 600 权限。
- 不入 Git。

## 风险 3：Codex 配置格式变化

处理：

> Codex 大版本升级后先人工测试，不自动假设兼容。

---

# 7. 下一阶段重点

当前：

> V1.1 已完成，保持稳定使用。

只有发生以下情况才继续开发：

- Profile 失同步真实影响使用。
- Codex 配置格式升级导致切换失败。
- 用户提出明确且高频的新需求。

---

# 8. 给未来 Codex 的说明

开始修改前先读：

1. `AGENTS.md`
2. `Codex_Desktop_Switcher_PRD_V1.md`
3. `Codex_Desktop_Switcher_Technical_Architecture_V1.md`
4. `Project_Memory.md`
5. `Change_Log.md`
6. 实际代码

当前不要重新引入：

- Python
- Swift
- Router
- daemon
- 数据库

除非当前 zsh 方案已经出现明确、真实、可复现的问题。

核心验收问题只有一个：

> 用户能不能点两个按钮，长期可靠地切 GPT / DeepSeek？
