# Project Memory

项目：codex switcher  
最后更新时间：2026-09-10

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

> V1.3.6 Hotfix 已合并 / 待目标 Mac 实机 POC

已完成：

- DeepSeek API 接入人工验证。
- `deepseek-v4-flash` 人工验证可用。
- 官方 DeepSeek Codex 配置流程已跑通到 DeepSeek 使用阶段。
- 产品方案已经收敛到最小版本。
- 已实现 `bin/codex-switcher.sh`：预检、完整退出 Codex.app（graceful -> TERM -> KILL -> 零残留）、并发锁、备份轮转、原子替换、静默重启。
- 已实现 `bin/test-deepseek.sh`：首次 DeepSeek 配置前的 Responses API 人工 POC。
- 已实现 `install.sh`：固定根目录 `$HOME/.codex/switcher` 的 Git 分发/更新。
- 已实现 `setup.sh`：install / save-deepseek / save-gpt / check。
- 已更新 README、AGENTS、Change_Log、.gitignore，统一命名为 `codex-switcher`。
- 临时目录自动测试基线已覆盖静默、可见错误、双向、20 次、轮转、预检、中断安全、安装/捕获；V1.3.2 新增 GPT models 基线与卸载回归测试，待目标 Mac 执行。

待实机 POC：

- 真实 Codex 完整退出验证。
- 20 次真实双向切换。
- 第二台用户名不同 Mac clone + setup。
- Shortcut 改用 `bin/codex-switcher.sh gpt|deepseek`，并按需首次授权“允许运行脚本”。

---

# 3. 关键决策记录

## Decision 015 — Bootstrap 必须与 DeepSeek 官方当前安装 URL 完全对齐

日期：2026-09-10

实机反馈：

> V1.3.4 使用 cache-buster 后仍拿到两模型脚本；V1.3.5 又引入了未由官方文档确认的备用 shell 地址。当前官方 Codex 文档明确给出的 macOS/Linux 安装入口只有 `codex-deepseek-setup-en.sh`，且页面明确声明菜单包含 Flash / Pro / Vision 三个模型。

决策：

- Bootstrap 只使用官方文档当前明确给出的 `codex-deepseek-setup-en.sh`。
- 不修改 URL，不追加 query/header，不猜备用 endpoint。
- 下载文件仅做 Vision 能力断言，不自行 patch 官方脚本。
- 如果同机官方命令与 bootstrap 得到不同结果，下一步必须比较实际响应/哈希，不再通过假设服务端缓存来继续改代码。
- zsh wrapper 退出码统一使用 `rc`，禁止 `status`。

状态：

> 代码已合并；目标 Mac A/B 实机 POC 待验证。


## Decision 014 — 不把 CDN cache-buster 当作版本正确性保证

日期：2026-09-10

实机证据：

> V1.3.4 对 `codex-deepseek-setup-en.sh` 增加时间戳 query 与 no-cache 后，仍下载到不含 Vision 的脚本，而 DeepSeek 当前官方文档明确列出三个 Codex 模型。同时 README 外层 zsh 命令暴露 `status` 为只读变量的问题。

决策：

- 撤销“强制绕过缓存即可得到最新脚本”的假设。
- 使用 DeepSeek 官方原始 CDN URL，不追加 query。
- 尝试 `codex-deepseek-setup.sh` 和 `codex-deepseek-setup-en.sh` 两个官方 shell 资产，以 Vision 模型标识做能力检测。
- 只运行满足三模型能力的官方脚本；如果都不满足则停止，不复制/patch 官方脚本。
- Shell wrapper 禁止使用 zsh 特殊只读变量名 `status`；退出码变量统一使用 `rc`。

未知：

> DeepSeek 官方文档与不同 CDN shell 资产之间出现版本不一致的具体发布/缓存机制尚未确认，不做推测。

状态：

> 代码已合并；目标 Mac 实机 POC 待验证。


## Decision 013 — DeepSeek 模型菜单必须来自官方最新脚本并做能力校验

日期：2026-09-10

问题：

