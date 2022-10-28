const AToken = artifacts.require('AToken');
const LendingPoolAddressesProvider = artifacts.require(
  'LendingPoolAddressesProvider'
);
const ATokenWithTransferForMoolaFix = artifacts.require(
  'ATokenWithTransferForMoolaFix'
);
const LendingPoolWithGracePeriod = artifacts.require(
  'LendingPoolWithGracePeriod'
);
const LendingPoolWithUpdateLiquidityIndex = artifacts.require(
  'LendingPoolWithUpdateLiquidityIndex'
);
const DefaultReserveInterestRateStrategy = artifacts.require(
  'DefaultReserveInterestRateStrategy'
);
const GenericLogic = artifacts.require('GenericLogic');
const ReserveLogic = artifacts.require('ReserveLogic');
const ReserveLogicNoInterest = artifacts.require('ReserveLogicNoInterest');
const ValidationLogic = artifacts.require('ValidationLogic');
const MoolaFix = artifacts.require('MoolaFix');

module.exports = async function (deployer) {
  const addressProviderAddress = '0xD1088091A174d33412a968Fa34Cb67131188B332';

  await deployer.deploy(AToken);
  await deployer.deploy(ATokenWithTransferForMoolaFix);
  await deployer.deploy(GenericLogic);

  await deployer.link(GenericLogic, ReserveLogic);
  await deployer.link(GenericLogic, ReserveLogicNoInterest);
  await deployer.link(GenericLogic, ValidationLogic);

  await deployer.deploy(ReserveLogic);
  await deployer.deploy(ReserveLogicNoInterest);
  await deployer.deploy(ValidationLogic);

  await deployer.link(ReserveLogic, LendingPoolWithGracePeriod);
  await deployer.link(ValidationLogic, LendingPoolWithGracePeriod);
  await deployer.link(ReserveLogicNoInterest, LendingPoolWithUpdateLiquidityIndex);
  await deployer.link(ValidationLogic, LendingPoolWithUpdateLiquidityIndex);

  await deployer.deploy(LendingPoolWithUpdateLiquidityIndex);
  await deployer.deploy(LendingPoolWithGracePeriod);

  const aTokenWithTransferForMoolaFix =
    await ATokenWithTransferForMoolaFix.deployed();
  const aAToken = await AToken.deployed();
  const lendingPoolWithUpdateLiquidityIndex =
    await LendingPoolWithUpdateLiquidityIndex.deployed();
  const lendingPoolWithGracePeriod =
    await LendingPoolWithGracePeriod.deployed();

  console.log(
    '  arguments: ',
    aTokenWithTransferForMoolaFix.address,
    aAToken.address,
    lendingPoolWithUpdateLiquidityIndex.address,
    lendingPoolWithGracePeriod.address
  );
  await deployer.deploy(
    MoolaFix,
    aTokenWithTransferForMoolaFix.address,
    aAToken.address,
    lendingPoolWithUpdateLiquidityIndex.address,
    lendingPoolWithGracePeriod.address
  );
};
