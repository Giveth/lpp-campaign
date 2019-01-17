/* eslint-env mocha */
/* eslint-disable no-await-in-loop */
const { assert } = require('chai');
const LPPCampaignState = require('../js/LPPCampaignState');

const { assertFail, deployLP, embarkConfig } = require('giveth-liquidpledging').test;

const LPPCampaignFactory = embark.require('Embark/contracts/LPPCampaignFactory');
const LPPCampaign = embark.require('Embark/contracts/LPPCampaign');
const Kernel = embark.require('Embark/contracts/Kernel');
const ACL = embark.require('Embark/contracts/ACL');
const StandardTokenTest = embark.require('Embark/contracts/StandardToken');

embarkConfig({
  LPPCampaign: {},
});

describe('LPPCampaign test', function() {
  this.timeout(0);

  let accounts;
  let liquidPledging;
  let liquidPledgingState;
  let vault;
  let campaign;
  let campaignState;
  let acl;
  let kernel;
  let giver1;
  let project1;
  let campaignOwner1;
  let reviewer1;
  let reviewer2;
  let ganache;
  let giver1Token;

  before(async () => {
    const deployment = await deployLP();
    accounts = deployment.accounts;

    project1 = accounts[2];
    campaignOwner1 = accounts[3];
    reviewer1 = accounts[4];
    reviewer2 = accounts[5];

    giver1 = deployment.giver1;
    vault = deployment.vault;
    liquidPledging = deployment.liquidPledging;
    liquidPledgingState = deployment.liquidPledgingState;
    giver1Token = deployment.token;

    // set permissions
    kernel = Kernel.at(await liquidPledging.kernel());
    acl = ACL.at(await kernel.acl());
    await acl.createPermission(
      accounts[0],
      vault.$address,
      await vault.CANCEL_PAYMENT_ROLE(),
      accounts[0],
      { $extraGas: 200000 },
    );
    await acl.createPermission(
      accounts[0],
      vault.$address,
      await vault.CONFIRM_PAYMENT_ROLE(),
      accounts[0],
      { $extraGas: 200000 },
    );
  });

  it('Should deploy LPPCampaign contract and add project to liquidPledging', async () => {
    factory = await LPPCampaignFactory.new(kernel.$address);
    await acl.grantPermission(factory.$address, acl.$address, await acl.CREATE_PERMISSIONS_ROLE(), {
      $extraGas: 200000,
    });
    await acl.grantPermission(
      factory.$address,
      liquidPledging.$address,
      await liquidPledging.PLUGIN_MANAGER_ROLE(),
      { $extraGas: 200000 },
    );
    await acl.grantPermission(
      factory.$address,
      kernel.$address,
      await kernel.APP_MANAGER_ROLE(),
      { $extraGas: 200000 },
    );

    await kernel.setApp(
      await kernel.APP_BASES_NAMESPACE(),
      await factory.CAMPAIGN_APP_ID(),
      LPPCampaign.$address,
      { $extraGas: 200000 },
    );

    await factory.newCampaign('Campaign 1', 'URL1', 0, reviewer1, {
      from: campaignOwner1,
    });

    const lpState = await liquidPledgingState.getState();
    assert.equal(lpState.admins.length, 2);
    const lpManager = lpState.admins[1];

    campaign = LPPCampaign.at(lpManager.plugin);
    campaignState = new LPPCampaignState(campaign);

    assert.isAbove(Number(await campaign.getInitializationBlock()), 0);

    assert.equal(lpManager.type, 'Project');
    assert.equal(lpManager.addr, campaign.$address);
    assert.equal(lpManager.name, 'Campaign 1');
    assert.equal(lpManager.commitTime, '0');
    assert.equal(lpManager.canceled, false);

    const cState = await campaignState.getState();
    assert.equal(cState.liquidPledging, liquidPledging.$address);
    assert.equal(cState.idProject, '1');
    assert.equal(cState.reviewer, reviewer1);
    assert.equal(cState.newReviewer, '0x0000000000000000000000000000000000000000');
    assert.equal(cState.canceled, false);
  });

  it('Should accept transfers if not canceled', async function() {
    await liquidPledging.addGiver('Giver1', 'URL', 0, '0x0000000000000000000000000000000000000000', { from: giver1 }); // pledgeAdmin #2
    await liquidPledging.donate(2, 1, giver1Token.$address, 1000, { from: giver1 });

    const st = await liquidPledgingState.getState();
    assert.equal(st.pledges[2].amount, 1000);
    assert.equal(st.pledges[2].token, giver1Token.$address);
    assert.equal(st.pledges[2].owner, 1);
  });

  it('Should be able to transfer pledge to another project', async function() {
    await liquidPledging.addProject('Project1', 'URL', project1, 0, 0, '0x0000000000000000000000000000000000000000', {
      from: project1,
      $extraGas: 100000,
    }); // pledgeAdmin #3
    await campaign.transfer(2, 1000, 3, { from: campaignOwner1, $extraGas: 200000 });

    const st = await liquidPledgingState.getState();
    assert.equal(st.pledges[3].amount, 1000);
    assert.equal(st.pledges[3].owner, 3);
    assert.equal(st.pledges[2].amount, 0);
  });

  it('Should be able to change reviewer', async function() {
    await campaign.changeReviewer(reviewer2, { from: reviewer1, $extraGas: 100000 });

    const st = await campaignState.getState();
    assert.equal(st.reviewer, reviewer1);
    assert.equal(st.newReviewer, reviewer2);

    await campaign.acceptNewReviewer({ from: reviewer2, $extraGas: 100000 });

    const st2 = await campaignState.getState();
    assert.equal(st2.reviewer, reviewer2);
    assert.equal(st2.newReviewer, '0x0000000000000000000000000000000000000000');
  });

  it('Owner should not be able to change reviewer', async function() {
    await assertFail(campaign.changeReviewer(reviewer1, { from: campaignOwner1, gas: 6700000 }));
  });

  it('Reviewer should be able to cancel campaign', async function() {
    await campaign.cancelCampaign({ from: reviewer2, $extraGas: 100000 });

    const canceled = await campaign.isCanceled();
    assert.equal(canceled, true);
  });

  it('Should deploy another campaign', async function() {
    campaign = await factory.newCampaign('Campaign 2', 'URL2', 0, reviewer1, {
      from: campaignOwner1,
    }); // pledgeAdmin #4

    const nPledgeAdmins = await liquidPledging.numberOfPledgeAdmins();
    const campaign2Admin = await liquidPledging.getPledgeAdmin(nPledgeAdmins);
    campaign = LPPCampaign.at(campaign2Admin.plugin);

    const canceled = await campaign.isCanceled();
    assert.equal(canceled, false);
  });

  it('Should reject transfer for unapproved token', async function() {
    const token2 = await StandardTokenTest.new(web3);
    await token2.mint(giver1, web3.utils.toWei('1000'));
    await token2.approve(liquidPledging.$address, '0xFFFFFFFFFFFFFFFF', { from: giver1 });

    const params = [
      // id: 204 (logic) op: OR(9) value: 2 or 1
      // '0xcc09000000000000000000000000000000000000000000000000000200000001',
      // id: 0 (arg 0) op: EQ(1) value: token2.$address
      `0x000100000000000000000000${token2.$address.slice(2)}`,
    ];
    await campaign.setTransferPermissions(params, { from: campaignOwner1, $extraGas: 100000 });

    await assertFail(
      liquidPledging.donate(2, 1, giver1Token.$address, 1000, { from: giver1, gas: 4000000 }),
    );

    await liquidPledging.donate(2, 4, token2.$address, 1000, { from: giver1, $extraGas: 100000 });

    const st = await liquidPledgingState.getState();
    assert.equal(st.pledges[5].amount, 1000);
    assert.equal(st.pledges[5].owner, 4);
  });

  it('Should update project', async function() {
    await campaign.update('new name', 'new url', 1010, { from: campaignOwner1, $extraGas: 100000 });

    const c = await liquidPledging.getPledgeAdmin(4);
    assert.equal(c.name, 'new name');
    assert.equal(c.addr, campaign.$address);
    assert.equal(c.url, 'new url');
    assert.equal(c.commitTime, 1010);
  });

  it('Random should not be able to cancel campaign', async function() {
    await assertFail(campaign.cancelCampaign({ from: accounts[9], gas: 6700000 }));
  });

  it('Owner should be able to cancel campaign', async function() {
    await campaign.cancelCampaign({ from: campaignOwner1, $extraGas: 100000 });

    const canceled = await campaign.isCanceled();
    assert.equal(canceled, true);
  });

  it('Should transfer multiple pledges at once', async function() {
    await factory.newCampaign('Campaign 3', 'URL3', 0, reviewer1, {
      from: campaignOwner1,
    }); // pledgeAdmin #5

    const campaign3Admin = await liquidPledging.getPledgeAdmin(5);
    campaign = LPPCampaign.at(campaign3Admin.plugin);

    await liquidPledging.donate(2, 5, giver1Token.$address, 1000, {
      from: giver1,
      $extraGas: 100000,
    });

    const pledges = [
      { amount: 10, id: 6 },
      { amount: 9, id: 6 },
      { amount: 11, id: 6 },
      { amount: 5, id: 6 },
    ];

    // .substring is to remove the 0x prefix on the toHex result
    const encodedPledges = pledges.map(p => {
      return (
        '0x' +
        web3.utils.padLeft(web3.utils.toHex(p.amount).substring(2), 48) +
        web3.utils.padLeft(web3.utils.toHex(p.id).substring(2), 16)
      );
    });

    await assertFail(campaign.mTransfer(encodedPledges, 3, { from: giver1, gas: 6700000 }));

    await campaign.mTransfer(encodedPledges, 3, { from: campaignOwner1, $extraGas: 400000 });

    const p = await liquidPledging.getPledge(7);
    assert.equal(p.amount, 35);
    assert.equal(p.oldPledge, 6);
    assert.equal(p.owner, 3);
  });
});
