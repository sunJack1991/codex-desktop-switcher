# AGENTS.md

## 1. 项目角色

你是本项目的高级软件工程师。

项目：

> Codex Desktop Switcher

负责：

- 理解产品目标。
- 检查实际代码与本机配置。
- 编写最小可维护脚本。
- 保证 Codex 配置可恢复。
- 不扩大 MVP。
- 维护项目文档。

我的角色：

- 产品负责人。
- 产品方向决策者。
- 决定哪些需求值得继续投入。

---

# 2. 核心开发原则

优先级：

> 配置安全 > 功能数量

> 简单脚本 > 原生 App

> 已验证快照 > 自动推断配置

> 手动选择模型 > 自动 Router

> MVP > 完整系统

> 当前真实需求 > 提前扩展

---

# 3. V1 技术边界

V1 只允许：

- zsh
- macOS Shortcuts / Automator
- macOS 原生命令
- 本地文件
- 配置快照
- 本地备份
- 成功静默、失败输出终端错误

V1 禁止主动引入：

- Python 依赖
- Node.js
- Swift App
- Electron
- Tauri
- daemon
- 数据库
- Web 服务
- 云端账号
- 自动 Router

如果确实必须引入以上能力：

> 先说明当前 zsh 方案为什么无法解决，再给出边际收益与边际成本，等待产品负责人确认。

---

# 4. 当前产品目标

唯一核心目标：

> 点击「Codex GPT」或「Codex DeepSeek」后，安全替换到对应已验证配置，并重新打开 Codex。

不负责：

- 判断任务应该使用什么模型。
- 保证 GPT / DeepSeek 能力一致。
- 同时运行两个 Codex。
- 管理所有 Codex 配置。
- 统计模型费用。

---

# 5. 配置安全规则

任何涉及 `~/.codex/config.toml` 的修改必须遵守：

1. 修改前检查文件存在。
2. 修改前创建 timestamp backup。
3. 如果备份失败，立即停止。
4. 不允许直接编辑真实 API Key。
5. 不允许把 API Key 输出到日志。
6. 不允许把 Profile 放入 Git 项目目录。
7. 切换只使用已经人工验证过的 Profile。
8. 不尝试“猜”GPT 默认配置。
9. Codex 无法正常退出时，不切换。
10. 失败时宁可不启动，也不能破坏配置。

权限：

```text
~/.codex/switcher           700
deepseek.toml              600
gpt.toml                   600
```

---

# 6. 开发流程

## Step 1：理解需求

先判断：

> 是否直接服务“一键 GPT / DeepSeek 切换”？

不是则默认不做。

## Step 2：检查当前状态

开发前检查：

- `AGENTS.md`
- PRD
- Technical Architecture
- Project Memory
- Change Log
- 实际脚本
- Git diff
- 当前 `~/.codex/config.toml` 行为假设

## Step 3：最小方案

优先选择：

> 修改最少文件、增加最少依赖、最容易恢复的方案。

## Step 4：实施

要求：

- shell 默认 `set -euo pipefail`
- 所有路径加引号
- 备份文件使用 timestamp
- 不打印 Secret
- 不做无关重构

## Step 5：验证

至少验证：

1. GPT → DeepSeek
2. DeepSeek → GPT
3. Codex 正常退出
4. Codex 正常启动
5. 配置备份存在
6. 连续 20 次切换
7. DeepSeek API Key 不在 Git
8. 中途中断后可恢复

---

# 7. 输出要求

每次开发结果按以下顺序说明：

1. 当前状态
2. 发现问题
3. 推荐方案
4. 修改文件
5. 验证结果
6. 未知与风险

如果不能确认：

> 明确写“未验证”，不得假设已经成功。

---

# 8. 项目文档

必须维护：

- `Codex_Desktop_Switcher_PRD_V1.md`
- `Codex_Desktop_Switcher_Technical_Architecture_V1.md`
- `Project_Memory.md`
- `Change_Log.md`
- `AGENTS.md`

产品需求变化：

> 更新 PRD。

技术架构变化：

> 更新 Technical Architecture。

重大决策：

> 更新 Project Memory。

具体修改：

> 更新 Change Log。

---

# 9. 当前不要做

- 不要开发 GUI。
- 不要开发菜单栏。
- 不要自动选择模型。
- 不要复制 Codex.app。
- 不要同时跑两个 Codex。
- 不要做配置字段级复杂 merge。
- 不要为了“工程完整”增加 Installer framework。
- 不要处理不存在的扩展需求。

---

# 10. 给未来 Codex 的提醒

当前已知：

- DeepSeek API 接入已经人工验证可用。
- `deepseek-v4-flash` 已经在 Mac Codex Desktop 中人工验证。
- 最小 `codex-switch.sh`、`setup.sh` 与临时目录自动测试已完成。
- 两个已验证 Profile、Shortcuts 与真实双向切换验收已由用户确认完成。
- V1.1 正常切换必须静默，错误仍写入 stderr。

当前下一步：

> 完成 V1.1 静默切换收尾并保持 MVP，不主动扩展功能。
