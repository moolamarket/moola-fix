const IERC20 = artifacts.require('IERC20');

const IOwnedWallet = artifacts.require('IOwnedWallet');
const ConsoleLogTest = artifacts.require('ConsoleLogTest');
const LendingPoolAddressesProvider = artifacts.require(
  'LendingPoolAddressesProvider'
);

const AToken = artifacts.require('AToken');
const MoolaFix = artifacts.require('MoolaFix');
const BigNumber = require('bignumber.js');

function BN(num) {
  return new BigNumber(num);
}

async function balanceOf(token, address) {
  return (await token.balanceOf(address)).toString()
}

contract('Moola Fix', (accounts) => {
  const multisig = '0xd7f77169d5E6a32C5044052F9a49eb94697b25ED';
  const addressProviderAddress = '0xD1088091A174d33412a968Fa34Cb67131188B332';

  it.only('should impersonate multisig, and transfer tokens to OwnedWallet', async () => {
    const addressesProvider = await LendingPoolAddressesProvider.at(
      addressProviderAddress
    );

    const moolaFix = await MoolaFix.deployed();
    const moolaFixAddress = moolaFix.address;

    const celo = await IERC20.at('0x471EcE3750Da237f93B8E339c536989b8978a438');
    const cusd = await IERC20.at('0x765DE816845861e75A25fCA122bb6898B8B1282a');
    const ceur = await IERC20.at('0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73');
    const creal = await IERC20.at('0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787');
    const moo = await IERC20.at('0x17700282592D6917F6A73D0bF8AcCf4D578c131e');

    const celoAmount = '8126913980204805125286141';
    const cusdAmount = '644523140000000000000000';
    const ceurAmount = '765106120000000000000000';
    const crealAmount = '170000000000000000000';
    const mooAmountFromMultisig = '1852549484486574642012200';
    const mooAmountFromOwnedWallet = '9000000000000000000000000';
    IOwnedWallet.autoGas = false;
    const ownedWallet = await IOwnedWallet.at(
      '0x313bc86D3D6e86ba164B2B451cB0D9CfA7943e5c'
    );

    // console.log(await balanceOf(celo, multisig));
    // console.log(await balanceOf(cusd, multisig));
    // console.log(await balanceOf(ceur, multisig));
    // console.log(await balanceOf(creal, multisig));
    // console.log(await balanceOf(moo, multisig));

    // console.log(await balanceOf(celo, ownedWallet.address));
    // console.log(await balanceOf(cusd, ownedWallet.address));
    // console.log(await balanceOf(ceur, ownedWallet.address));
    // console.log(await balanceOf(creal, ownedWallet.address));
    // console.log(await balanceOf(moo, ownedWallet.address));

    // console.log(await balanceOf(celo, moolaFixAddress));
    // console.log(await balanceOf(cusd, moolaFixAddress));
    // console.log(await balanceOf(ceur, moolaFixAddress));
    // console.log(await balanceOf(creal, moolaFixAddress));
    // console.log(await balanceOf(moo, moolaFixAddress));

    // transfer all needed amount to OwnedWallet to later be used in MoolaFix
    if (await balanceOf(celo, multisig) != '0') {
      await celo.transfer(ownedWallet.address, celoAmount, { from: multisig, gasPrice: 0 });
      await cusd.transfer(ownedWallet.address, cusdAmount, { from: multisig, gasPrice: 0 });
      await ceur.transfer(ownedWallet.address, ceurAmount, { from: multisig, gasPrice: 0 });
      await creal.transfer(ownedWallet.address, crealAmount, { from: multisig, gasPrice: 0 });
      await moo.transfer(ownedWallet.address, mooAmountFromMultisig, { from: multisig, gasPrice: 0 });
    }

    // OwnedWallet steps:
    // 1. Transfer Tokens to MoolaFix
    // 2. Transfer AddressesProvider owner to MoolaFix
    // 3. Call MoolaFix.execute()

    await ownedWallet.executeMany(
      [
        celo.address,
        cusd.address,
        ceur.address,
        creal.address,
        moo.address,

        addressesProvider.address,
        moolaFixAddress,
      ],
      [0, 0, 0, 0, 0, 0, 0],
      [
        (await celo.transfer.request(moolaFixAddress, celoAmount)).data,
        (await cusd.transfer.request(moolaFixAddress, cusdAmount)).data,
        (await ceur.transfer.request(moolaFixAddress, ceurAmount)).data,
        (await creal.transfer.request(moolaFixAddress, crealAmount)).data,
        (await moo.transfer.request(moolaFixAddress, mooAmountFromOwnedWallet)).data,

        (await addressesProvider.transferOwnership.request(moolaFixAddress)).data,
        (await moolaFix.execute.request()).data,
      ],
      { from: multisig, gasPrice: 0, gas: 19000000 }
    );
    // console.log(await balanceOf(celo, moolaFixAddress));
    // console.log(await balanceOf(cusd, moolaFixAddress));
    // console.log(await balanceOf(ceur, moolaFixAddress));
    // console.log(await balanceOf(creal, moolaFixAddress));
    // console.log(await balanceOf(moo, moolaFixAddress));
  });
});
