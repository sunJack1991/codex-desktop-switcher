# codex-switcher-PRD-V1.3

版本：V1.3.8 Hotfix（基于 V1.3）  
日期：2026-09-10  
状态：代码已落 / 待实机 POC

## 1. 产品目标

在 macOS 上用两个桌面入口，一键在 Codex GPT 与 DeepSeek 之间切换；不改变项目、不引入后台服务、不让用户日常手工维护配置。

## 2. 核心用户与场景

目标用户：同时使用 Codex GPT 与 DeepSeek 的 Mac 开发者。

核心场景：复杂、高返工成本任务使用 GPT；明确、低风险执行任务使用 DeepSeek。用户只决定“这次用哪个模型”，不处理 `config.toml`、`models.json` 和恢复细节。

## 3. MVP 范围

### 3.1 首次初始化

1. 当前 GPT 已实际验证可用。
2. 保存 GPT Profile 与 GPT `models.json` 基线。
3. 仅从 DeepSeek 官方 CDN 获取并原样执行：

```zsh
bash <(curl -fsSL https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh)
```

4. 模型菜单、API Key、DeepSeek `config.toml`、`models.json`、`backup-deepseek` 全部由官方脚本负责。
5. Switcher 不检测脚本新旧版本，不补模型，不 Patch 官方配置。
6. 官方流程结束后，只检查 `config.toml` / `models.json` 存在且 Provider 为 DeepSeek。
7. 用户在 Codex 中实际验证 DeepSeek 可回复。
8. 验证成功后，原样保存官方生成结果为 DeepSeek Profile。

### 3.2 日常 GPT 切换

```text
退出 Codex
→ 备份当前 config.toml
→ 恢复 gpt.toml
→ 按 GPT 已验证基线恢复/清理 models.json
→ 启动 Codex
```

### 3.3 日常 DeepSeek 切换

```text
退出 Codex
→ 备份当前 config.toml
→ 恢复已验证 deepseek.toml
→ 恢复已验证 models.deepseek.json
→ 启动 Codex
```

注意：日常使用的是“官方安装 + 人工验证后保存的快照”，不是 Switcher 自己生成的 DeepSeek 配置。

## 4. DeepSeek 官方-only 边界

必须：

- DeepSeek 模型安装只用官方 `codex-deepseek-setup.sh`。
- 官方脚本下载后原样执行。
- 官方安装成功且人工验证后才允许保存 Profile。

禁止：

- 自行增加或删除 DeepSeek 模型。
- 从 Flash 派生 Vision。
- 修改官方 `models.json` 的 schema、context、instructions、priority、modalities 等字段。
- 修改官方 DeepSeek Provider 配置。
- 根据 CDN 脚本内容做新旧版本分流。
- 移动、删除、伪造 `~/.codex/backup-deepseek`。

若官方脚本异常：停止初始化，使用同一官方脚本的 Restore / 官方流程处理，不由 Switcher 兜底。

## 5. 安全要求

- 修改用户配置前必须备份。
- `~/.codex/switcher` 权限 700。
- 私有 Profile 权限 600。
- API Key 不进入 Git、日志、README、Shortcut。
- `~/.codex/auth.json` 永不触碰。
- Codex 未完全退出时不切配置。
- 失败时宁可停止，也不破坏当前可用状态。

## 6. 明确不做

- 自动 Router。
- 多实例。
- GUI / 菜单栏 App。
- Python / Node / Swift Runtime。
- 数据库或云服务。
- 配置字段级智能 merge。
- DeepSeek 第三方安装器或模型目录维护。

## 7. 验收标准

POC：

- 官方 DeepSeek setup 能正常出现并完成安装。
- Switcher 初始化过程中不出现 CDN 新旧判断、Vision 补齐或模型 Patch。
- DeepSeek 实际回复通过后才保存 Profile。

MVP：

- GPT ↔ DeepSeek 连续切换稳定。
- 配置损坏次数 = 0。
- API Key 不进入 Git。
- 第二台 Mac 可用同一 bootstrap + `$HOME` Shortcut 完成初始化。

North Star Metric：成功完成的模型切换次数 / 总切换次数。

## 8. 当前阶段

只完成 V1.3.8 official-only 首次初始化实机 POC，不继续扩大功能范围。
