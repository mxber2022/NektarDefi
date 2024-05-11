// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IErrors} from "./IErrors.sol";
import {IERC20Permit} from "./IERC20Permit.sol";

interface IDivaEtherTokenErrors is IErrors {
    error ErrZeroDeposit();
    error ErrZeroAmount();
    error ErrMinDepositAmount();
}

interface IDivaEtherTokenEvents {
    // Emits when token rebased (total supply and/or total shares were changed)
    event TokenRebased(
        uint256 indexed reportTimestamp,
        uint256 timeElapsed,
        uint256 preTotalShares,
        uint256 preTotalEther,
        uint256 postTotalShares,
        uint256 postTotalEther,
        uint256 sharesMintedAsFees
    );

    /**
     * @notice An executed shares transfer from `sender` to `recipient`.
     *
     * @dev emitted in pair with an ERC20-defined `Transfer` event.
     */
    event TransferShares(address indexed from, address indexed to, uint256 sharesValue);
}

interface IDivaEtherToken is IDivaEtherTokenErrors, IDivaEtherTokenEvents, IERC20Permit {
    receive() external payable;

    function DOMAIN_SEPARATOR() external view returns (bytes32 result);

    function allowance(address owner, address spender) external view returns (uint256 result);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address user) external view returns (uint256);

    function burnShares(uint256 shares) external returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

    function decimals() external view returns (uint8);

    function deposit() external payable returns (uint256 shares);

    function depositFor(address user) external payable returns (uint256 shares);

    function mintShares(address user, uint256 shares) external;

    function name() external pure returns (string memory);

    function nonces(address owner) external view returns (uint256 result);

    function rebase(
        uint256 reportTimestamp,
        uint256 timeElapsed,
        uint256 postTotalEther,
        uint256 sharesMintedAsFees
    ) external;

    function sharesOf(address user) external view returns (uint256 shares);

    function symbol() external pure returns (string memory);

    function totalEther() external view returns (uint128);

    function totalShares() external view returns (uint128);

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function transferOwnership(address newOwner) external payable;

    function transferShares(address to, uint256 shares) external returns (uint256 assets);

    function transferSharesFrom(address from, address to, uint256 shares) external returns (uint256 amount);

    function withdrawEther() external;
}