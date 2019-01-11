const generateClass = require('eth-contract-class').default;

const factoryArtifact = require('./dist/contracts/LPPCampaignFactory.json');
const campaignArtifact = require('./dist/contracts/LPPCampaign.json');

module.exports = {
  LPPCampaign: generateClass(campaignArtifact.abiDefinition, campaignArtifact.code),
  LPPCampaignFactory: generateClass(factoryArtifact.abiDefinition, factoryArtifact.code),
};
