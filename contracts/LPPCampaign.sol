pragma solidity ^0.4.13;

import "liquidpledging/contracts/LiquidPledging.sol";
import "giveth-common-contracts/contracts/Owned.sol";
import "minimetoken/contracts/MiniMeToken.sol";

/// @title LPPCampaign
/// @author perissology <perissology@protonmail.com>
/// @notice The LPPCampaign contract is a plugin contract for liquidPledging,
///  extending the functionality of a liquidPledging project. This contract
///  prevents withdrawals from any pledges this contract is the owner of.
///  This contract has 2 roles. The owner and a reviewer. The owner can transfer or cancel
///  any pledges this contract owns. The reviewer can only cancel the pledges.
///  If this contract is canceled, all pledges will be rolled back to the previous owner
///  and will reject all future pledge transfers to the pledgeAdmin represented by this contract
contract LPPCampaign is Owned, TokenController {
    uint constant FROM_OWNER = 0;
    uint constant FROM_PROPOSEDPROJECT = 255;
    uint constant TO_OWNER = 256;
    uint constant TO_PROPOSEDPROJECT = 511;

    LiquidPledging public liquidPledging;
    MiniMeToken public token;
    bool public initPending;
    uint64 public idProject;
    address public reviewer;
    address public newReviewer;

    event GenerateTokens(address indexed liquidPledging, address addr, uint amount);

    function LPPCampaign(
        LiquidPledging _liquidPledging,
        string tokenName,
        string tokenSymbol
    ) {
      require(msg.sender != tx.origin);
      liquidPledging = _liquidPledging;
      MiniMeTokenFactory tokenFactory = new MiniMeTokenFactory();
      token = new MiniMeToken(tokenFactory, 0x0, 0, tokenName, 18, tokenSymbol, false);
      initPending = true;
    }

    function init(
        string name,
        string url,
        uint64 parentProject,
        address _reviewer
    ) {
        require(initPending);
        idProject = liquidPledging.addProject(name, url, address(this), parentProject, 0, ILiquidPledgingPlugin(this));
        reviewer = _reviewer;
        initPending = false;
    }

    modifier initialized() {
      require(!initPending);
      _;
    }

    modifier onlyReviewer() {
        require(msg.sender == reviewer);
        _;
    }

    modifier onlyOwnerOrReviewer() {
        require( msg.sender == owner || msg.sender == reviewer );
        _;
    }

    function changeReviewer(address _newReviewer) public initialized onlyReviewer {
        newReviewer = _newReviewer;
    }

    function acceptNewReviewer() public initialized {
        require(newReviewer == msg.sender);
        reviewer = newReviewer;
        newReviewer = 0;
    }

    function beforeTransfer(
        uint64 pledgeAdmin,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        uint amount
    ) external initialized returns (uint maxAllowed) {
        require(msg.sender == address(liquidPledging));
        var (, , , fromProposedProject , , , ) = liquidPledging.getPledge(pledgeFrom);
        var (, , , , , , toPaymentState ) = liquidPledging.getPledge(pledgeTo);

        // campaigns can not withdraw funds
        if ( (context == TO_OWNER) && (toPaymentState != LiquidPledgingBase.PaymentState.Pledged) ) return 0;

        // If this campaign is the proposed recipient of delegated funds or funds are being directly
        // transferred to me, ensure that the campaign has not been canceled
        if ( (context == TO_PROPOSEDPROJECT)
            || ( (context == TO_OWNER) && (fromProposedProject != idProject) ))
        {
            if (isCanceled()) return 0;
        }
        return amount;
    }

    function afterTransfer(
        uint64 pledgeAdmin,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        uint amount
    ) external initialized {
      require(msg.sender == address(liquidPledging));
      var (, , , , , , toPaymentState ) = liquidPledging.getPledge(pledgeTo);
      var (, fromOwner, , , , , ) = liquidPledging.getPledge(pledgeFrom);

      // only issue tokens when pledge is committed to this campaign
      if ( (context == TO_OWNER) &&
              (toPaymentState == LiquidPledgingBase.PaymentState.Pledged)) {
        var (, fromAddr , , , , , , ) = liquidPledging.getPledgeAdmin(fromOwner);

        token.generateTokens(fromAddr, amount);
        GenerateTokens(liquidPledging, fromAddr, amount);
      }
    }

    function cancelCampaign() public initialized onlyOwnerOrReviewer {
        require( !isCanceled() );

        liquidPledging.cancelProject(idProject);
    }

    function transfer(uint64 idPledge, uint amount, uint64 idReceiver) public initialized onlyOwner {
      require( !isCanceled() );

      liquidPledging.transfer(idProject, idPledge, amount, idReceiver);
    }

    function isCanceled() public constant initialized returns (bool) {
      return liquidPledging.isProjectCanceled(idProject);
    }

    // allows the owner to send any tx, similar to a multi-sig
    // this is necessary b/c the campaign may receive dac/campaign tokens
    // if they transfer a pledge they own to another dac/campaign.
    // this allows the owner to participate in governance with the tokens
    // it holds.
    function sendTransaction(address destination, uint value, bytes data) public initialized onlyOwner {
      require(destination.call.value(value)(data));
    }

////////////////
// TokenController
////////////////

  /// @notice Called when `_owner` sends ether to the MiniMe Token contract
  /// @param _owner The address that sent the ether to create tokens
  /// @return True if the ether is accepted, false if it throws
  function proxyPayment(address _owner) public payable initialized returns(bool) {
    return false;
  }

  /// @notice Notifies the controller about a token transfer allowing the
  ///  controller to react if desired
  /// @param _from The origin of the transfer
  /// @param _to The destination of the transfer
  /// @param _amount The amount of the transfer
  /// @return False if the controller does not authorize the transfer
  function onTransfer(address _from, address _to, uint _amount) public initialized returns(bool) {
    return false;
  }

  /// @notice Notifies the controller about an approval allowing the
  ///  controller to react if desired
  /// @param _owner The address that calls `approve()`
  /// @param _spender The spender in the `approve()` call
  /// @param _amount The amount in the `approve()` call
  /// @return False if the controller does not authorize the approval
  function onApprove(address _owner, address _spender, uint _amount) public initialized returns(bool) {
    return false;
  }
}