> DeepSeek 官方当前 Codex 文档已有三个模型，但固定 CDN URL 在一键初始化中可能返回旧的两模型 setup，导致 bootstrap 与“直接运行官方首次安装”体验不一致。

决策：

- 不在 codex-switcher 内手写第三个模型，也不 fork DeepSeek 官方 setup。
- 每次首次 DeepSeek 初始化都对官方 CDN URL 加 cache-buster，并发送 no-cache 请求头。
- 下载后以 `deepseek-v4-flash-vision-exp` 作为“当前三模型版”的最小能力标记。
- 校验失败直接停止，避免静默降级到旧的两模型版本。
- 仍然由 DeepSeek 官方脚本负责 API Key、models.json、config.toml 和菜单逻辑。

状态：

> 代码已合并；目标 Mac 三模型菜单实机 POC 待验证。


## Decision 012 — DeepSeek 官方 backup-deepseek 视为外部状态机，不直接删除

日期：2026-09-10

问题：

> DeepSeek 官方 setup 自己维护 `~/.codex/backup-deepseek`。当 Switcher 或上一次失败流程使当前 `config.toml/models.json` 与该备份状态不一致时，官方脚本会主动中止，导致“一键初始化”无法重入。

决策：

- bootstrap 在调用官方 setup 前先检查官方备份状态。
- 当前仍为 DeepSeek 且 `models.json` 缺失：按官方建议调用 Restore（9），不手工拼配置。
- 当前已为 GPT 但旧 `backup-deepseek` 仍存在：不让旧备份覆盖当前 GPT；将旧目录重命名归档后，让官方 setup 重新生成一致的新备份。
- 旧备份只移动保留，不删除。
- 临时官方脚本的 cleanup 必须在 `set -u` 下安全，禁止局部变量 EXIT trap 再次报错。

状态：

> 代码已合并，截图对应 Mac 实机重试待验证。


## Decision 011 — GPT models.json 必须按已验证基线恢复

日期：2026-09-10

问题：

> DeepSeek 会写入 `~/.codex/models.json`。旧版切回 GPT 只恢复 `config.toml`，可能留下 DeepSeek models；同时旧卸载逻辑存在误删未知 `models.json` 的风险。

决策：

- `save-gpt` 同时记录 GPT 的 models 基线：存在则保存 `models.gpt.json`，不存在则保存 `models.gpt.absent`。
- 切回 GPT 时按该已验证基线恢复。
- 对 V1.3.1 及更早的旧安装，不猜 GPT 默认状态；仅当当前 `models.json` 与 `models.deepseek.json` 完全一致时自动清理。
- 卸载仅修改可确认属于 Switcher 的 models；未知文件保留。
- README 的标准卸载入口下载 GitHub main 最新 `uninstall.sh`，解决旧本机没有该文件导致的一键卸载失败。

状态：

> 代码已合并，目标 Mac 实机 POC 未验证。

## Decision 010 — 安装/卸载入口统一为固定路径

日期：2026-09-10

决策：

> 新 Mac 的首次安装入口收敛为一个远程 bootstrap 命令；运行后仓库统一落在 `$HOME/.codex/switcher`。macOS Shortcut 永远只引用该固定目录和 `$HOME`，不依赖具体用户名。

实现：

- `bootstrap.sh`：Git clone/update → `setup.sh install` → GPT Profile 确认与保存 → DeepSeek 官方 Codex setup → DeepSeek 人工验证 → 保存 DeepSeek Profile → `setup.sh check`。
- `uninstall.sh`：优先恢复 GPT Profile，再清理 Switcher 与 DeepSeek models / Profile；保留 `auth.json` 与 App。
- README 顶部提供首次安装、卸载、两颗 Shortcut 的可复制命令。

边界：

- 首次 DeepSeek 接入不能完全无交互：官方 setup 仍要求选择模型、输入 API Key。
- 日常切换才是完全一键、无需 Terminal。
- 不为了“完全自动化”而绕过官方 DeepSeek setup 或把 API Key 写进命令行参数 / Git。

---

## Decision 000 — 终止 V1.5，确认 V1.3 Stable

日期：2026-09-10

