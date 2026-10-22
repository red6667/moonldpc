# MoonLDPC

MoonLDPC 是一个本地开发中的 MoonBit 二进制稀疏校验矩阵工具库，面向需要在 MoonBit 项目中建立“矩阵—编码—软判决译码—擦除恢复—协议接入”闭环的开发者。当前待发布模块为 `red6667/moonldpc@0.1.0`，GitHub 身份已验证为 `red6667`；尚无公开仓库、MoonCakes 发布或云端 CI 结果。

> 状态：本地验收候选。代码、测试、示例和文档在本地维护；“已通过本地命令”不等于已发布或已通过竞赛官方验收。

## 能解决什么问题

MoonLDPC 把常被分散在脚本、矩阵代码和通信仿真中的工作收拢为明确的、带边界的 API：构造二进制 Tanner 图，验证稀疏矩阵不变量，做 GF(2) 编码，使用 Sum-Product、Flooding Min-Sum 或 Layered Min-Sum 软判决译码，处理 BEC 擦除，导入/导出 padded alist，构造 QC lift，并通过严格 JSON 协议接入工具链。

它不是 Wi-Fi、5G、DVB 或任何标准 LDPC profile 的兼容实现；不会生成随机信道样本，也不承诺某种码族的通信性能。使用者应提供自己的校验矩阵、信道 LLR 和性能实验设计。

## 已实现范围

- 不可变拥有式 `ParityCheck`：行/列邻接、综合、码字验证、置换、direct sum、重复码和 Hamming(7,4) 构造。
- `Encoder`：受限 GF(2) 消元、秩、自由信息位置、编码、信息提取、综合方程一个特解、受限精确距离枚举。
- 译码：Sum-Product（box-plus）、Flooding Min-Sum、Layered Min-Sum；迭代数、LLR、边访问预算都有上限。收敛只表示得到合法码字，不表示知道发送码字。
- 擦除：线性队列 peeling，以及受限 dense GF(2) `recover_erasures`，分别表达“局部可剥离”和“仿射空间的唯一/多解/无解”。
- 结构：四环、连通分量、精确小图 girth、精确小维度距离分布。
- 格式：严格 padded alist 双向校验；QC base matrix `-1`/shift lift。
- 信道和调度：BPSK、AWGN LLR、BSC LLR、BEC LLR、重复观测相加、shortening 校验和误码统计。
- JSON：`analyze`、`encode`、`decode`、`peel`、`recover`、`bit-flip`、`distance`、`alist`；未知字段、重复键、深度和资源边界会被拒绝。
- 线性码投影 `puncture`：通过消去被删除坐标正确导出投影码，而不是简单截断原校验矩阵。

## 三个实际工作流

1. **接收端/仿真开发者**：把解调后的 LLR 和自定义稀疏矩阵交给 `decode`，读取合法码字、迭代历史和后验 LLR，再通过 `Encoder::extract` 或 `ErrorCounts` 进入上层统计。
2. **码设计/互操作工具**：用 QC base matrix 生成图，导出 padded alist 交给别的工具，重新导入并检查邻接、四环、girth、秩和距离边界；对需要投影的坐标使用 `puncture`。
3. **遥测/协议服务**：通过 JSON 请求把矩阵、信道观测、BEC `null` 和译码配置传入；错误以 `ok:false` 数据返回，适合命令行或宿主服务检查，不要求将 MoonBit 类型暴露给协议边界。

## 本地使用

环境要求：MoonBit 工具链 `moon 0.1.20260920` 或兼容版本；本地验证使用 Windows、Moonc `0.10.14+7d59c7ec9-dev`。模块名已按本项目授权账号设置为 `red6667/moonldpc`，但尚未发布，因此现在不要运行 `moon add`。可在本仓库根目录运行：

```powershell
moon info
moon fmt
moon check --deny-warn
moon test --deny-warn
moon run examples/receiver
moon run examples/designer
moon run examples/telemetry
moon run cmd/main -- '{"action":"analyze","code":{"variables":3,"rows":[[0,1],[1,2]]}}'
```

PowerShell 中若 JSON 引号不便，可先使用三个示例，或从脚本调用 `execute`。仓库内示例通过 `import { "red6667/moonldpc" }` 使用本地包。正式安装命令和证据必须在真实发布后补充；预设 repository 元数据不代表公开仓库已经存在。

## 核心 API 约定

- LLR 为 `log(P(bit=0)/P(bit=1))`，正值偏向 0；硬判决中零按 0 处理。
- 矩阵列和行索引从 0 开始；重复边、越界索引、非二值观测和不一致的 alist 都是错误。
- `peel` 不猜测 stopping set；需要精确分析时使用 `recover_erasures`，并检查 `unique`、`ambiguity_dimension` 和 `particular_word`。
- `RatePlan` 的重复传输坐标表示独立观测，会进行 LLR 合并；punctured 坐标恢复为 0 LLR。`shortened` 是有限先验并在结果后用 `accepts` 验证，不是隐藏的硬约束。
- `execute` 始终返回 JSON 字符串；协议错误不依赖进程退出码，自动化必须检查 `ok`。

## 测试与证据

当前本地测试包含 19 个 MoonBit 测试：Hamming 全枚举、独立 Python 生成的 144 个译码案例、40 个独立 GF(2) 核心样本、20 个精确边缘案例、BEC 3^7 观测组合、puncture 投影枚举、alist/QC、JSON 错误边界和三个示例。执行 `python scripts/generate_oracles.py --check` 可检查独立 fixture 未漂移。

最近执行 `moon coverage analyze -- -f summary`：977/1136 行，约 86.0%。覆盖率不是性能指标。

本机可通过 `moon check --target native --deny-warn`，但 native build 因系统没有 `cc`、`gcc` 或 `clang` 未能运行；不可写成 native build 已通过。GitHub Actions 配置只描述未来 CI，不代表已经运行云端 CI。

## 安全、许可、参考边界

输入大小、矩阵维度、稠密消元、译码边访问和 JSON 深度均有明确上限；库不执行网络请求、不读取凭据、不生成随机数。详见 [SECURITY.md](SECURITY.md)。项目代码采用 MIT，见 [LICENSE](LICENSE)；依赖 MoonBit core 的许可见 [NOTICE](NOTICE)。算法行为参考公开 LDPC/置信传播教材和成熟实现的公开文档，但实现、测试向量和协议代码独立编写，没有复制第三方源代码或发布包。

[AI-USE.md](AI-USE.md) 记录了 AI 辅助开发边界。查重与候选比较见 [docs/competition/duplicate-check.md](docs/competition/duplicate-check.md)，本地交付审计见 [docs/competition/local-audit.md](docs/competition/local-audit.md)。

## 当前未完成事项

2026-10-22 已通过隔离 helper 验证 GitHub 登录 `red6667`。MoonCakes 同名凭据尚未导入；没有远程仓库、云端 CI、Release 或正式发布版本。既有无提交的本地成果将以真实时间建立基线，不补造历史。完整 skill 要求的至少 20 个有独立工程价值的提交仍未满足；后续只能通过实际开发积累，不能拆分现有文件凑数。发布前还须完成账号、隐私、包内容和无缓存消费者验收。
