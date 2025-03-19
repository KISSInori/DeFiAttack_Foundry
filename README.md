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

## 2024年10月10日 HYDT 攻击事件分析与复现

本文将通过对 **2024年10月10日 HYDT 攻击事件** 的详细分析，使用 Foundry 工具进行复现。
请参阅详细分析文档：https://learnblockchain.cn/article/13124。

### 复现命令

在安装 Foundry 后，可以使用以下命令来复现该攻击事件：

```bash
forge test --contracts ./src/2024-10-10-HYDT/HYDT_exp.t.sol -vvv --evm-version cancun