产品负责人决定终止 V1.5「多 Runtime 物理会话隔离」方向，不合并 V1.5 POC，确认 **V1.3 Stable** 为当前版本。已回退 V1.5 POC 临时内容（`poc/` 及文档条目），并严格重跑 V1.3 自动化测试（`test-switcher.zsh` / `test-setup.zsh` 均 PASS）。真实退出/重启 Codex 的实机 POC 仍需在 Codex 会话外执行。

> 不要再次提出「多 Runtime 物理会话隔离」或「Session Namespace 隔离」方向。


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

## Decision 008 — 不继续实现工作区首页直达

日期：2026-09-09

结论：

> 当前 Codex Desktop 无法通过公开、稳定的深链直接进入工作区首页，保持原启动逻辑，不继续增加绕行方案。

依据：

- `codex://space` 实机验证仍进入 GPT 默认聊天区。
- 当前应用包的外部路由解析对 `space` 返回空结果，后续 `spacePage` 处理也是空操作。
- `codex://threads/new` 只能导航到新建 Codex 任务，不等同于工作区首页，且没有官方稳定性承诺。

---

## Decision 009 — V1.4 评估：不实施架构扩展，确认 auth.json 不变式

日期：2026-09-09

结论：

> V1.4 文档中的「Provider Adapter / lib+scripts+logs+state.json 结构 / 字段级 Patch / Session Namespace 隔离 / CC Switch 预留」与既有范围约束冲突，**不实施**。唯一确认采纳的是 P0「Switcher 永不触碰 `~/.codex/auth.json`」——该要求现状已满足，现补充为显式回归测试。

依据：

- 现有 `bin/codex-switcher.sh` 只操作 `config.toml`、`models.json`、`switcher/state` 与 `profiles/`，从不引用 `auth.json`。
- 实机 Profile 事实：GPT `gpt.toml` 无 `model_provider` 行，仅 `model = "gpt-5.6-sol"`；DeepSeek `deepseek.toml` 才有 `model_provider = "deepseek"` 与 `[model_providers.deepseek]`。V1.4「GPT → model_provider=openai」是对已验证快照的猜测，违背「已验证快照 > 自动推断配置」与「不尝试猜 GPT 默认配置」。
- Session Namespace 隔离是 Codex 运行时行为，无法仅靠 `model_provider` 从配置层保证，配置为未验证假设；按「当前真实需求 > 提前扩展」暂不投入。
- 字段级 Patch 与 Provider Adapter 属架构扩展，违背「MVP > 完整系统 / 简单脚本 > 原生 App / 不主动扩展功能」。
- V1.4 文档路径使用 `codex-switch.sh`，与本项目命名约定 `codex-switcher.sh` 不一致，不可直接照搬。
- 会话存储实机证据：`~/.codex/sessions` 为按日期扁平树；`session_index.jsonl` 仅 `id`/`thread_name`/`updated_at` 三字段，无 provider；单会话文件内记录 `payload.model` 与 `payload.model_provider`。→ Provider 是会话内容元数据，不是存储分区维度；无法通过 `model_provider` 实现 Session Namespace 隔离。

实施：

- `tests/test-switcher.zsh` 新增 auth.json 哨兵不变式：切换 / 多次切换 / 中断路径均不得改动 `~/.codex/auth.json`。
- 对原上传版 V1.4 文档做了基于实机证据的核对与修正（PRD + Technical Architecture 对齐 V1.3），固化「已采纳 / 不采纳」结论；V1.4 文档文件已随回退移除，仅保留本条决策。

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
codex-switcher.sh
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

> V1.3.6 Hotfix 已合并 / 待目标 Mac 实机 POC。

待实机 POC：

- 真实 Codex 完整退出验证。
- 20 次真实双向切换。
- 第二台用户名不同的 Mac clone + setup。

只有发生以下情况才继续开发：

- Profile 失同步真实影响使用。
- Codex 配置格式升级导致切换失败。
- 用户提出明确且高频的新需求。

---

# 8. 给未来 Codex 的说明

开始修改前先读：

1. `AGENTS.md`
2. `codex-switcher-PRD-V1.3.md`
3. `codex-switcher-Technical-Architecture-V1.3.md`
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
