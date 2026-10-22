# MoonLDPC 本地交付审计

日期：2026-10-22。本文件记录本地候选状态，不替代 GitHub、MoonCakes 或竞赛官方验收。最初的 2026-10-21 阶段为无身份本地开发；用户随后授权以 red6667 完成交付。

## 已核验的本地对象

- 模块：`red6667/moonldpc@0.1.0`，尚未发布。原 `local/moonldpc` 已替换为本项目授权命名空间。
- 生产源码去掉空行和纯注释后为 1,879 行；不含测试、示例、CLI 和脚本，使用 `python scripts/audit_local.py` 复算。
- `moon check/test/build --target wasm-gc/wasm/js --deny-warn` 三个目标均通过；每个目标 19 个测试通过。`moon check --target native --deny-warn` 通过；本机没有 C 编译器，未完成 native 构建/运行。
- 独立 Python oracle 包含 144 个迭代译码样本、40 个 GF(2) 样本、20 个精确边缘样本；生成器检查通过。
- receiver、designer、telemetry 三个示例实际运行成功，分别验证自定义 QC 帧、alist/矩阵互操作、重复观测和擦除恢复。
- 覆盖报告为 977/1136（约 86.0%，包括未由测试覆盖的 CLI/示例）；这不是兼容性或性能保证。
- 查重复核见同目录 `duplicate-check.md` 和脱敏 evidence JSON：在本轮可访问的范围内未发现成熟的直接语义替代，不声称绝对唯一。

## 账号与交付门禁

- 已通过指定账号隔离 helper 验证 GitHub 登录为 red6667；项目级提交作者配置为 red6667，使用其已核对的 GitHub noreply 邮箱。未切换共享 gh 活动账号或修改全局 Git 身份。
- 2026-10-22 首次绑定前全部代码仍无提交；将现有实现作为一个真实基线提交，不拆分旧文件伪造此前的开发过程。提交数及实际 remote 数由 audit_local.py 动态报告。至少 20 个有意义工程提交的门禁尚未满足。
- 尚无项目远程仓库、真实云端 CI、tag、Release、MoonCakes 上传或新无缓存消费者验证。manifest 中 repository 是预设目标，不是已建仓证明。
- red6667 的受保护 MoonCakes 凭据缺失；没有使用其他账号凭据，等待参赛者通过本机隐藏输入导入。GitHub 授权不等于 MoonCakes 授权。
- 申报草稿保存在仓库外，未上传。没有真实公开仓库时，申报书严格检查应如实拒绝，不添加虚假地址绕过门禁。

## 可复核命令

```powershell
moon info
moon fmt
moon check --deny-warn
moon test --deny-warn
python scripts/generate_oracles.py --check
python scripts/audit_local.py
moon coverage analyze -- -f summary
moon run examples/receiver
moon run examples/designer
moon run examples/telemetry
```

只操作本项目及仓库外的交付资料；没有修改同级项目。上述本地通过记录不能作为完整交付声明。
