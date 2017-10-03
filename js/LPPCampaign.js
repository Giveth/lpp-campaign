const LPPCampaignABI = require('../build/contracts/LPPCampaign.json').abi;
const LPPCampaignByteCode = require('../build/contracts/LPPCampaign.json').bytecode;
const generateClass = require('eth-contract-class').default;

const LPPCampaign = generateClass(LPPCampaignABI, LPPCampaignByteCode);

const translateStatus = (status) => {
  switch (status) {
    case '0':
      return 'Active';
    case '1':
      return 'Canceled';
    default:
      return 'Unknown';
  }
};

LPPCampaign.prototype.getState = function () {
  return Promise.all([
    this.liquidPledging(),
    this.idProject(),
    this.reviewer(),
    this.newReviewer(),
    this.status(),
  ])
  .then(results => ({
    liquidPledging: results[0],
    idProject: results[1],
    reviewer: results[2],
    newReviewer: results[3],
    status: translateStatus(results[4]),
  }));
};

module.exports = LPPCampaign;
