pragma solidity ^0.4.18;

import "./LPPCampaign.sol";
import "@aragon/os/contracts/factory/AppProxyFactory.sol";
import "@aragon/os/contracts/common/VaultRecoverable.sol";
import "giveth-liquidpledging/contracts/LiquidPledging.sol";
import "giveth-liquidpledging/contracts/LPConstants.sol";
import "giveth-liquidpledging/contracts/lib/aragon/IACLEnhanced.sol";
import "giveth-liquidpledging/contracts/lib/aragon/IKernelEnhanced.sol";

contract LPPCampaignFactory is LPConstants, VaultRecoverable, AppProxyFactory {
    IKernelEnhanced public kernel;

    // bytes32 constant public CAMPAIGN_APP_ID = keccak256("lpp-campaign");
    bytes32 constant public CAMPAIGN_APP_ID = 0xb645d68dd4f7ddd2bee6043ca156085bc75ba46cc3b5f2e58d04942e24095eac;

    event DeployCampaign(address campaign);

    constructor(address _kernel) public 
    {
        // note: this contract will need CREATE_PERMISSIONS_ROLE on the ACL
        // and the PLUGIN_MANAGER_ROLE on liquidPledging,
        // the CAMPAIGN_APP and LP_APP_INSTANCE need to be registered with the kernel

        require(_kernel != 0x0);
        kernel = IKernelEnhanced(_kernel);
    }

    function newCampaign(
        string name,
        string url,
        uint64 parentProject,
        address reviewer
    ) public
    {
        address campaignBase = kernel.getApp(kernel.APP_BASES_NAMESPACE(), CAMPAIGN_APP_ID);
        require(campaignBase != 0);
        address liquidPledging = kernel.getApp(kernel.APP_ADDR_NAMESPACE(), LP_APP_ID);
        require(liquidPledging != 0);

        LPPCampaign campaign = LPPCampaign(newAppProxy(IKernel(kernel), CAMPAIGN_APP_ID));

        LiquidPledging(liquidPledging).addValidPluginInstance(address(campaign));

        campaign.initialize(liquidPledging, name, url, parentProject, reviewer);

        IACLEnhanced acl = IACLEnhanced(kernel.acl());

        bytes32 adminRole = campaign.ADMIN_ROLE();
        bytes32 acceptTransferRole = campaign.ACCEPT_TRANSFER_ROLE();

        acl.createPermission(liquidPledging, address(campaign), acceptTransferRole, address(campaign));
        // this permission is managed by msg.sender
        acl.createPermission(msg.sender, address(campaign), adminRole, msg.sender);

        DeployCampaign(address(campaign));
    }

    function getRecoveryVault() public view returns (address) {
        return kernel.getRecoveryVault();
    }
}
