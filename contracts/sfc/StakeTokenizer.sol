pragma solidity ^0.5.0;

import "./SFC.sol";
import "../erc20/base/ERC20Burnable.sol";
import "../erc20/base/ERC20Mintable.sol";
import "../common/Initializable.sol";

contract Spacer {
    address private _owner;
}

contract StakeTokenizer is Spacer, Initializable {
    SFC internal sfc;

    mapping(address => mapping(uint256 => uint256)) public outstandingSMTC;

    address public sMTCTokenAddress;

    function initialize(address _sfc, address _sMTCTokenAddress) public initializer {
        sfc = SFC(_sfc);
        sMTCTokenAddress = _sMTCTokenAddress;
    }

    function mintSMTC(uint256 toValidatorID) external {
        address delegator = msg.sender;
        uint256 lockedStake = sfc.getLockedStake(delegator, toValidatorID);
        require(lockedStake > 0, "delegation isn't locked up");
        require(lockedStake > outstandingSMTC[delegator][toValidatorID], "sMTC is already minted");

        uint256 diff = lockedStake - outstandingSMTC[delegator][toValidatorID];
        outstandingSMTC[delegator][toValidatorID] = lockedStake;

        // It's important that we mint after updating outstandingSMTC (protection against Re-Entrancy)
        require(ERC20Mintable(sMTCTokenAddress).mint(delegator, diff), "failed to mint sMTC");
    }

    function redeemSMTC(uint256 validatorID, uint256 amount) external {
        require(outstandingSMTC[msg.sender][validatorID] >= amount, "low outstanding sMTC balance");
        require(IERC20(sMTCTokenAddress).allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        outstandingSMTC[msg.sender][validatorID] -= amount;

        // It's important that we burn after updating outstandingSMTC (protection against Re-Entrancy)
        ERC20Burnable(sMTCTokenAddress).burnFrom(msg.sender, amount);
    }

    function allowedToWithdrawStake(address sender, uint256 validatorID) public view returns(bool) {
        return outstandingSMTC[sender][validatorID] == 0;
    }
}
