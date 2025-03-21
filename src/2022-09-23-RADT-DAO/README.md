# 2022年9月23日 RADT-DAO(TWN) 攻击事件分析与复现

通过对 **2022年9月23日 RADT-DAO(TWN)** 的详细分析，并使用 Foundry 工具进行复现。
请参阅详细分析文档：https://learnblockchain.cn/article/13124

## 分析总结
攻击者通过监测交易池mempool的情况，发现有一笔受害者交易可以被利用（执行相似的逻辑），于是攻击者构建了3笔gasprice更高的交易（大约900gwei，远大于受害者的15gwei），由于抢跑攻击，攻击者交易优先被矿工打包并执行。在攻击者的交易中，攻击者在交易中查询来自PancakeSwap: Router v2合约中的代币额度并授权，通过闪电贷借款大量USDT，并使用借款中的部分USDT换取TWN。此时攻击者利用接收者地址向池子中转入1 ether USDT，并利用withdraw函数从池子中取出大量的LP token，由于在TWN代币合约中fallback函数的逻辑简单，攻击者利用wrap，在取款函数中设置大量不安全转账，利用fallback将池子中的TWN代币基本全部取走，仅仅留有0.11左右的TWN，接着，攻击者调用V2合约中的swap相关函数（包含手续费）执行交换代币的逻辑，利用大额的价格差，用极少量的TWN换取池子大量的USDT代币，最后再归还闪电贷的还款，最终池子损失约94,304.58 USDT。

## 复现命令

在安装 Foundry 后，可以使用以下命令来复现该攻击事件：

```bash
forge test --contracts ./src/2022-09-23-RADT-DAO/RADT_exp.t.sol -vvv
 ```

## 注意事项
注意：使用可以进行fork的RPC