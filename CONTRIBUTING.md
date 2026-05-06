# 贡献指南

## 提 Issue

- Bug：描述复现步骤、预期行为、实际行为
- 功能请求：描述场景和期望的命令行用法

## 提 PR

1. Fork 本仓库
2. 创建分支：`git checkout -b feature/your-feature`
3. 提交修改，确保脚本在 bash 下可运行
4. 推送并创建 PR，描述改动内容和动机

## 代码规范

- Bash 脚本使用 `set -euo pipefail`
- 新脚本 `source common.sh` 使用公共函数
- 配置文件使用 TOML 格式
