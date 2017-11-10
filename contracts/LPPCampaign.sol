pragma solidity ^0.4.13;

import "../node_modules/liquidpledging/contracts/LiquidPledging.sol";
import "../node_modules/giveth-common-contracts/contracts/Owned.sol";

/// @title LPPCampaign
/// @author perissology <perissology@protonmail.com>
/// @notice The LPPCampaign contract is a plugin contract for liquidPledging,
///  extending the functionality of a liquidPledging project. This contract
///  prevents withdrawals from any pledges this contract is the owner of.
///  This contract has 2 roles. The owner and a reviewer. The owner can transfer or cancel
///  any pledges this contract owns. The reviewer can only cancel the pledges.
///  If this contract is canceled, all pledges will be rolled back to the previous owner
///  and will reject all future pledge transfers to the pledgeAdmin represented by this contract
contract LPPCampaign is Owned {
    uint constant FROM_OWNER = 0;
    uint constant FROM_PROPOSEDPROJECT = 255;
    uint constant TO_OWNER = 256;
    uint constant TO_PROPOSEDPROJECT = 511;

    LiquidPledging public liquidPledging;
    uint64 public idProject;
    address public reviewer;
    address public newReviewer;

    function LPPCampaign(
        LiquidPledging _liquidPledging,
        string name,
        string url,
        uint64 parentProject,
        address _reviewer
    ) {
        liquidPledging = _liquidPledging;
        idProject = liquidPledging.addProject(name, url, address(this), parentProject, 0, ILiquidPledgingPlugin(this));
        reviewer = _reviewer;
    }

    modifier onlyReviewer() {
        require(msg.sender == reviewer);
        _;
    }

    modifier onlyOwnerOrReviewer() {
        require( msg.sender == owner || msg.sender == reviewer );
        _;
    }

    function changeReviewer(address _newReviewer) public onlyReviewer {
        newReviewer = _newReviewer;
    }

    function acceptNewReviewer() public {
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
    ) external returns (uint maxAllowed) {
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
    ) external {
        // do nothing
    }

    function cancelCampaign() public onlyOwnerOrReviewer {
        require( !isCanceled() );

        liquidPledging.cancelProject(idProject);
    }

    function transfer(uint64 idSender, uint64 idPledge, uint amount, uint64 idReceiver) public onlyOwner {
      require( !isCanceled() );

      liquidPledging.transfer(idSender, idPledge, amount, idReceiver);
    }

    function isCanceled() public constant returns (bool) {
      return liquidPledging.isProjectCanceled(idProject);
    }
}
