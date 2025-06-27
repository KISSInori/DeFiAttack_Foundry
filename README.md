# 对web3攻击进行分析与使用foundry复现

## 环境安装

在进行复现之前，您需要先安装Foundry。以下是安装步骤：

### 安装 Foundry

1. 打开终端执行以下命令：
    ```bash
    curl -L https://foundry.paradigm.xyz | bash
    ```

2. 添加 Foundry 到系统 PATH 中：
    ```bash
    export PATH="$HOME/.foundry/bin:$PATH"
    ```

3. 完成安装，验证是否安装成功：
    ```bash
    forge --version
    ```

## 使用Foundry对具体的安全事件进行分析

### 2024年10月10日 HYDT 攻击事件分析与复现

快速构建：https://github.com/KISSInori/DeFiAttack_Foundry/tree/main/src/2024-10-10-HYDT

请参阅详细分析文档：https://learnblockchain.cn/article/13124


### 2022年9月23日 RADT-DAO(TWN) 攻击事件分析与复现
快速构建：https://github.com/KISSInori/DeFiAttack_Foundry/tree/main/src/2022-09-23-RADT-DAO

请参阅详细分析文档：https://learnblockchain.cn/article/13161


### 2023年4月5日 Sentiment 攻击事件分析与复现
快速构建：https://github.com/KISSInori/DeFiAttack_Foundry/tree/main/src/2023-04-05-Sentiment

请参阅详细分析文档：https://learnblockchain.cn/article/17471