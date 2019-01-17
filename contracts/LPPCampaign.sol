pragma solidity ^0.4.24;

import "giveth-liquidpledging/contracts/LiquidPledging.sol";
import "giveth-liquidpledging/contracts/lib/aragon/IACLEnhanced.sol";
import "@aragon/os/contracts/apps/AragonApp.sol";


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
contract LPPCampaign is AragonApp {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // used internally to control what transfers to accept
    bytes32 public constant ACCEPT_TRANSFER_ROLE = keccak256("ACCEPT_TRANSFER_ROLE");

    uint private constant FROM_OWNER = 0;
    uint private constant FROM_PROPOSEDPROJECT = 255;
    uint private constant TO_OWNER = 256;
    uint private constant TO_PROPOSEDPROJECT = 511;

    LiquidPledging public liquidPledging;
    uint64 public idProject;
    address public reviewer;
    address public newReviewer;

    function initialize(
        address _liquidPledging,
        string name,
        string url,
        uint64 parentProject,
        address _reviewer
    ) onlyInit external
    {
        require(_liquidPledging != 0);
        require(_reviewer != 0);
        initialized();

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
    }

    function beforeTransfer(
        uint64 pledgeAdmin,
        uint64 pledgeFrom,
        uint64 pledgeTo,
        uint64 context,
        address token,
        uint amount
    ) external view returns (uint maxAllowed)
	  {
        require(msg.sender == address(liquidPledging));
        (, uint64 fromOwner, , uint64 fromProposedProject , , , , ) = liquidPledging.getPledge(pledgeFrom);
        (, , , , , , , LiquidPledgingStorage.PledgeState toPledgeState ) = liquidPledging.getPledge(pledgeTo);

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
    ) external pure {}

    function changeReviewer(address _newReviewer) external {
        require(msg.sender == reviewer);
        newReviewer = _newReviewer;
    }

    function acceptNewReviewer() external {
        require(newReviewer == msg.sender);

        reviewer = newReviewer;
        newReviewer = 0;
    }

    function cancelCampaign() external {
        require(msg.sender == reviewer || canPerform(msg.sender, ADMIN_ROLE, new uint[](0)));
        require(!isCanceled());

        liquidPledging.cancelProject(idProject);
    }

    function transfer(uint64 idPledge, uint amount, uint64 idReceiver) external authP(ADMIN_ROLE, arr(amount, idReceiver)) {
        require(!isCanceled());

        liquidPledging.transfer(
		        idProject,
			    idPledge,
			    amount,
			    idReceiver
        );
    }

    uint constant D64 = 0x10000000000000000;

    function mTransfer(
        uint[] pledgesAmounts,
        uint64 idReceiver
    ) external
    {
        require(!isCanceled());

        // TODO is there a more efficient way to do this? we can't pass array into canPerform function
        // this has ~ 15k gas overhead / pledge vs a single authP
        for (uint i = 0; i < pledgesAmounts.length; i++ ) {
            uint amount = pledgesAmounts[i] / D64;
            require(canPerform(msg.sender, ADMIN_ROLE, arr(amount, idReceiver)));
        }

        liquidPledging.mTransfer(
            idProject,
            pledgesAmounts,
            idReceiver
        );
    }

    // this allows the ADMIN to use the ACL permissions to control under what circumstances a transfer can be
    // made to this PledgeAdmin. Some examples are whitelisting tokens and/or who can donate
    function setTransferPermissions(uint256[] params) external auth(ADMIN_ROLE) {
        IACLEnhanced(kernel().acl()).grantPermissionP(address(liquidPledging), address(this), ACCEPT_TRANSFER_ROLE, params);
    }

    function isCanceled() public view returns (bool) {
        return liquidPledging.isProjectCanceled(idProject);
    }

    function update(
        string newName,
        string newUrl,
        uint64 newCommitTime
    ) public auth(ADMIN_ROLE)
    {
        liquidPledging.updateProject(
            idProject,
            address(this),
            newName,
            newUrl,
            newCommitTime
        );
    }
}
