pragma solidity ^0.4.13;

import "./LPPCampaign.sol";


contract LPPCampaignFactory is Escapable {

    function LPPCampaignFactory(address _escapeHatchCaller, address _escapeHatchDestination)
        Escapable(_escapeHatchCaller, _escapeHatchDestination)
    {
    }

    function deploy(
        LiquidPledging liquidPledging,
        string name,
        string url,
        uint64 parentProject,
        address reviewer,
        string tokenName,
        string tokenSymbol,
        address escapeHatchCaller,
        address escapeHatchDestination
  ) {
        LPPCampaign campaign = new LPPCampaign(liquidPledging, tokenName, tokenSymbol, escapeHatchCaller, escapeHatchDestination);
        campaign.init(
            name,
			url,
			parentProject,
			reviewer
        );
        campaign.changeOwnership(msg.sender);
    }
}
