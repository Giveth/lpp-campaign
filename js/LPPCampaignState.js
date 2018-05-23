class LPPCampaignState {
  constructor(lppCampaign) {
    this.campaign = lppCampaign;
  }

  getState() {
    return Promise.all([
      this.campaign.liquidPledging(),
      this.campaign.idProject(),
      this.campaign.reviewer(),
      this.campaign.newReviewer(),
      this.campaign.isCanceled(),
      this.campaign.campaignToken(),
    ])
      .then(results => ({
        liquidPledging: results[0],
        idProject: results[1],
        reviewer: results[2],
        newReviewer: results[3],
        canceled: results[4],
        campaignToken: results[5]
      }));
  }
}

module.exports = LPPCampaignState;
