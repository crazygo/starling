# 去除二进制差异并提供生成指引计划

## 背景
用户反馈 PR 因包含二进制 diff 无法创建，需要改为不带二进制的提交，并提供可复用 prompt 让 Agent 在本地生成二进制。

## 目标
1. 从版本库移除 `assets/bin/culture_chinese_modern.bin`，避免 PR 二进制差异。
2. 让运行时和测试在该文件缺失时可回退，不阻塞开发。
3. 给出可直接复制的 Agent prompt，用于本地生成该二进制文件。

## 步骤
1. `git rm assets/bin/culture_chinese_modern.bin`。
2. 修改数据加载逻辑：优先加载 modern bin，缺失时回退 western bin。
3. 修改相关测试：modern bin 不存在时回退读取 western bin。
4. 执行测试验证并提交。
