const LPPCampaignFactoryABI = require('../build/LPPCampaignFactory.sol').LPPCampaignFactoryAbi;
const LPPCampaignFactoryByteCode = require('../build/LPPCampaignFactory.sol').LPPCampaignFactoryByteCode;
const generateClass = require('eth-contract-class').default;

module.exports = generateClass(LPPCampaignFactoryABI, LPPCampaignFactoryByteCode);
