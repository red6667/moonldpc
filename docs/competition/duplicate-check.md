# MoonLDPC 语义查重与选题记录

日期：2026-10-21。范围：MoonBit/MoonCakes 公开模块与公开 GitHub 搜索；目的不是证明“绝对没有同类”，而是记录为什么本项目的能力边界与已知近邻不同。

## 需求与成熟基线

LDPC 开发者、编码仿真开发者和需要处理稀疏二进制约束的工具作者，都需要把校验矩阵、编码、软信息、擦除和互操作格式接成可测试的链路。跨生态公开资料中的 belief-propagation / min-sum Tanner 图译码和 padded alist 是行为基线；成熟公开说明用于核对 LLR 符号、校验节点更新、收敛含义和格式边界。本项目没有声称符合任一无线标准 profile。

候选题目采用“真实输入—处理—可复用结果”的门槛：至少三类用户（接收端/仿真、码设计/互操作、遥测/协议接入），分别可以使用 API、alist/QC 工作流或 JSON 协议完成闭环。它不是把现有包改名，也不是只做一个单一矩阵 demo。

## 已检查候选

| 候选 | 公开邻近实现或结果 | 决定 | 边界理由 |
|---|---|---|---|
| VCD | `lqhy1234567/moonbit-vcd@0.3.1`；另有 `alicedhaha/minivcd_mbt@0.1.6` | 拒绝 | 已有直接成熟邻近模块，重复风险高 |
| 采样率转换 | `yzy726/MoonSRC@0.1.0`（包页 owner 显示为 Ag108） | 拒绝 | 已有直接信号处理实现 |
| FITS | `cosettese/moonastrofits@0.1.0` | 拒绝 | 已有文件格式领域实现 |
| 稳定匹配 | `shencangsheng513/moonmatch@0.1.0` | 拒绝 | 已含 DA、HR、TTC 等匹配流程 |
| Cubature | MoonCakes/ GitHub 关键词未见直接 LDPC 同类；quadrature 结果为 `symbit`、`moonNum`、`moonbit-relief` 等 | 保留观察 | 需求和复用链路不如稀疏编码明确，未选 |
| LDPC/稀疏校验/置信传播 | MoonCakes 关键词结果没有直接二进制 LDPC 模块；匿名 GitHub `ldpc language:MoonBit`、`"low-density" MoonBit`、`"Tanner" language:MoonBit`、`"belief propagation" language:MoonBit` 均返回 `total_count=0` 且 `incomplete_results=false` | 选择 | 不是“生态没有所以必然原创”；是当前检索下未发现直接语义替代，同时跨生态已有成熟行为基线可验收 |

## 查询边界和限制

通过匿名 `moon search` 检查了 `ldpc`、`low-density`、`parity`、`tanner`、`min-sum`、`belief propagation`、`channel coding`、`sum-product`、`erasure`、`hamming`、`bch`、`turbo`、`polar` 等关键词；成功结果使用 `--limit 100`。MoonCakes 搜索在 `--limit 150` 时返回 HTTP 422，不能把失败响应当作零命中；`integration` 与 `matching` 结果触及 100 条上限，因此只作为邻域信号，不据此断言总量。匿名 GitHub API 后续触发 rate limit，未换号、未登录。

已匿名下载并检查的相邻发布包包括 MoonSRC、reed_solomon、moonastrofits、dsp、moonbit-vcd、moonerasure、moonmatch；只做包清单、接口和关键词边界检查，没有运行或复制其源码。特别是 `moonerasure` 是 GF(256) 存储/擦除方向，不能等同于本项目的二进制软判决 Tanner 图译码。

公开行为基线页面保存于本地研究临时目录并仅用于人工核对：Roffe 的 LDPC BP decoding example 与 MacKay 的 ITILA 页面。它们是公开文档参考，不是 MoonLDPC 的源码依赖。研究临时目录不属于本仓库交付物。

## 最终差异和待验证项

MoonLDPC 的组合差异是：拥有式稀疏矩阵不变量 + 受限 GF(2) 编码/综合 + 三种软译码 + BEC peeling 与精确仿射恢复 + alist/QC + rate matching + 严格 JSON 协议。每项都有本地测试和资源边界，但尚未有真实第三方用户访谈、公开仓库 issue 反馈、标准 profile 互操作认证或云端 CI 证据。因此本文件只支持“当前本地查重后选择该方向”，不支持“官方唯一”或“已获初审”。


## 2026-10-22 发布前复查

本轮重新执行已安装 `osc2026-guide` 的 Project Research Guide，并扫描完整本地 registry（读取时 749,784 字符、177 个二级分段），不是只比较项目名。MoonLDPC 自身预留不视为他人撞题；重点复读 MoonRecoder、Reed-Solomon 和本项目完整能力指纹。

### 检索与反向检索

