# codex-switcher-Technical-Architecture-V1.3

版本：V1.3.8 Hotfix（基于 V1.3）  
最后更新时间：2026-09-10  
状态：代码已落 / 待实机 POC

## 1. 技术目标

在 Mac 上把 Codex GPT / DeepSeek 切换收敛为两个 Shortcut，同时保证配置可恢复、Secret 不进入 Git、不增加后台服务和额外 Runtime。

优先级：

> 配置安全 > 自动化

> DeepSeek 官方安装结果 > Switcher 生成配置

> 已验证快照 > 自动推断配置

> MVP > 完整配置管理器

## 2. 技术栈

- zsh
- macOS Shortcuts
- macOS 原生命令
- 本地文件快照
- timestamp backup

不引入 Python / Node / Swift / Electron / Tauri / daemon / DB。

## 3. 运行目录

```text
$HOME/.codex/switcher/
├── bin/codex-switcher.sh
├── profiles/
│   ├── gpt.toml
│   ├── models.gpt.json / models.gpt.absent
│   ├── deepseek.toml
│   └── models.deepseek.json
├── backups/
└── state
```

## 4. DeepSeek 首次安装架构

DeepSeek 官方脚本是唯一安装事实源：

```text
https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh
```

流程：

```text
bootstrap.sh
↓
保存已验证 GPT Profile
↓
curl 官方 setup 到临时文件
↓
bash 原样执行官方脚本
↓
官方脚本负责
  - 模型菜单
  - API Key
  - config.toml
  - models.json
  - backup-deepseek
  - Restore / 官方校验
↓
Switcher 只检查结果文件存在 + model_provider=deepseek
↓
用户在 Codex 中实际验证
↓
setup.sh save-deepseek
↓
逐字节保存官方生成结果
```

### 4.1 允许行为

- 下载官方 `codex-deepseek-setup.sh`。
- 原样执行。
- 检查结果文件是否存在。
- 检查 Provider 是否为 DeepSeek。
- 人工确认可用后复制官方输出为本机私有 Profile。

### 4.2 禁止行为

- grep Vision 后决定安装流程。
- 判断 CDN “新/旧版本”。
- 自行补 `deepseek-v4-flash-vision-exp`。
- 使用 `plutil` / `PlistBuddy` / `awk` 修改 DeepSeek `models.json` 或 Provider 配置。
- 在 Switcher 维护 DeepSeek model schema、instructions、context、priority、modalities。
- patch / fork 官方 setup。
- 移动、删除、伪造 `~/.codex/backup-deepseek`。

若官方 setup 失败：Bootstrap 停止，并提示直接运行同一官方命令；不做本地兼容兜底。

## 5. GPT Profile

保存当前已实际验证的 GPT `config.toml`。同时记录 GPT 的 `models.json` 基线：

- GPT 存在 `models.json` → `models.gpt.json`
- GPT 不存在 → `models.gpt.absent`

不猜 GPT 默认配置。

## 6. DeepSeek Profile

前提：DeepSeek 官方脚本已完成，并且用户在 Codex 中实际验证可用。

保存：

```text
~/.codex/config.toml → profiles/deepseek.toml
~/.codex/models.json → profiles/models.deepseek.json
```

这两份文件只做逐字节快照，不在保存阶段修改内容。

## 7. 日常切换

### GPT

```text
preflight
→ lock
→ 完整退出 Codex
→ backup config.toml
→ 原子恢复 gpt.toml
→ 按 GPT models 基线恢复/清理 models.json
→ 启动 Codex
```

### DeepSeek

```text
preflight
→ lock
→ 完整退出 Codex
→ backup config.toml
→ 原子恢复 deepseek.toml
→ 原子恢复 models.deepseek.json
→ 启动 Codex
```

## 8. 安全不变式

1. Codex 未完全退出时不改配置。
2. 修改前必须备份。
3. API Key 不进 Git / 日志。
4. `auth.json` 永不写入。
5. Profile 权限 600，目录权限 700。
6. DeepSeek 首次安装只接受官方脚本结果。
7. DeepSeek 官方安装失败时不由 Switcher 修复。

## 9. 测试

```zsh
./tests/test-switcher.zsh
./tests/test-setup.zsh
./tests/test-uninstall.zsh
./tests/test-bootstrap.zsh
```

`test-bootstrap.zsh` 的职责是防止未来重新引入 DeepSeek 模型 Patch / Vision 派生 / CDN 版本匹配逻辑。

## 10. 当前 POC

待目标 Mac 验证：

- bootstrap 直接进入官方 DeepSeek 菜单。
- 不出现 Switcher 自己的模型列表或兼容兜底。
- 官方安装成功后，DeepSeek 实际调用通过。
- Profile 保存后 GPT ↔ DeepSeek 双向切换稳定。
