pragma solidity ^0.4.13;

import "../node_modules/liquidpledging/contracts/LiquidPledging.sol";
import "./Owned.sol";

contract LPPCampaign is Owned {
    uint constant FROM_OWNER = 0;
    uint constant FROM_PROPOSEDPROJECT = 255;
    uint constant TO_OWNER = 256;
    uint constant TO_PROPOSEDPROJECT = 511;

    LiquidPledging public liquidPledging;
    uint64 public idProject;
    address public reviewer;
    address public newReviewer;
    CampaignStatus public status;

    enum CampaignStatus { Active, Canceled }

    event CampaignCanceled(address indexed liquidPledging);

    function LPPCampaign(LiquidPledging _liquidPledging, string name, uint64 parentProject, address _reviewer) {
        liquidPledging = _liquidPledging;
        idProject = liquidPledging.addProject(name, address(this), parentProject, 0, ILiquidPledgingPlugin(this));
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

    function changeReviewer(address _newReviewer) onlyReviewer {
        newReviewer = _newReviewer;
    }

    function acceptNewReviewer() {
        require(newReviewer == msg.sender);
        reviewer = newReviewer;
        newReviewer = 0;
    }

    function beforeTransfer(uint64 noteManager, uint64 noteFrom, uint64 noteTo, uint64 context, uint amount) returns (uint maxAllowed) {
        require(msg.sender == address(liquidPledging));
        var (, , , fromProposedProject , , , ) = liquidPledging.getNote(noteFrom);
        // If I'm the proposed recipient of delegated funds or funds are being directly transferred to me, ensure the I am still active
        if (   (context == TO_PROPOSEDPROJECT)
            || (   (context == TO_OWNER)
                && (fromProposedProject != idProject)))
        {
            if (status != CampaignStatus.Active) return 0;
        }
        return amount;
    }

    function afterTransfer(uint64 noteManager, uint64 noteFrom, uint64 noteTo, uint64 context, uint amount) {
        // do nothing
    }


    function cancelCampaign() onlyOwnerOrReviewer {
        require( status == CampaignStatus.Active );

        liquidPledging.cancelProject(idProject);

        status = CampaignStatus.Canceled;
        CampaignCanceled(address(liquidPledging));
    }
}
