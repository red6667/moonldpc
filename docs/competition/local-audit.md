# 发布候选本地审计

日期：2026-10-22。此记录形成于首次远程写入之前，不是平台已完成的声明。

- GitHub 与 MoonCakes 均由隔离 helper 在服务端核验为 red6667。共享本机凭据未改写，选中 Moon 凭据受 DPAPI 保护。
- 原有无提交实现只有一个真实基线提交；随后完成独立工程改进。engineering-slices.json 记录已复核的 20 个非空切片；audit_history.py 复算可达性、身份、非 merge、用途和验证说明，不把 raw count 当有意义证明。
- moon info/fmt/check/test 对每个切片执行。现有 36 个 MoonBit 测试、144 个迭代 oracle、40 个 GF(2) oracle、20 个边缘 oracle；新增四个实际下游示例。
- 生产 .mbt 的文件清单和去空行/纯注释行数由 scripts/audit_local.py 动态复算；测试、示例、CLI glue 不计入。
- 便携目标本地复测；native 仅能本地 check，本机无 C compiler。云端 native 构建、测试和运行必须由真实 CI 证明。
- 完整查重矩阵见 duplicate-check.md；本轮 supplementary refresh 及 registry 摘要保存在 release-search-refresh.json。没有私有仓库/全文索引穷尽保证，没有复制近邻源码或夹具。
- 私有申报书在仓库外；working tree 和 reachable history 隐私检查须在首次 push 和后续 release push 前执行。

远程交付须另外核验：公开默认分支 SHA、四目标真实 CI、同 SHA 的 tag/Release、MoonCakes 精确版本/包内容、新隔离无凭据消费者安装检查和运行。本地命令不能替代这些证据，最终平台状态以实际链接和仓库外交付记录为准。