MoonCakes 每次使用 `moon search --limit 100 --json`。查询包括 ldpc、low-density、tanner、belief propagation、min-sum、sum-product、channel coding、parity、erasure、hamming、bch、polar、error correction、纠错、alist、qc-ldpc、fec、reed solomon、recoder、bit flip、AWGN，以及 parity-check、minsum、软判决、校验矩阵、SumProduct、decode_llr、LDPC decoder、置信传播。核心 ldpc / belief propagation / bch / qc-ldpc / decode_llr / 软判决 / 置信传播 等未返回模块；宽泛 error correction 命中 100 条上限，不能称为穷尽。

GitHub 16 组 repository 搜索均成功返回 `incomplete_results=false`，每页上限 100：LDPC、low-density、Tanner、belief propagation、min-sum、error correcting、moonldpc、sparse parity，以及 README 反向搜索、parity-check、alist、SumProduct、hackathon ldpc 和中文纠错。LDPC 的 README 搜索命中 `Across2005/yimai-prophecy-moonbit`：实际 README 的 LDPC 仅为预测记忆引擎的测试语料；min-sum README 命中 `amistozy/arturo` 编程语言解释器；中文纠错命中 `qjgqjg/MoonRules` 中文写作检查器。已查看这些 README 和源文件树，均非信道译码实现。官方 awesome-moonbit README 也重新获取并检查。查询计数和版本清单见 [复查证据摘要](duplication-refresh-2026-10-22.json)。

### 能力对照与源码证据

| 近邻（本轮公开最新版本） | 实际核对材料 | 重合与区别 | 决定 |
|---|---|---|---|
| [MoonErasure](https://github.com/oyjh0381/MoonErasure) `oyjh0381/moonerasure@0.2.0` | MoonCakes 元数据/文档；codec.mbt、codec_test.mbt、pkg.generated.mbti | GF(256) 固定编号字节分片的系统式 Reed-Solomon 恢复；不是任意二进制 H + LLR + BP/min-sum | 相邻，非直接替代 |
| [reed_solomon](https://github.com/CAIMEOX/reed_solomon) `CAIMEOX/reed_solomon@0.1.0` | MoonCakes 文档/元数据；src/decoder.mbt、src/test_rs.mbt | 有限域多项式综合、定位和纠错，不同于 Tanner 图软译码；build_status=legacy，不能据此推断维护成熟度 | 相邻，非直接替代 |
| [MoonRecoder](https://github.com/ZJH-666-ZJH/moonrecoder) `ZJH-666-ZJH/moonrecoder@0.1.1` | 最新元数据、README、源树、decoder.mbt、decoder_wbtest.mbt、公开接口 | GF(256) 任意方程入库、秩创新反馈、不完整中继重编码，不是软比特观测迭代译码 | 相邻，保留其独立工作流 |
| [moonbit-shard-note](https://github.com/JJ-ai-nb/moonbit-shard-note) `JJ-ai-nb/moonbit-shard-note@0.2.1` | 最新文档/元数据、README、resilient.mbt、resilient_test.mbt、公开接口 | 纸质短消息卡片、校验和、GF(256) 多校验分片；没有 LLR/BP/alist/QC 输入输出语义 | 新增近邻，非直接替代 |
| [moonbit-radioframe](https://github.com/lxyhgvb/moonbit-radioframe) `lxyhgvb/moonbit-radioframe@0.2.0` | 最新文档/元数据、README、源树、src/phy/modulation.mbt、src/channel/simulator.mbt、channel_test.mbt、phy 接口 | 无线帧、DSSS 芯片序列最近匹配、丢包/抖动/碰撞仿真，不是任意稀疏 H 的软译码 | 新增近邻，可互补 |
| [dsp](https://github.com/hwlxmm/moonbit-dsp) `hwlxmm/dsp@0.1.0` | 最新文档/元数据、README、源树、telecom_dsp 全部 4 个源码/接口/测试文件 | QPSK 调制/硬判决、CostasLoop、EVM；被检查 API 无 LDPC/校验矩阵/LLR 迭代译码 | 前端互补，非直接替代 |

### 独立实现必要性与判定

MoonLDPC 的核心状态是稀疏二进制 H、变量/校验边消息、LLR 后验和综合收敛历史；GF(2) 精确恢复/编码是配套能力，不把“分片丢失恢复”重新包装成主线。把这一核心塞进固定 GF(256) 分片库、中继重编码器或无线帧工具，会改变其主要输入、状态和结果契约；独立包可被这些宿主按需集成，比复制或强行扩展既有分片 API 更合适。

**判定：在本轮实际可访问、已检查范围内未发现成熟直接替代，未触发用户的撞题暂停条件。** 不证明生态绝对唯一，也不代表赛事组查重裁决。未搜索私有仓库，仓库搜索不等于 GitHub 全文代码搜索，100 条上限和索引延迟仍存在。没有运行近邻测试，也没有复制其代码/数据。
