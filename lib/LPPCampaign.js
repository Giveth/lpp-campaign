'use strict';

var LPPCampaignABI = require('../build/LPPCampaign.sol').LPPCampaignAbi;
var LPPCampaignByteCode = require('../build/LPPCampaign.sol').LPPCampaignByteCode;
var generateClass = require('eth-contract-class').default;

var LPPCampaign = generateClass(LPPCampaignABI, LPPCampaignByteCode);

var translateStatus = function translateStatus(status) {
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
  return Promise.all([this.liquidPledging(), this.idProject(), this.reviewer(), this.newReviewer(), this.status()]).then(function (results) {
    return {
      liquidPledging: results[0],
      idProject: results[1],
      reviewer: results[2],
      newReviewer: results[3],
      status: translateStatus(results[4])
    };
  });
};

module.exports = LPPCampaign;
//# sourceMappingURL=LPPCampaign.js.map