# SSH 授权后 push 与 PR 执行计划

## 背景
用户已为提供的 SSH 公钥授予仓库权限，要求继续完成 push 与 PR。

## 目标
1. 配置远程仓库地址。
2. 推送当前 `work` 分支到远程。
3. 创建 PR 记录并反馈结果。

## 步骤
1. 检查 `git remote -v` 与当前分支。
2. 添加 `origin` 指向 `git@github.com:crazygo/starling.git`（若不存在）。
3. 执行 `git push -u origin work`。
4. 使用计划内容创建 PR 消息并回传。
