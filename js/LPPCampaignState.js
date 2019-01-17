module.exports = function(campaign) {
  return {
    getState: () =>
      Promise.all([
        campaign.liquidPledging(),
        campaign.idProject(),
        campaign.reviewer(),
        campaign.newReviewer(),
        campaign.isCanceled(),
      ]).then(results => ({
        liquidPledging: results[0],
        idProject: results[1],
        reviewer: results[2],
        newReviewer: results[3],
        canceled: results[4],
      })),
  };
};
