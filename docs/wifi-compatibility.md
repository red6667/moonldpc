# IEEE 802.11 LDPC 兼容性：范围、对比和复跑

本地修订日期：2026-10-26。目的：补足“只有基础算法，缺少典型通信标准的明确对比与测试”的缺口。原始 0.1.0 基线仅有自定义 QC 与小码；以下 API、向量和测试属于未发布修订，不应拿旧 Release/CI 充当本次验证结果。

## 明确支持的对象

| 项目 | 本次范围 |
| --- | --- |
| 配置 | IEEE 802.11 LDPC，码长 n=1944，码率 3/4 |
| 信息/校验 | k=1458，486 个校验位，6×24 base matrix，z=81 |
| 位序 | 前 1458 位为原始信息，后 486 位为校验；字节按 MSB first 展开 |
| QC 定义 | base[r][c]=s≥0 时，展开行 r*z+t 连接 c*z+(t+s)%z；-1 表示零块 |
| 编码 | `WifiLdpc1944R34::encode`；利用固定稀疏阶梯结构求校验位，完整综合复核 |
| 提取 | `extract` 验证长度、二值和综合，再提取前 k 位 |
| 译码 | 既有 SumProduct、MinSum、LayeredMinSum，LLR=log(P0/P1) |

通用 `Encoder` 按 GF(2) 消元后的自由列放信息，不能直接假定其输出是这个标准的系统位序。新增 API 显式固定标准位序，原有通用 API 保持兼容。

## 对照对象与来源

1. [ishmal/ldpc802-js](https://github.com/ishmal/ldpc802-js/tree/e4a0042a2e0884304ba306163d7df00c291667f1)，固定 revision `e4a0042a2e0884304ba306163d7df00c291667f1`：`src/ldpc802.11.js` 提供 base matrix；`src/ldpcEncoder.js`、`src/codetable.js`、`src/util.js` 运行外部编码；`test/testdata.js` 的数值数组转录 IEEE 802.11-2016 Annex G Tables G.36–G.38。
2. [tavildar/LDPC](https://github.com/tavildar/LDPC/blob/05ee7f4af36ed5dacf52861315af68b8a17e71e0/LdpcC/WiFiLDPC.h)，固定 revision `05ee7f4af36ed5dacf52861315af68b8a17e71e0`：`H_1944_3_4[6][24]` 与前一个来源的 144 个 base 元素逐项一致。没有编译运行此 C++ 项目，不宣称其译码器参与了对照。

原 IEEE 出版物未独立获取，因此本项目将附录样本准确称为“固定版本开源实现中的标准附录转录”，不称为直接从官方原文独立校订。两个来源均有 MIT 许可，完整许可在 `docs/licenses/`。只收录必要数值，不复制上游测试文件的文本内容。每个源文件的路径、revision、SHA-256 在 `tests/fixtures/wifi1944-r34.json`，可防止上游变动悄悄改变预期。

## 测试比较什么

| 证据 | 输入和独立预期 | 通过条件 |
| --- | --- | --- |
| 标准矩阵 | 两个固定上游的 6×24 matrix | 144 个元素相同，MoonBit 展开后 486 行邻接全部相同 |
| 附录非零样本 | G.36 的 1458 位输入与 G.37 的 1944 位码字 | 输出每一位相同，信息位置相同，Hc=0 |
| 另外六组 | 全零、全一、交替、首单比特、尾单比特、stride-17；外部 JS 编码器生成 | 7 组输入及全部 13,608 个码字位逐一比较 |
| 独立代数 | Python 位压缩 GF(2) 消元求解 486×486 校验子矩阵 | 不使用 MoonBit 稀疏阶梯公式，7 组全码字相同 |
| 附录速率选择 | 816 位有效信息、642 个 shortening 零位、54 个尾部 parity puncture | 1248 位输出与 G.38 转录逐位相同；恢复 LLR 后三种译码算法均恢复原 1944 位及 1458 位信息 |
| 真实迭代路径 | 确定性非零信息，6 个指定位置将强正确 LLR 变为弱错误 LLR | 初始硬判有 6 位错误；三种算法均执行至少一次迭代并恢复原码字和信息 |
| 失败反例 | 错长、非二值、损坏 parity、字节内反序、不同合法码字、零迭代 | 错误被拒绝；合法码字不自动等于原信息；零迭代不冒报恢复成功 |

附录速率选择的零基索引：保留完整码字 `[0,816)` 和 `[1458,1890)`；`[816,1458)` 是 642 个已知零位，`[1890,1944)` 是 54 个穿孔位。183 字节的输入展开有 6 个填充位，只取前 1458 位。`RatePlan.restore_llr` 恢复观测后，还检查 `accepts` 的 shortening 约束。

上游 JS 与本项目比较的是编码码字和矩阵，未进行逐次软后验或译码速度的跨实现比较。弱错误测试是确定性功能回归，不是随机信道 BER/FER 曲线，也不能推导所有噪声条件下都能纠正 6 位错误。

## 复跑

在包含本地修订的仓库运行，建议 Moon 0.1.20261021 / Moonc 0.10.17：

```sh
python scripts/check_wifi.py
moon test --target wasm-gc --deny-warn
moon test --target wasm --deny-warn
moon test --target js --deny-warn
moon run examples/wifi
python scripts/smoke.py --target wasm-gc
```

第一条只用 Python 标准库，离线重新解矩阵并核对 7 组 JSON 与 MoonBit 内嵌向量；`moon test` 才实际执行 MoonBit 实现。CI 已新增离线校验步骤。

可选的完整上游重放：从上面固定 revision 下载 fixture `sources` 中各文件，按照 `local_file` 命名存入一个目录，然后运行：

```sh
python scripts/check_wifi.py --reference-dir /absolute/path/to/reference-files
```

这条命令先核对所有源文件散列、再比较第二来源矩阵，最后调用 Node 执行 `scripts/wifi_reference.cjs`，用第一个上游编码器重新生成全部预期。适配器只移除 ES import/export 声明并加载依赖，不修改算法。

## 结论的边界

本次只证明上述一个 FEC profile 及列出的逐位/恢复用例。未覆盖全部 12 种 Wi-Fi LDPC 配置，没有完整 PHY、扰码/交织/调制链路、射频设备互通、5G NR/DVB 配置或官方认证。原有 JSON CLI 仍操作通用矩阵；固定 profile 使用 MoonBit API 和独立示例。Windows 本机无 C 编译器，本次 native 仅作静态检查；旧版本的云端结果不能替代本次执行。修订是否已公开应查看修订后的精确提交与包版本，不能由本地测试推定。
