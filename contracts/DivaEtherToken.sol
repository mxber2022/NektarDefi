// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          LIBRARIES                         */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
import {IDivaEtherTokenErrors, IDivaEtherTokenEvents} from "./interfaces/IDivaEtherToken.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {INITIAL_SUPPLY} from "./libraries/Constants.sol";

/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
/// @author 0x4non, Nico & Nando Builded to use in Diva
contract DivaEtherToken is ERC20, Ownable, IDivaEtherTokenErrors, IDivaEtherTokenEvents {
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Provides the token name.
    /// @return The name of the token.
    function name() public pure override returns (string memory) {
        return "Diva Ether Token";
    }

    /// @notice Provides the token symbol.
    /// @return The symbol of the token.
    function symbol() public pure override returns (string memory) {
        return "divETH";
    }

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    // @dev value virtually imposible to overflow
    uint128 public totalShares;
    // @dev this contract will keep ether accounting using this variable
    uint128 public totalEther;

    mapping(address user => uint256 shares) public sharesOf;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _accountingManager The address of the Accounting Manager.
    constructor(address _accountingManager) payable {
        /// @dev _accountingManager owns this contract, so he can withdraw ether and burnShares
        _initializeOwner(_accountingManager);

        if (msg.value != INITIAL_SUPPLY) revert ErrMinDepositAmount();
        // mint and lock forever in address(1) 1000 shares

        // use address 1 to avoid issues for the client
        // a transfer from address(0) to address(0) might be confusing
        sharesOf[address(1)] = msg.value;
        totalShares = uint128(msg.value);
        totalEther = uint128(msg.value);
        _emitTransferEvents(address(0), address(1), msg.value, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the balance of the given user in divETH base on how many shares owns.
    /// @param user The address of the user.
    /// @return The balance of the user.
    function balanceOf(address user) public view override returns (uint256) {
        return convertToAssets(sharesOf[user]);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        // @notice user can try to send a amount but due to rounding error send less
        //         if amount > 0 and convertToShares(amount) = 0 then we have a rounding error
        uint256 shares = convertToShares(amount);
        sharesOf[from] -= shares;

        // User can try to send a amount but due to rounding error need 0 shares
        // this is an idea, but probably is better to recommend defi protocol to only use WDIVA to avoid issues
        // if (shares == 0 && amount > 0) revert ZeroAmount();

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            sharesOf[to] += shares;
        }

        _emitTransferEvents(from, to, amount, shares);
    }

    /// @notice Transfers a specified amount of divETH from the caller's account to another account.
    /// @param to The recipient address.
    /// @param amount The amount of divETH to transfer.
    /// @return True if the transfer is successful.
    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);

        return true;
    }

    /// @notice Transfers a specified amount of divETH from one account to another, using allowance mechanism.
    /// @param from The address to transfer divETH from.
    /// @param to The recipient address.
    /// @param amount The amount of divETH to transfer.
    /// @return True if the transfer is successful.
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);

        _transfer(from, to, amount);

        return true;
    }

    /// @notice Transfers shares from the caller's account to another account.
    /// @param to The recipient address.
    /// @param shares The number of shares to transfer.
    function transferShares(address to, uint256 shares) external returns (uint256 assets) {
        sharesOf[msg.sender] -= shares;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            sharesOf[to] += shares;
        }

        assets = convertToAssets(shares);

        _emitTransferEvents(msg.sender, to, assets, shares);
    }

    /// @notice Transfers shares from one account to another, using allowance mechanism.
    /// @param from The address to transfer shares from.
    /// @param to The recipient address.
    /// @param shares The number of shares to transfer.
    function transferSharesFrom(address from, address to, uint256 shares) external returns (uint256 amount) {
        amount = convertToAssets(shares);
        if (amount == 0 && shares > 0) revert ErrZeroAmount();

        _spendAllowance(from, msg.sender, amount);

        sharesOf[from] -= shares;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            sharesOf[to] += shares;
        }

        _emitTransferEvents(from, to, amount, shares);
    }

    /*//////////////////////////////////////////////////////////////
                        MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Receives ETH and deposits it for the sender.
    receive() external payable {
        depositFor(msg.sender);
    }

    /// @notice Deposits ETH for the sender.
    /// @return shares The number of shares minted for the deposited ETH.
    function deposit() public payable returns (uint256 shares) {
        return depositFor(msg.sender);
    }

    /// @notice Deposits ETH for a specific user and credits them with shares.
    /// @dev AccountingManager will withdraw later the ether and use it to add validators
    /// @param user The address of the user for whom to deposit.
    /// @return shares The number of shares minted for the deposited ETH.
    function depositFor(address user) public payable returns (uint256 shares) {
        if (msg.value == 0) revert ErrZeroDeposit();

        uint128 _totalShares = totalShares;
        uint128 _totalEther = totalEther;

        /// @dev Equivalent to convertToShares(uint256 assets), but cheaper.
        shares = msg.value.mulDiv(_totalShares, _totalEther);

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            sharesOf[user] += shares;
            // Assume that shares is less than 2^128. And totalShares will never be greater than 2^128.
            totalShares = _totalShares + uint128(shares);
            // Assume that msg.value is less than 2^128. And totalEther will never be greater than 2^128.
            totalEther = _totalEther + uint128(msg.value);
        }

        _emitTransferEvents(address(0), user, msg.value, shares);
    }

    /// @notice Burns the given amount of shares and returns the corresponding amount of ETH.
    /// @param shares The amount of shares to burn.
    /// @return burnedInETH The amount of ETH burned.
    function burnShares(uint256 shares) external returns (uint256) {
        return _burnShares(msg.sender, shares);
    }

    /// @dev Internal function to burn shares and handle the internal accounting.
    /// @param user The user whose shares are being burned.
    /// @param shares The amount of shares to burn.
    /// @return burnedInETH The amount of ETH burned.
    function _burnShares(address user, uint256 shares) internal returns (uint256 burnedInETH) {
        uint128 _totalShares = totalShares;
        uint128 _totalEther = totalEther;

        // @dev next line is equivalent to `burnedInETH = convertToAssets(shares);`
        burnedInETH = shares.mulDiv(_totalEther, _totalShares);

        sharesOf[user] -= shares;
        unchecked {
            // cant overflow because totalShares is bigger than shares
            totalShares = _totalShares - uint128(shares);
        }

        _emitTransferEvents(user, address(0), burnedInETH, shares);

        // @dev the protocol has lost ether via a slash event to a user
        totalEther = _totalEther - uint128(burnedInETH);
    }

    /*//////////////////////////////////////////////////////////////
                              DIVA 
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the owner (AccountingManager) to withdraw any ETH held in the contract.
    function withdrawEther() external onlyOwner {
        SafeTransferLib.safeTransferETH(msg.sender, address(this).balance);
    }

    /// @notice Adjusts the total ether count to account for external changes like slashing or rewards.
    /// @param postTotalEther The amount to adjust the total ether by.
    function rebase(
        uint256 reportTimestamp,
        uint256 timeElapsed,
        uint256 postTotalEther,
        uint256 sharesMintedAsFees
    ) external onlyOwner {
        uint256 preTotalEther = totalSupply();

        // @dev the protocol has win ether via rewards or loose via slash event
        totalEther = uint128(postTotalEther);

        emit TokenRebased(
            reportTimestamp,
            timeElapsed,
            totalShares - sharesMintedAsFees,
            preTotalEther,
            totalShares,
            totalEther,
            sharesMintedAsFees
        );
    }

    /// @notice Allows the owner to mint a specific amount of shares from a user's account. Useful for operator rewards distribution.
    /// @param user The user to whom shares are minted. The user is the rewards receiver.
    /// @param shares The amount of shares to mint.
    function mintShares(address user, uint256 shares) external onlyOwner {
        unchecked {
            sharesOf[user] += shares;
            totalShares += uint128(shares);
        }

        _emitTransferEvents(address(0), user, shares.mulDiv(totalEther, totalShares), shares);
    }

    /// @notice Provides the total supply of divETH.
    /// @return The total supply of divETH in ETH.
    function totalSupply() public view override returns (uint256) {
        return totalEther;
    }

    /// @notice Converts an amount of divETH into the corresponding amount of shares.
    /// @param assets The amount of divETH to convert.
    /// @return The equivalent amount of shares.
    function convertToShares(uint256 assets) public view returns (uint256) {
        /// @dev Assumption: totalEther can not be 0 because we lock shares/ether on address(1)
        return assets.mulDiv(totalShares, totalEther);
    }

    /// @notice Converts an amount of shares into the corresponding amount of divETH.
    /// @param shares The amount of shares to convert.
    /// @return The equivalent amount of divETH.
    function convertToAssets(uint256 shares) public view returns (uint256) {
        /// @dev Assumption: totalShares can not be 0 because we mint shares to address(1)
        /// @dev Equivalent to (shares * totalEther) / totalShares rounded down.
        return shares.mulDiv(totalEther, totalShares);
        // [shares] * [total ETH] / [total shares]
    }

    /// @notice Emit Transfer and TransferShares events.
    /// @dev Emits {Transfer} and {TransferShares} events
    /// @param _from The sender address.
    /// @param _to The recipient address.
    /// @param _tokenAmount The amount of divETH transferred.
    /// @param _sharesAmount The amount of shares transferred.
    function _emitTransferEvents(address _from, address _to, uint256 _tokenAmount, uint256 _sharesAmount) internal {
        emit Transfer(_from, _to, _tokenAmount);
        emit TransferShares(_from, _to, _sharesAmount);
    }
}