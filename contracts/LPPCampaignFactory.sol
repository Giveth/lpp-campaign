pragma solidity ^0.4.18;

import "./LPPCampaign.sol";
import "minimetoken/contracts/MiniMeToken.sol";
import "@aragon/os/contracts/factory/AppProxyFactory.sol";
import "@aragon/os/contracts/kernel/Kernel.sol";
import "giveth-liquidpledging/contracts/LiquidPledging.sol";
import "giveth-liquidpledging/contracts/LPConstants.sol";
import "giveth-common-contracts/contracts/Escapable.sol";

contract LPPCampaignFactory is LPConstants, Escapable, AppProxyFactory {
    Kernel public kernel;
    MiniMeTokenFactory public tokenFactory;

    bytes32 constant public CAMPAIGN_APP_ID = keccak256("lpp-campaign");
    bytes32 constant public CAMPAIGN_APP = keccak256(APP_BASES_NAMESPACE, CAMPAIGN_APP_ID);
    bytes32 constant public LP_APP_INSTANCE = keccak256(APP_ADDR_NAMESPACE, LP_APP_ID);

    event DeployCampaign(address campaign);

    function LPPCampaignFactory(address _kernel, address _tokenFactory, address _escapeHatchCaller, address _escapeHatchDestination)
        Escapable(_escapeHatchCaller, _escapeHatchDestination) public
    {
        // note: this contract will need CREATE_PERMISSIONS_ROLE on the ACL
        // and the PLUGIN_MANAGER_ROLE on liquidPledging,
        // the CAMPAIGN_APP and LP_APP_INSTANCE need to be registered with the kernel

        require(_kernel != 0x0);
        require(_tokenFactory != 0x0);
        kernel = Kernel(_kernel);
        tokenFactory = MiniMeTokenFactory(_tokenFactory);
    }

    function newCampaign(
        string name,
        string url,
        uint64 parentProject,
        address reviewer,
        string tokenName,
        string tokenSymbol,
        address escapeHatchCaller,
        address escapeHatchDestination
    ) public
    {
        address campaignBase = kernel.getApp(CAMPAIGN_APP);
        require(campaignBase != 0);
        address liquidPledging = kernel.getApp(LP_APP_INSTANCE);
        require(liquidPledging != 0);

        // TODO: could make MiniMeToken an AragonApp to save gas by deploying a proxy
        address token = new MiniMeToken(tokenFactory, 0x0, 0, tokenName, 18, tokenSymbol, false);
        LPPCampaign campaign = LPPCampaign(newAppProxy(kernel, CAMPAIGN_APP_ID));

        LiquidPledging(liquidPledging).addValidPluginInstance(address(campaign));

        campaign.initialize(liquidPledging, token, name, url, parentProject, reviewer, escapeHatchDestination);
        MiniMeToken(token).changeController(address(campaign));

        _setPermissions(campaign, liquidPledging, escapeHatchCaller);

        DeployCampaign(address(campaign));
    }

    function _setPermissions(
        LPPCampaign campaign,
        address liquidPledging,
        address escapeHatchCaller
    ) internal
    {
        ACL acl = ACL(kernel.acl());

        bytes32 hatchCallerRole = campaign.ESCAPE_HATCH_CALLER_ROLE();
        bytes32 adminRole = campaign.ADMIN_ROLE();
        bytes32 transferRole = campaign.TRANSFER_ROLE();
        bytes32 acceptTransferRole = campaign.ACCEPT_TRANSFER_ROLE();

        acl.createPermission(liquidPledging, address(campaign), acceptTransferRole, address(campaign));
        // this permission is managed by the escapeHatchCaller
        acl.createPermission(escapeHatchCaller, address(campaign), hatchCallerRole, escapeHatchCaller);
        // these 2 permissions are managed by msg.sender
        acl.createPermission(msg.sender, address(campaign), adminRole, msg.sender);
        acl.createPermission(msg.sender, address(campaign), transferRole, msg.sender);
    }
}
