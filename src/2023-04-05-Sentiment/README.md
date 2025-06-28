# 2023年4月5日 Sentiment 攻击事件分析与复现

通过对 **2023年4月5日 Sentiment 攻击事件** 的详细分析，并使用 Foundry 工具进行复现。
请参阅详细分析文档：https://learnblockchain.cn/article/17471

## 分析总结
这是一次只读重入攻击，由于在sentiment 项目中，没有考虑到在和其他defi协议交互过程中的只读重入问题，导致预言机的价格被操纵。即Balancer: Vault._joinOrExit() 函数在移除流动性时，先进行了资产转移（交互）然后再更新池子中的余额从而导致被攻击者利用。于是攻击者就在sentiment项目中借入资金，并与balancer进行交互，然后在balancer的三种代币组成的等权重池子中注入并移除流动性，由于移除流动性的过程中，balancer合约先进行资产转移再更新余额，并且在转移ETH的时候采用call的转账方式触发了攻击者精心设计的fallback函数，攻击者在设计的fallback函数中进行了多次borrow操作，每次的borrow操作都需要在sentiment中进行健康检查，由于检查中使用balancer的返回的代币数量计算lp token 对应的价格，价格预言机错误的使用了未更新的余额进行价格预测，导致攻击者可以借出更多的资产，最后，将多获利的资产转入攻击者地址账户，实现获利。

## 复现命令

在安装 Foundry 后，可以使用以下命令来复现该攻击事件：

```bash
forge test --contracts ./src/2023-04-05-Sentiment/Sentiment.t.sol -vvv --evm-version cancun
 ```

## 注意事项
注意：使用可以进行fork的RPC