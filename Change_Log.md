# Change Log

项目：codex switcher

## V1.3.8 — DeepSeek Official-Only Installation Boundary

日期：2026-09-10  
状态：已合并 main / 待目标 Mac 实机验证

### 修复

- 撤销 V1.3.7 的“旧两模型 catalog → 本地派生 Vision”兼容兜底。
- 首次 DeepSeek 接入固定使用：

```text
https://cdn.deepseek.com/api-docs/codex-deepseek-setup.sh
```

- 官方 shell 下载后直接交给 `bash` 原样执行。
- 删除 bootstrap 中 CDN 新旧判断、Vision 能力匹配、模型派生、`models.json` Patch、DeepSeek Provider 字段 Patch。
- 不再移动、归档、删除、伪造 DeepSeek 官方 `backup-deepseek`。
- Switcher 只检查官方执行结果是否存在且 Provider 为 DeepSeek。
- 用户实际验证成功后，`save-deepseek` 原样捕获官方生成的 `config.toml` / `models.json`。
- `tests/test-bootstrap.zsh` 改为 official-only 边界回归测试，防止未来重新引入 DeepSeek 模型修改逻辑。

### 产品边界

> DeepSeek 模型安装 = DeepSeek 官方职责。codex-switcher = 已验证配置快照的安全切换器。

### 待实机 POC

- README 一键初始化应直接进入 DeepSeek 官方菜单。
- 不应出现 Switcher 自己的模型列表、CDN 旧版判断或 Vision 补齐。
- 模型列表完全以 DeepSeek 官方脚本实际展示为准。
- 官方安装后实际验证 DeepSeek；通过后再保存 Profile。

---

## V1.3.7 — 已撤销方案

曾尝试在官方 CDN 返回两模型脚本时，由 Switcher 从 Flash catalog 派生 Vision。该方案已被 V1.3.8 / Decision 017 明确撤销，不属于当前产品边界。

---

## V1.3.6 及以前 — 历史摘要

- 修复 zsh `status` 只读变量问题，统一使用 `rc`。
- 增加固定运行目录 `$HOME/.codex/switcher`。
- 增加 bootstrap / uninstall。
- 增加 GPT `models.json` 基线记录与安全恢复。
- 增加 `auth.json` 不变式。
- 增加完整退出 Codex、并发锁、原子替换、备份轮转。
- V1.1 已确认真实 GPT ↔ DeepSeek 双向切换可用。

完整历史可通过 Git commit history 查看。
