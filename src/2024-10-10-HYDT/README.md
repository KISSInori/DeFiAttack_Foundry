# 2024年10月10日 HYDT 攻击事件分析与复现

通过对 **2024年10月10日 HYDT 攻击事件** 的详细分析，并使用 Foundry 工具进行复现。
请参阅详细分析文档：https://learnblockchain.cn/article/13124

## 分析总结
攻击者利用闪电贷进行借款，在借款后通过swap功能改变代币对的数量比，通过操纵预言机（链上代币对的价格），让InitialMintV2合约中的initialMint 函数根据 WBNB/USDT 对的现货价格计算 HYDT 代币数量并铸造了更多HYDT代币，最后通过swap将HYDT转换为USDT获利，最终获利5.8k 美元。攻击的根本原因在于 initialMint() 中发生了价格操纵。InitialMintV2 合约中的 initialMint() 函数执行了一系列的代币交换操作

## 复现命令

在安装 Foundry 后，可以使用以下命令来复现该攻击事件：

```bash
forge test --contracts ./src/2024-10-10-HYDT/HYDT_exp.t.sol -vvv --evm-version cancun
 ```

## 注意事项
注意：使用可以进行fork的RPC