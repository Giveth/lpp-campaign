const generateClass = require('eth-contract-class').default;

const factoryArtifact = require('./build/LPPCampaignFactory.json');
const campaignArtifact = require('./build/LPPCampaign.json');

module.exports = {
  LPPCampaign: generateClass(
    campaignArtifact.compilerOutput.abi,
    campaignArtifact.compilerOutput.evm.bytecode.object,
  ),
  LPPCampaignFactory: generateClass(
    factoryArtifact.compilerOutput.abi,
    factoryArtifact.compilerOutput.evm.bytecode.object,
  ),
};