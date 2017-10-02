/* eslint-env mocha */
/* eslint-disable no-await-in-loop */
const TestRPC = require('ethereumjs-testrpc');
const chai = require('chai');
const LiquidPledging = require('liquidpledging').LiquidPledging(true);
const { Vault } = require('liquidpledging');
const LPPCampaign = require('../index.js');
const Web3 = require('web3');

const assert = chai.assert;

//
// const printState = async(liquidPledging) => {
//   console.log(liquidPledging.b);
//   const st = await liquidPledging.getState();
//   console.log(JSON.stringify(st, null, 2));
// };
//
// const printBalances = async(liquidPledging) => {
//   const st = await liquidPledging.getState();
//   assert.equal(st.notes.length, 13);
//   for (let i = 1; i <= 12; i += 1) {
//     console.log(i, ethConnector.web3.fromWei(st.notes[i].amount).toNumber());
//   }
// };
//
// const readTest = async(liquidPledging) => {
//   const t1 = await liquidPledging.test1();
//   const t2 = await liquidPledging.test2();
//   const t3 = await liquidPledging.test3();
//   const t4 = await liquidPledging.test4();
//   console.log('t1: ', t1.toNumber());
//   console.log('t2: ', t2.toNumber());
//   console.log('t3: ', t3.toNumber());
//   console.log('t4: ', t4.toNumber());
// };

describe('LPPCampaign test', () => {
  let web3;
  let accounts;
  let liquidPledging;
  let vault;
  let campaign;
  let donor1;
  let delegate1;
  let campaignOwner1;
  let reviewer1;
  let testrpc;

  before(async () => {
    testrpc = TestRPC.server({
      ws: true,
      gasLimit: 6500000,
      total_accounts: 10,
    });

    testrpc.listen(8546, '127.0.0.1', (err) => {
      if (err) {
        console.log(err);
      }
    });

    web3 = new Web3('ws://localhost:8546');
    accounts = await web3.eth.getAccounts();

    donor1 = accounts[1];
    delegate1 = accounts[2];
    campaignOwner1 = accounts[3];
    reviewer1 = accounts[4];
  });

  it('Should deploy LPPCampaign contract and add project to liquidPledging', async () => {
    vault = await Vault.new(web3);
    liquidPledging = await LiquidPledging.new(web3, vault.$address, { $gas: 5200000 });
    await vault.setLiquidPledging(liquidPledging.$address);

    campaign = await LPPCampaign.new(web3, liquidPledging.$address, 'Campaign 1', 0, reviewer1, { from: campaignOwner1 });

    const lpState = await liquidPledging.getState();
    assert.equal(lpState.managers.length, 2);
    const lpManager = lpState.managers[1];
    assert.equal(lpManager.type, 'Project');
    assert.equal(lpManager.addr, campaign.$address);
    assert.equal(lpManager.name, 'Campaign 1');
    assert.equal(lpManager.commitTime, '0');
    assert.equal(lpManager.canceled, false);
    assert.equal(lpManager.plugin, campaign.$address);

    const cState = await campaign.getState();
    assert.equal(cState.liquidPledging, liquidPledging.$address);
    assert.equal(cState.idProject, '1');
    assert.equal(cState.reviewer, reviewer1);
    assert.equal(cState.newReviewer, '0x0000000000000000000000000000000000000000');
    assert.equal(cState.status, 'Active');
  }).timeout(6000);
});
