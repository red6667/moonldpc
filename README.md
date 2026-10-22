# MoonLDPC

MoonLDPC 是 MoonBit 二进制稀疏校验矩阵、GF(2) 编码、软判决译码和擦除恢复库。模块版本为 `red6667/moonldpc@0.1.0`，MIT 许可。适合接收端/仿真工具、码设计互操作工具、遥测/协议服务复用同一核心；不提供 Wi-Fi、5G、DVB 标准 profile、随机信道仿真、密码学保证或生产吞吐量承诺。

## 安装与环境

从 MoonCakes 安装精确版本：

```sh
moon add red6667/moonldpc@0.1.0
```

在消费者 `moon.pkg` 中添加 `import { "red6667/moonldpc" }`。本仓库本地使用 Moon 0.1.20260920、Moonc 0.10.14；CI 使用官方稳定工具链并记录实际版本。支持 wasm-gc、wasm、js 和 native；Windows 本地未安装 C 编译器，native 的 build/test/run 须看云端证据。

[源码与版本](https://github.com/red6667/moonldpc) · [真实 CI 记录](https://github.com/red6667/moonldpc/actions) · [MoonCakes 文档](https://mooncakes.io/docs/red6667/moonldpc)

发布是否已完成应以平台精确版本和 Release 记录为准；本地测试不等于真实云端 CI 或竞赛官方验收。

## 能力范围

- `ParityCheck`：拥有式稀疏二进制 Tanner 图，综合、码字验证、置换、direct sum、dense 互操作、Hamming(7,4) 和重复码。
- `Encoder`：受限 GF(2) RREF、秩/自由信息位置、编码/提取、综合方程特解、小码距枚举；`CosetEncoder` 支持 Hx=s 的仿射编码。另有对偶码和整体偶校验扩展。
- 三种迭代软译码：Sum-Product、Flooding Min-Sum、Layered Min-Sum。合法码字收敛不证明原始发送内容已恢复。
- BEC：队列 peeling、受限精确仿射恢复、stopping-set 诊断；精确恢复区分唯一、多解、无解。
- 小码对照：nearest_word 穷举最近码字且拒绝并列；decode_exact 输出序列 ML 和比特 MAP 后验，有严格枚举预算。
- 互操作：严格 padded alist 双向邻接校验、QC lift、四环/girth/连通分量；puncture 通过消元得到投影码，而非直接截断 H。
- 接收适配：BPSK、AWGN/BSC/BEC LLR、逐样本方差、稳定概率转换、独立观测合并、重排、shortening/puncturing 和不可变统计合并。
- JSON：analyze、encode、decode、peel、recover、bit-flip、distance、alist、exact-decode、nearest、correct-single、stopping、coset-encode。

## 最小 API 例子

下面的操作可在本仓库 [receiver](examples/receiver/main.mbt) 和 [laboratory](examples/laboratory/main.mbt) 查看完整的错误处理与可执行代码：

```moonbit
let code = @moonldpc.hamming7()
let encoder = @moonldpc.Encoder::new(code)
let word = encoder.encode([1, 0, 1, 1])
let llr = @moonldpc.awgn_llr(@moonldpc.bpsk(word), 0.5)
let decoded = code.decode(llr, @moonldpc.DecoderConfig::new(SumProduct))
let information = encoder.extract(decoded.word)
```

这些 API 可能抛出 CodeError；调用函数需要声明 raise 或显式 catch。LLR 为 log(P0/P1)，正值偏向 0，零硬判为 0。行/列索引从零开始；重复边、越界索引、非二值输入、NaN/Infinity 不是合法输入。

## 四个可运行工作流

```sh
moon run examples/receiver
moon run examples/designer
moon run examples/telemetry
moon run examples/laboratory
```

1. **接收端/仿真开发者**：矩阵和解调 LLR → 三种迭代译码 → 候选码字、综合历史、后验和误码统计。receiver 实跑自定义 42-bit QC 帧。
2. **码设计工具作者**：QC base matrix → lift、alist 导出/导入 → 邻接、环、秩、小码距和投影结果，供其他工具链接入。
3. **遥测服务作者**：重复/穿孔观测和 BEC 擦除 → RatePlan、peeling/精确恢复 → 结构化唯一/多解/错误结果。
4. **接收校准与诊断工具**：扩展 Hamming 码、重排观测和逐样本方差 → 对齐 LLR → 精确 ML/MAP 对照与比特概率。

## JSON CLI

```sh
moon run cmd/main -- '{"action":"analyze","code":{"variables":3,"rows":[[0,1],[1,2]]}}'
moon run cmd/main -- '{"action":"exact-decode","code":{"variables":3,"rows":[[0,1],[1,2]]},"llr":[-2,0.1,-2]}'
```

PowerShell 的原生命令引号转义可能不同；可运行 `python scripts/smoke.py`，它通过真实子进程传递 JSON，并检查成功和失败请求。协议拒绝未知字段、重复键和过深 JSON。**CLI 将协议错误作为 ok:false 数据返回，进程退出零不是译码成功证明。**

## 关键边界

- 稀疏图最多 65,536 个变量/校验与 1,000,000 条边；稠密消元另限尺寸、单元数和工作量。详见 [安全边界](SECURITY.md)。
- 精确小码译码长度不超过 256、维度不超过 16，且 n*(k+1)*2^k <= 20,000,000。不是大图生产译码器。
- `correct_single` 只在单错误假设下返回唯一列匹配；多错误可能形成另一个合法码字。最近码字并列不猜，精确软译码并列按信息掩码顺序选首项并报告 ties。
- `recover_erasures` 的 particular_word 不证明唯一；检查 unique、ambiguity_dimension。`peel` 不猜 stopping set。
- `RatePlan` 只合并独立观测；相关观测重复使用会导致过度置信。有限 LLR shortening 必须在译码后用 accepts 检查；BEC 重复观测冲突会报错。
- 不声称兼容某个无线标准、通过第三方认证、比某个实现更快或项目绝对唯一。

## 验证

```sh
moon info && moon fmt
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon build --deny-warn
python scripts/generate_oracles.py --check
python scripts/test_audit_history.py
python scripts/audit_local.py
python scripts/audit_history.py
python scripts/smoke.py --target wasm-gc
```

当前 36 个 MoonBit 测试；独立 Python fixture 有 144 个迭代译码案例、40 个 GF(2) 案例、20 个精确边缘案例。新增测试穷举 Hamming 单错误、双对偶、仿射综合、置换和 stopping sets，并独立核对概率乘积枚举与 log-domain 后验。CI 对 wasm-gc、wasm、js、native 分别执行检查、测试、构建和真实工作流。工程 ledger 记录 20 个已逐项复核的真实切片，不将后续格式/修复提交自动计入门槛。

[架构与数值约定](docs/architecture.md) · [查重范围和近邻](docs/competition/duplicate-check.md) · [提交审计 ledger](docs/competition/engineering-slices.json) · [变更记录](CHANGELOG.md)

## 许可与参考

原创实现，未复制近邻项目代码或测试夹具。MoonBit core 依赖与参考边界见 [NOTICE](NOTICE)，许可见 [MIT LICENSE](LICENSE)，AI 辅助开发披露见 [AI-USE.md](AI-USE.md)。本库没有网络发布或报名功能；私有申报材料不属于源码/包。
