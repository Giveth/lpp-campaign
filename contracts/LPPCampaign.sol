pragma solidity ^0.4.13;

import "giveth-liquidpledging/contracts/LiquidPledging.sol";
import "giveth-liquidpledging/contracts/EscapableApp.sol";
import "giveth-common-contracts/contracts/Escapable.sol";
import "minimetoken/contracts/MiniMeToken.sol";
import "@aragon/os/contracts/acl/ACL.sol";
import "@aragon/os/contracts/kernel/KernelProxy.sol";


/// @title LPPCampaign
/// @author RJ Ewing<perissology@protonmail.com>
/// @notice The LPPCampaign contract is a plugin contract for liquidPledging,
///  extending the functionality of a liquidPledging project. This contract
///  prevents withdrawals from any pledges this contract is the owner of.
///  This contract has 3 roles. The admin, a reviewer, and a transfer role. The admin
///  can cancel the campaign, update the conditions the campaign accepts transfers
///  and send a tx as the campaign. The reviewer can cancel the campaign. The transfer role
///  can transfer any pledge's owned by this campaign. Each entity given the transfer role can
///  restricted by amount of the transfer and/or which idAdmin they can transfer to.
///  If this contract is canceled, all pledges will be rolled back to the previous owner
///  and will reject all future pledge transfers to the pledgeAdmin represented by this contract
contract LPPCampaign is EscapableApp, TokenController {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    // used internally to control what transfers to accept
    bytes32 public constant ACCEPT_TRANSFER_ROLE = keccak256("ACCEPT_TRANSFER_ROLE");

    uint constant FROM_OWNER = 0;
    uint constant FROM_PROPOSEDPROJECT = 255;
    uint constant TO_OWNER = 256;
    uint constant TO_PROPOSEDPROJECT = 511;

    LiquidPledging public liquidPledging;
    MiniMeToken public campaignToken;
    uint64 public idProject;
    address public reviewer;
    address public newReviewer;

    event GenerateTokens(address indexed liquidPledging, address addr, uint amount);

    function initialize(address _escapeHatchDestination) onlyInit public {
        require(false); // overload the EscapableApp
        _escapeHatchDestination;
    }

    function initialize(
        address _liquidPledging,
        address _token,
        string name,
        string url,
        uint64 parentProject,
        address _reviewer,
        address _escapeHatchDestination
    ) onlyInit external
    {
        super.initialize(_escapeHatchDestination);
        require(_liquidPledging != 0);
        require(_reviewer != 0);

        liquidPledging = LiquidPledging(_liquidPledging);

        idProject = liquidPledging.addProject(
            name,
            url,
            address(this),
            parentProject,
            0,
            ILiquidPledgingPlugin(this)
        );
        reviewer = _reviewer;
        campaignToken = MiniMeToken(_token);
    }

    function changeReviewer(address _newReviewer) external auth(REVIEWER_ROLE) {
        newReviewer = _newReviewer;
    }

    function acceptNewReviewer() external {
        require(newReviewer == msg.sender);

        ACL acl = ACL(kernel.acl());
        acl.revokePermission(reviewer, address(this), REVIEWER_ROLE);
        acl.grantPermission(newReviewer, address(this), REVIEWER_ROLE);

        reviewer = newReviewer;
        newReviewer = 0;
    }

    function beforeTransfer(
        uint64 pledgeAdmin,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount
    ) external returns (uint maxAllowed)
	  {
        require(msg.sender == address(liquidPledging));
        var (, fromOwner, , fromProposedProject , , , , ) = liquidPledging.getPledge(pledgeFrom);
        var (, , , , , , , toPledgeState ) = liquidPledging.getPledge(pledgeTo);

        // campaigns can not withdraw funds
        if ( (context == TO_OWNER) && (toPledgeState != LiquidPledgingStorage.PledgeState.Pledged) ) {
            return 0;
        }

        // If this campaign is the proposed recipient of delegated funds or funds are being directly
        // transferred to me, ensure that the campaign has not been canceled
        // also check that the transfer can be performed for the given token, amount, and fromOwner
        if ( (context == TO_PROPOSEDPROJECT) ||
            ( (context == TO_OWNER) && (fromProposedProject != idProject) ))
        {
            if (isCanceled() || !canPerform(msg.sender, ACCEPT_TRANSFER_ROLE, arr(token, amount, fromOwner))) {
                return 0;
            }
        }
        return amount;
    }

    function afterTransfer(
        uint64 pledgeAdmin,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount
    ) external
	  {
        require(msg.sender == address(liquidPledging));
        var (, , , , , , , toPledgeState) = liquidPledging.getPledge(pledgeTo);
        var (, fromOwner, , , , , , ) = liquidPledging.getPledge(pledgeFrom);

        // only issue tokens when pledge is committed to this campaign
        if ( (context == TO_OWNER) &&
            (toPledgeState == LiquidPledgingStorage.PledgeState.Pledged)) {
            var (, fromAddr , , , , , , ) = liquidPledging.getPledgeAdmin(fromOwner);

            campaignToken.generateTokens(fromAddr, amount);
            GenerateTokens(liquidPledging, fromAddr, amount);
      }
    }

    function cancelCampaign() external {
        require(_hasRole(ADMIN_ROLE) || _hasRole(REVIEWER_ROLE));
        require(!isCanceled());

        liquidPledging.cancelProject(idProject);
    }

    function transfer(uint64 idPledge, uint amount, uint64 idReceiver) external authP(TRANSFER_ROLE, arr(amount, idReceiver)) {
        require(!isCanceled());

        liquidPledging.transfer(
		        idProject,
			      idPledge,
			      amount,
			      idReceiver
        );
    }

    // allows the owner to send any tx, similar to a multi-sig
    // this is necessary b/c the campaign may receive dac/campaign tokens
    // if they transfer a pledge they own to another dac/campaign.
    // this allows the owner to participate in governance with the tokens
    // it holds.
    function sendTransaction(address destination, uint value, bytes data) external auth(ADMIN_ROLE) {
        require(destination.call.value(value)(data));
    }

    // this allows the ADMIN to use the ACL permissions to control under what circumstances a transfer can be
    // made to this PledgeAdmin. Some examples are whitelisting tokens and/or who can donate
    function setTransferPermissions(uint[] params) external auth(ADMIN_ROLE) {
        // hack until they fix thier shit regarding the require(!hasPermission) when setting another permission
        ACL(kernel.acl()).revokePermission(address(liquidPledging), address(this), ACCEPT_TRANSFER_ROLE);
        ACL(kernel.acl()).grantPermissionP(address(liquidPledging), address(this), ACCEPT_TRANSFER_ROLE, params);
    }

    function isCanceled() public constant returns (bool) {
        return liquidPledging.isProjectCanceled(idProject);
    }

    function _hasRole(bytes32 role) internal returns(bool) {
      return canPerform(msg.sender, role, new uint[](0));
    }

////////////////
// TokenController
////////////////

  /// @notice Called when `_owner` sends ether to the MiniMe Token contract
  /// @param _owner The address that sent the ether to create tokens
  /// @return True if the ether is accepted, false if it throws
    function proxyPayment(address _owner) public payable returns(bool) {
        return false;
    }

  /// @notice Notifies the controller about a token transfer allowing the
  ///  controller to react if desired
  /// @param _from The origin of the transfer
  /// @param _to The destination of the transfer
  /// @param _amount The amount of the transfer
  /// @return False if the controller does not authorize the transfer
    function onTransfer(address _from, address _to, uint _amount) public returns(bool) {
        return false;
    }

  /// @notice Notifies the controller about an approval allowing the
  ///  controller to react if desired
  /// @param _owner The address that calls `approve()`
  /// @param _spender The spender in the `approve()` call
  /// @param _amount The amount in the `approve()` call
  /// @return False if the controller does not authorize the approval
    function onApprove(address _owner, address _spender, uint _amount) public returns(bool) {
        return false;
    }
}
