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
        LPPCampaign campaign = new LPPCampaign(liquidPledging, tokenName, tokenSymbol);
        campaign.init(name, url, parentProject, reviewer);
        campaign.changeOwnership(msg.sender);
    }
}
