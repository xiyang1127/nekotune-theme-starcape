# 星穹 · Starcape — NekoTune 主题

独立的纯 QML 主题，ID 为 nekotune.theme-starcape。支持深浅配色、完整 Shell、
曲库、设置与动态音乐壁纸。无需 C++ 编译器、Qt 开发包或 Node.js。

## 构建与安装

    cmake -S . -B build
    cmake --build build
    ctest --test-dir build --output-on-failure

输出 build/packages/nekotune.theme-starcape.nktheme.zip，在宿主「设置 → 外观」
导入并确认信任。开发时可直接挂载本仓库的 theme/。
更新使用「更新主题包」，重新加载不会安装新 ZIP。故障时用 Ctrl+Shift+E 恢复界面，
或以 --safe-mode 启动宿主。

同一份包可用于 Linux 和 Windows，宿主界面 API 必须兼容。
详细功能和资源来源见 [功能说明](docs/FEATURES.md)，历史宿主验收见 [验收记录](VALIDATION.md)。

## CI 与发布

提交与 PR 自动打包，检查 ZIP 清单、QML 入口和资源完整性，并提供 SHA-256。
更新 theme/extension.json 后推送同版本的 v<version> 标签，生成草稿 Release；
实际安装、切换和更新验收后再公开。静态包检查不替代视觉和宿主交互验收。
原有 tests/integration_test.cpp 可通过宿主的
NEKOTUNE_EXTERNAL_TESTS_DIR=/path/to/nekotune-theme-starcape/tests 运行。
