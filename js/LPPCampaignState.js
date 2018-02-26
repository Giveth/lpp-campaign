export default class LPPCampaignState {
  constructor(lppCampaign) {
    this.campaign = lppCampaign;
  }

  getState() {
    return Promise.all([
      this.campaign.liquidPledging(),
      this.campaign.idProject(),
      this.campaign.reviewer(),
      this.campaig.nnewReviewer(),
      this.campaign.isCanceled(),
    ])
      .then(results => ({
        liquidPledging: results[0],
        idProject: results[1],
        reviewer: results[2],
        newReviewer: results[3],
        canceled: results[4],
      }));
  }
}
