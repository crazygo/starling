# Codex 环境初始化与自验计划

## 背景
当前容器缺少 `dart` / `flutter` 命令，导致无法在本地执行格式化、分析和测试。需要在仓库内提供可复用脚本，初始化 Codex 运行环境并完成自验。

## 目标
1. 在仓库中新增 `初始化 codex 环境` 的 shell 脚本。
2. 脚本可在无全局 Flutter 的环境中工作（安装到仓库本地 `.tooling/`）。
3. 执行脚本后可运行：
   - flutter/dart version
   - flutter pub get
   - flutter gen-l10n
   - flutter analyze
   - flutter test
4. 修复并提交任何自验过程中暴露的问题。

## 实施步骤
1. 新增 `scripts/init_codex_env.sh`：
   - 检查依赖（git/curl/unzip）。
   - 下载并解压 Flutter stable 到 `.tooling/flutter`（若不存在）。
   - 导出 PATH 让当前 shell 可直接使用 `flutter`/`dart`。
   - 输出版本信息。
2. 运行脚本并验证命令可用。
3. 执行项目自验（至少 analyze + test）。
4. 如有失败，修复并再次验证。

## 风险
- 首次初始化下载体积较大，耗时较长。
- CI/容器网络波动可能导致下载失败，需脚本内给出清晰错误提示。
