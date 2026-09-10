# codex-switcher-PRD-V1.3

版本：V1.3.5 Hotfix（基于 V1.3）  
日期：2026-09-10  
状态：V1.3 代码已落 / 待实机 POC；此前 V1.1 已完成

---

# 1. 产品概述

## 产品定位

一句话：

> 在 macOS 上用两个桌面入口，一键在 Codex GPT 与 DeepSeek 之间切换，不改项目、不改工作流。

## 背景

用户已经完成以下验证：

- DeepSeek API 已成功接入 Mac Codex Desktop。
- `deepseek-v4-flash` 可以在 Codex 中正常使用。
- DeepSeek 官方配置方式可生效。

当前已经由用户确认：

- 官方恢复流程后，Codex 可以恢复到 GPT 配置。
- 两个真实 Profile 已固化。
- 两个 Shortcut 已完成修改并通过人工测试。
- 连续双向切换测试已完成。

## 为什么现在

当前手工切换方式已经证明可行，但操作仍然需要：

```text
打开 Terminal
↓
运行 DeepSeek 官方脚本
↓
选择模型 / 恢复
↓
重启 Codex
```

真正需要产品化的不是“接入 DeepSeek”，而是：

> 把已经验证可行的切换流程压缩成两个按钮。

---

# 2. 用户与场景

## 目标用户

最小用户画像：

- Mac 用户。
- 使用 Codex Desktop 开发。
- 同时使用 GPT 与 DeepSeek。
- 希望低风险、低成本切换。
- 不希望维护复杂本地服务或路由系统。

## 核心场景

### 场景 A：复杂、高返工成本任务

例如：

- 架构设计
- 复杂 Bug
- 跨模块重构
- 发布前 Review
- PRD → 技术方案

用户点击：

> 🧠 Codex GPT

### 场景 B：明确、低风险执行任务

例如：

- UI 微调
- CRUD
- 测试补充
- lint
- 文档整理
- 已经明确实现方案的开发

用户点击：

> ⚡ Codex DeepSeek

---

# 3. 核心痛点

当前方案的问题：

1. 每次切换需要 Terminal。
2. 需要记住 DeepSeek 官方脚本的操作方式。
3. 需要重新启动 Codex。
4. 当前 Provider 不够直观。
5. 手工操作有误覆盖配置的风险。

核心问题：

> 用户只想决定“这次任务用 GPT 还是 DeepSeek”，不应该关心 config.toml、models.json 和恢复流程。

---

# 4. 产品价值

一句话价值：

> 两个按钮决定 Codex 当前使用哪个模型。

项目上下文保持不变：

- Git
- 源码
- `AGENTS.md`
- PRD
- Technical Architecture
- `Project_Memory.md`
- `Change_Log.md`

设计原则：

> 模型可以切换，项目事实不能依赖模型聊天历史。

---

# 5. MVP 范围

## 必做功能

### 5.1 第一次初始化

初始化只做一次：

1. 保存已验证可用的 DeepSeek 配置快照。
2. 保存 DeepSeek `models.json`。
3. 恢复 Codex GPT。
4. 保存已验证可用的 GPT 配置快照。
5. 从 DeepSeek 官方原始 CDN URL 获取 setup，依次尝试中文/默认与英文 shell 资产，并校验当前三模型版本（Flash / Pro / Vision）。
6. 调用 DeepSeek 官方 setup 前检查 `backup-deepseek` 状态：不一致时优先官方 Restore 或保留并隔离旧备份。
7. 创建本地 Switcher 目录。
6. 创建两个 macOS 快捷入口。

本地目录：

```text
~/.codex/switcher/
├── profiles/
│   ├── gpt.toml
│   ├── models.gpt.json        # GPT 原本存在 models.json 时
│   ├── models.gpt.absent      # GPT 原本不存在 models.json 时（二选一）
│   ├── deepseek.toml
│   └── models.deepseek.json
├── backups/
└── state
```

### 5.2 Codex GPT

点击：

> 🧠 Codex GPT

执行：

```text
退出 Codex
↓
备份当前 config.toml
↓
复制 gpt.toml → ~/.codex/config.toml
↓
按 GPT 已验证基线恢复 models.json；旧安装仅清理可确认的 DeepSeek 快照
↓
启动 Codex
↓
静默结束
```

### 5.3 Codex DeepSeek

点击：

> ⚡ Codex DeepSeek

执行：

```text
退出 Codex
↓
备份当前 config.toml
↓
复制 deepseek.toml → ~/.codex/config.toml
↓
确保 models.json 存在
↓
启动 Codex
↓
静默结束
```

### 5.4 安全卸载

卸载必须兼容旧安装本机缺少 `uninstall.sh` 的情况，因此 README 的标准入口先从 GitHub 下载最新卸载脚本再执行。

卸载只清理能够确认属于本项目的 DeepSeek `models.json`；无法确认归属的文件必须保留。当前处于 DeepSeek 时，必须先恢复 GPT Profile，再删除 Switcher。

## 5.5 恢复

任何切换前：

> 自动备份当前 `config.toml`。

如果配置异常：

> 不继续启动 Codex，并提示用户恢复最近备份。

---

# 6. 明确不做

V1 不做：

