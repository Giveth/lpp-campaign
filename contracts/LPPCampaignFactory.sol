pragma solidity ^0.4.18;

import "./LPPCampaign.sol";
import "@aragon/os/contracts/factory/AppProxyFactory.sol";
import "@aragon/os/contracts/kernel/Kernel.sol";
import "@aragon/os/contracts/common/VaultRecoverable.sol";
import "giveth-liquidpledging/contracts/LiquidPledging.sol";
import "giveth-liquidpledging/contracts/LPConstants.sol";

contract LPPCampaignFactory is LPConstants, VaultRecoverable, AppProxyFactory {
    Kernel public kernel;

    bytes32 constant public CAMPAIGN_APP_ID = keccak256("lpp-campaign");
    bytes32 constant public CAMPAIGN_APP = keccak256(APP_BASES_NAMESPACE, CAMPAIGN_APP_ID);
    bytes32 constant public LP_APP_INSTANCE = keccak256(APP_ADDR_NAMESPACE, LP_APP_ID);

    event DeployCampaign(address campaign);

    function LPPCampaignFactory(address _kernel) public 
    {
        // note: this contract will need CREATE_PERMISSIONS_ROLE on the ACL
        // and the PLUGIN_MANAGER_ROLE on liquidPledging,
        // the CAMPAIGN_APP and LP_APP_INSTANCE need to be registered with the kernel

        require(_kernel != 0x0);
        kernel = Kernel(_kernel);
    }

    function newCampaign(
        string name,
        string url,
        uint64 parentProject,
        address reviewer
    ) public
    {
        address campaignBase = kernel.getApp(CAMPAIGN_APP);
        require(campaignBase != 0);
        address liquidPledging = kernel.getApp(LP_APP_INSTANCE);
        require(liquidPledging != 0);

        LPPCampaign campaign = LPPCampaign(newAppProxy(kernel, CAMPAIGN_APP_ID));

        LiquidPledging(liquidPledging).addValidPluginInstance(address(campaign));

        campaign.initialize(liquidPledging, name, url, parentProject, reviewer);

        _setPermissions(campaign, liquidPledging);

        DeployCampaign(address(campaign));
    }

    function _setPermissions(
        LPPCampaign campaign,
        address liquidPledging
    ) internal
    {
        ACL acl = ACL(kernel.acl());

        bytes32 adminRole = campaign.ADMIN_ROLE();
        bytes32 acceptTransferRole = campaign.ACCEPT_TRANSFER_ROLE();

        acl.createPermission(liquidPledging, address(campaign), acceptTransferRole, address(campaign));
        // this permission is managed by msg.sender
        acl.createPermission(msg.sender, address(campaign), adminRole, msg.sender);
    }

    function getRecoveryVault() public view returns (address) {
        return kernel.getRecoveryVault();
    }
}
