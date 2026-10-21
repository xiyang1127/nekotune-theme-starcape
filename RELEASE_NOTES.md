本次为发布规范维护版本，插件功能和设置不变。

- 原生安装包统一为 `<插件ID>-<版本>-linux.zip` / `windows.zip`；平台无关主题使用 `<插件ID>-<版本>.zip`。
- 下载附件只保留安装包和 `SHA256SUMS.txt`，不再提供 JSON 构建信息附件。
- `SHA256SUMS.txt` 覆盖所有 ZIP，构建环境在 CI 中校验并记录。
- 发布前自动校验标签、清单版本、ZIP 结构和平台完整性。

安装：下载 `nekotune.theme-starcape-1.1.2.zip`，从 NekoTune「设置 → 外观」导入；同一份包适用于 Linux 和 Windows。