- 自动识别任务难度。
- 自动 Router。
- 双 Codex 实例。
- 复制 Codex.app。
- Swift 原生 App。
- 菜单栏常驻程序。
- 数据库。
- 云端服务。
- 用户账号。
- Token / 费用统计。
- DeepSeek Pro 自动选择。
- 配置字段级智能合并。
- Keychain。
- 自动同步两个 Profile 的所有非 Provider 配置。

---

# 7. MVP 技术选择

最终选择：

> 一个 zsh 脚本 + 两个 macOS Shortcuts。

不使用 Python 的原因：

- 当前需求只是两个“已验证配置快照”之间切换。
- 不需要解析复杂业务数据。
- 不增加运行时依赖。
- macOS 原生即可完成进程退出、文件复制和启动。

核心脚本预计：

> 50～100 行。

---

# 8. 用户流程

## 第一次初始化

```text
DeepSeek 已验证可用
↓
保存 DeepSeek Profile
↓
恢复 GPT
↓
保存 GPT Profile
↓
创建 Switcher
↓
创建两个 Shortcut
↓
完成
```

## 日常使用

```text
判断任务返工风险
↓
高 → GPT
低 → DeepSeek
↓
点击对应入口
↓
Codex 自动重启
↓
开始工作
```

---

# 9. 成功指标

POC：

- DeepSeek API 接入：已通过。
- DeepSeek V4 Flash 在 Codex 使用：已通过。
- GPT 恢复：用户确认已通过。
- 临时目录连续 20 次双向切换：已通过。
- 真实 Codex 连续双向切换：V1.1 已确认通过；V1.3 变更后待实机重验。
- Shortcut 点击切换：用户确认已通过。

MVP：

- 正常切换无需 Terminal。
- 两个入口均能启动 Codex。
- 切换成功率 ≥ 99%。
- 配置损坏次数 = 0。
- API Key 不进入 Git。
- 用户能知道当前 Provider。

North Star Metric：

> 成功完成的模型切换次数 / 总切换次数。

---

# 10. 版本规划

## V0 POC

目标：

> 证明 GPT ↔ DeepSeek 的核心链路可行。

当前进度：

- [x] DeepSeek API 接入
- [x] DeepSeek 模型可用
- [x] 临时目录双向切换与连续 20 次自动测试
- [x] GPT 恢复确认
- [x] 真实 Codex 连续切换稳定性（用户确认）

## V1 MVP

目标：

> 两个桌面按钮完成日常模型切换。

必须：

- `codex-switcher.sh`
- GPT Profile
- DeepSeek Profile
- 配置备份
- 两个 Shortcuts
- 正常切换完全静默
- 异常情况保留错误输出

## V1.1

目标：

> 移除日常切换中的通知、弹窗、成功输出和启动确认检测。

已完成：

- 正常切换完全静默。
- Shortcuts 只保留 Shell 调用。
- 配置安全和错误输出保持不变。

后续只有出现真实需求才考虑：

- 第三个 DeepSeek Pro 按钮。
- `status` 命令。
- Profile 刷新命令。

## V2

只有 V1 已成为高频工具后考虑：

- Swift 菜单栏 App。
- Keychain。
- 多 Provider。
- 更完整的配置管理。

---

# 11. 风险

## P0

1. 配置快照覆盖用户后来新增的 Codex 配置。
2. DeepSeek API Key 明文存在本机 Profile。
3. Codex 更新后配置格式变化。
4. DeepSeek `models.json` 残留到 GPT，导致 GPT 启动后仍读取第三方模型目录或出现异常。
5. DeepSeek 官方 `backup-deepseek` 与当前配置不一致，导致官方 setup 为保护备份而主动中止。
6. DeepSeek 官方文档与某个官方 CDN shell 资产可能短时版本不一致，菜单只显示两个模型，与当前官方三模型能力不一致。
7. zsh wrapper 使用特殊只读变量名 `status`，失败路径产生 `read-only variable: status` 二次错误。

应对：

- 每次切换前自动备份。
- `~/.codex/switcher` 权限设为 `700`。
- Secret Profile 权限设为 `600`。
- 不提交该目录到 Git。
- 用户手工修改 Codex 配置后，需要重新生成 Profile 快照。
- GPT Profile 同时记录 `models.json` 存在/不存在的已验证基线；旧安装只对与 DeepSeek 快照完全一致的 `models.json` 做自动清理。
- bootstrap 不直接删除 DeepSeek 官方备份：DeepSeek 不完整态优先官方 Restore；GPT 态残留旧备份则时间戳归档后重建。
- bootstrap 不再假设 cache-buster 能保证版本新鲜度；改为依次验证两个 DeepSeek 官方 shell 资产，选择包含 `deepseek-v4-flash-vision-exp` 的版本，旧版两模型脚本拒绝执行。
- 一键命令退出码变量使用 `rc`，避免 zsh 的 `status` 只读参数冲突。

## P1

1. 切换需要重启 Codex。
2. GPT 与第三方 API 会话历史显示可能不同。
3. DeepSeek 部分 Codex 工具能力可能与 GPT 不完全一致。
4. 当前 Codex Desktop 没有公开、稳定的“工作区首页”深链；启动后的落点由应用决定。

应对：

> 这三个问题都不阻塞 V1，复杂任务随时切回 GPT。

---

# 12. 当前阶段建议

现在不要继续扩功能。

当前阶段：

> V1.3 代码已落 / 待目标 Mac 实机 POC。保持稳定使用，不继续扩功能。
