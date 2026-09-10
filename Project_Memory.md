# Project Memory

项目：codex switcher  
最后更新时间：2026-09-10

## 1. 当前状态

当前版本：**V1.3.8 Hotfix**  
状态：代码已落 / 待目标 Mac 实机 POC。

当前产品已经收敛为：

> 一个 zsh 切换脚本 + 两个 macOS Shortcuts + 两套已验证 Profile。

核心目标只有一个：

> 用户点击 GPT / DeepSeek 后，安全切换到对应已验证状态并重新打开 Codex。

## 2. 当前已验证事实

- DeepSeek API 已人工接入 Codex Desktop。
- `deepseek-v4-flash` 已人工验证可用。
- GPT Restore 已人工验证可用。
- GPT / DeepSeek Profile 快照方案已验证。
- V1.1 真实双向切换已确认通过。
- V1.3 之后的完整退出、models 基线、bootstrap 等仍需目标 Mac 继续 POC。

## 3. 最重要决策

### Decision 017 — DeepSeek 安装严格 official-only

日期：2026-09-10

产品负责人明确：

> DeepSeek 所有模型安装只使用 DeepSeek 官方渠道；codex-switcher 不修改、补齐、派生任何 DeepSeek 模型配置。

最终规则：

- 首次安装固定使用：

```text
https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh
```

- 官方 shell 下载后原样执行。
- 模型菜单、API Key、`config.toml`、`models.json`、`backup-deepseek` 全部归 DeepSeek 官方脚本负责。
- Switcher 不做 CDN 新旧判断。
- Switcher 不 grep Vision 决定流程。
- Switcher 不从 Flash 派生 Vision。
- Switcher 不使用 `plutil` / `PlistBuddy` / `awk` 修改 DeepSeek 官方配置。
- 官方 setup 失败时停止，不由 Switcher 兜底。
- 官方安装完成且用户实际验证可用后，Switcher 只逐字节保存官方结果作为本机 Profile。

Decision 016“旧 catalog + Vision 派生”方案：**已撤销，不实施。**

## 4. 当前架构

```text
macOS Shortcut
      ↓
codex-switcher.sh
      ↓
完整退出 Codex
      ↓
备份当前 config
      ↓
恢复已验证 Profile
      ↓
恢复对应 models 基线/快照
      ↓
启动 Codex
```

首次 DeepSeek 安装单独走：

```text
bootstrap.sh
→ DeepSeek 官方 setup.sh 原样执行
→ 人工验证
→ 保存官方结果快照
```

## 5. 安全不变式

- `~/.codex/auth.json` 永不触碰。
- DeepSeek API Key 不进入 Git / 日志 / README / Shortcut。
- `profiles/` 不进入 Git。
- 配置修改前必须备份。
- Codex 未完全退出时不切换。
- 不猜 GPT 默认配置。
- DeepSeek 官方安装结果优先于 Switcher 生成配置。

## 6. 当前主动放弃

- 自动 Router。
- 双实例。
- Swift / Electron / Tauri GUI。
- daemon / DB / Web 服务。
- Keychain（V1 暂缓）。
- Token 统计。
- Session Namespace 隔离。
- DeepSeek 模型目录维护或补丁。

## 7. 下一步

只做 V1.3.8 实机 POC：

1. 新 Mac / 清理后环境运行 README bootstrap。
2. 确认直接进入 DeepSeek 官方模型菜单。
3. 确认不存在“CDN 旧版”“兼容兜底”“补齐 Vision”等 Switcher 流程。
4. 官方安装后实际调用 DeepSeek。
5. 通过后保存 Profile。
6. 再验证 GPT ↔ DeepSeek 双向切换与第二台 Mac。

除非出现新的真实、可复现问题，不扩大 MVP。
