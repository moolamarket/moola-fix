const IERC20 = artifacts.require("IERC20");
const ConsoleLogTest = artifacts.require("ConsoleLogTest");
const IOwnedWallet = artifacts.require("IOwnedWallet");
const MoolaOracle = artifacts.require("MoolaOracle");

const ONE = 1000000000000000000n;

contract.skip("Celo Fork", (accounts) => {
  const multisig = '0xd7f77169d5E6a32C5044052F9a49eb94697b25ED';
  it("should transfer CELO through contract", async () => {
    const celo = await IERC20.at('0x471EcE3750Da237f93B8E339c536989b8978a438');
    await celo.transfer('0xdead000000000000000000000000000000000000', 1, {from: accounts[0]});
    const balance = await celo.balanceOf('0xdead000000000000000000000000000000000000');

    assert.equal(balance.valueOf(), 1);
  });
  it("should console log in the fork console", async () => {
    const consoleLogTest = await ConsoleLogTest.new();
    await consoleLogTest.testCall.call();
  });
  it("should impersonate multisig", async () => {
    const celo = await IERC20.at('0x471EcE3750Da237f93B8E339c536989b8978a438');
    const ownedWallet = await IOwnedWallet.at('0x313bc86D3D6e86ba164B2B451cB0D9CfA7943e5c');
    await celo.transfer(ownedWallet.address, 1, {from: accounts[0]});
    await ownedWallet.executeMany([celo.address], [0], [(await celo.transfer.request('0xdead00000000000000000000000000000000dead', 1)).data], {from: multisig});
    assert.equal(await celo.balanceOf('0xdead00000000000000000000000000000000dead').valueOf(), 1);
    assert.equal(await celo.balanceOf(ownedWallet.address).valueOf(), 0);
  });
  it("should get price from MoolaOracle", async () => {
    const oracle = await MoolaOracle.at('0xBa2224905Ad3CDbA6c1b764CD62FDa52bd524d29');
    const cUSDPrice = await oracle.getAssetPrice('0x765DE816845861e75A25fCA122bb6898B8B1282a');

    assert.isTrue(BigInt(cUSDPrice.valueOf()) > ONE);
    assert.isTrue(BigInt(cUSDPrice.valueOf()) < 2n * ONE);
  });
  it("should transfer cUSD through contract", async () => {
    const cusd = await IERC20.at('0x765DE816845861e75A25fCA122bb6898B8B1282a');
    await cusd.transfer('0xdead000000000000000000000000000000000000', 1, {from: multisig});
    const balance = await cusd.balanceOf('0xdead000000000000000000000000000000000000');

    assert.equal(balance.valueOf(), 1);
  });
});