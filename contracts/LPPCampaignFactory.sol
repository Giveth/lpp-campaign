pragma solidity ^0.4.13;

import "./LPPCampaign.sol";

contract LPPCampaignFactory {
    function deploy(
        LiquidPledging liquidPledging,
        string name,
        string url,
        uint64 parentProject,
        address reviewer,
        string tokenName,
        string tokenSymbol
  ) {
        LPPCampaign campaign = new LPPCampaign(tokenName, tokenSymbol);
        campaign.init(liquidPledging, name, url, parentProject, reviewer);
        campaign.changeOwnership(msg.sender);
    }
}
