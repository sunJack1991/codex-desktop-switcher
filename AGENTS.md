# AGENTS.md

## 1. 项目角色

项目：codex switcher。

目标：用最小、可恢复的 zsh + macOS Shortcuts，在已经人工验证过的 GPT / DeepSeek 配置快照之间切换。

产品负责人决定范围；工程实现不得主动扩大 MVP。

## 2. 核心原则

优先级：

> 配置安全 > 功能数量

> DeepSeek 官方安装结果 > Switcher 生成配置

> 已验证快照 > 自动推断配置

> 简单脚本 > 原生 App

> MVP > 完整系统

## 3. V1 技术边界

允许：

- zsh
- macOS Shortcuts
- macOS 原生命令
- 本地文件快照
- timestamp backup
- 原子替换

禁止主动引入：

- Python / Node / Swift / Electron / Tauri
- daemon / DB / Web 服务
- 自动 Router
- DeepSeek 第三方安装器逻辑

## 4. DeepSeek official-only 边界

首次 DeepSeek 安装固定使用：

```text
https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh
```

必须：

1. 官方 shell 下载后原样执行。
2. 模型菜单、API Key、`config.toml`、`models.json`、`backup-deepseek` 交给官方脚本。
3. 只有官方安装完成且用户实际验证可用后，才保存 DeepSeek Profile。
4. 保存 Profile 只做逐字节快照。

禁止：

- CDN 新旧版本判断。
- grep Vision 决定流程。
- 从 Flash 派生 Vision。
- 生成、补齐、删除或 Patch DeepSeek `models.json`。
- 修改 DeepSeek Provider 字段。
- 使用 `plutil` / `PlistBuddy` / `awk` 改写 DeepSeek 官方配置。
- 移动、删除、伪造 `~/.codex/backup-deepseek`。
- fork / patch DeepSeek 官方 setup。

官方 setup 异常时：停止初始化，提示用户直接运行同一官方脚本 / Restore；Switcher 不兜底。

## 5. 配置安全规则

1. 修改 `~/.codex/config.toml` 前必须备份。
2. 备份失败立即停止。
3. Codex 未完全退出时不切换。
4. API Key 不进入 Git、日志、README、Shortcut。
5. `~/.codex/auth.json` 永不触碰。
6. 不猜 GPT 默认配置。
7. 失败时宁可停止，也不能破坏当前配置。
8. `~/.codex/switcher` 权限 700；Profile 权限 600。

## 6. 日常切换

`codex-switcher.sh gpt|deepseek` 只恢复已经人工验证过的 Profile。

DeepSeek 日常快照必须来源于：

> DeepSeek 官方安装 → 用户实际验证 → `save-deepseek` 原样保存。

## 7. 开发流程

修改前检查：

- AGENTS.md
- PRD
- Technical Architecture
- Project Memory
- Change Log
- 实际脚本
- Git diff

实施原则：修改最少文件、增加最少依赖、保留恢复路径。

## 8. 验证

至少验证：

1. `zsh -n`。
2. GPT → DeepSeek。
3. DeepSeek → GPT。
4. Codex 完整退出 / 启动。
5. 备份存在。
6. 20 次连续切换。
7. API Key 不进 Git。
8. `auth.json` 不变。
9. bootstrap 不包含 DeepSeek catalog Patch / Vision 派生 / CDN 版本匹配。

## 9. 文档

必须维护：

- `codex-switcher-PRD-V1.3.md`
- `codex-switcher-Technical-Architecture-V1.3.md`
- `Project_Memory.md`
- `Change_Log.md`
- `AGENTS.md`

## 10. 当前下一步

完成 V1.3.8 official-only 首次初始化实机 POC；不要重新引入 V1.3.7 的本地 Vision 派生方案，也不要扩展多 Runtime / Session Namespace / GUI / Router。
