// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import 'hardhat/console.sol';

import '../dependencies/openzeppelin/contracts/SafeMath.sol';
import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';
import '../protocol/configuration/LendingPoolAddressesProvider.sol';
import '../protocol/lendingpool/LendingPoolConfigurator.sol';
import '../interfaces/ILendingPoolConfigurator.sol';
import '../protocol/lendingpool/LendingPool.sol';
import '../dependencies/openzeppelin/contracts/IERC20.sol';
import './ATokenWithTransferForMoolaFix.sol';
import '../protocol/tokenization/AToken.sol';
import './LendingPoolWithGracePeriod.sol';
import './LendingPoolWithUpdateLiquidityIndex.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';
import {Errors} from '../protocol/libraries/helpers/Errors.sol';

interface IUbeswapPair {
  function sync() external;
}

contract MoolaFix is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address constant lendingPoolConfiguratorAddress = 0x928F63a83217e427A84504950206834CBDa4Aa65;
  LendingPoolConfigurator constant lendingPoolConfigurator =
    LendingPoolConfigurator(lendingPoolConfiguratorAddress);

  address constant lendingPoolAddressesProviderAddress = 0xD1088091A174d33412a968Fa34Cb67131188B332;
  LendingPoolAddressesProvider constant addressesProvider =
    LendingPoolAddressesProvider(lendingPoolAddressesProviderAddress);

  address constant lendingPoolAddress = 0x970b12522CA9b4054807a2c5B736149a5BE6f670;
  LendingPool constant lendingPool = LendingPool(lendingPoolAddress);

  address constant mCeloMooPool = 0x9272388FDf2D6bFbA8b1Cdd99732A3D552a71346;

  address immutable newATokenImplementation;
  address immutable originalATokenImplementation;
  address immutable lendingPoolWithUpdateLiquityIndexAddress;
  address immutable lendingPoolImplWithGracePeriodEnabled;

  address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;
  address constant cUSD = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
  address constant cEUR = 0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73;
  address constant cREAL = 0xe8537a3d056DA446677B9E9d6c5dB704EaAb4787;
  address constant MOO = 0x17700282592D6917F6A73D0bF8AcCf4D578c131e;

  address immutable mCELO;
  address immutable mcUSD;
  address immutable mcEUR;
  address immutable mcREAL;
  address immutable mMOO;

  address immutable mceloStableDebt;
  address immutable mceloVariableDebt;

  address immutable mcusdStableDebt;
  address immutable mcusdVariableDebt;

  address immutable mceurStableDebt;
  address immutable mceurVariableDebt;

  address immutable mcrealStableDebt;
  address immutable mcrealVariableDebt;

  address immutable mmooStableDebt;
  address immutable mmooVariableDebt;

  address constant OwnedWallet = 0x313bc86D3D6e86ba164B2B451cB0D9CfA7943e5c;
  address constant incentivesController = 0x0000000000000000000000000000000000000000;
  bytes constant tokenParams = '0x10';

  address constant exploiterAddress = 0x5DAE2C3d5a9f35bFaf36A2E6edD07c477f57789e;

  string constant mceloName = 'Moola interest bearing CELO';
  string constant mceloSymbol = 'mCELO';
  string constant mcusdName = 'Moola interest bearing CUSD';
  string constant mcusdSymbol = 'mCELO';
  string constant mceurName = 'Moola interest bearing CEUR';
  string constant mceurSymbol = 'mCEUR';
  string constant mcrealName = 'Moola interest bearing CREAL';
  string constant mcrealSymbol = 'mCREAL';
  string constant mmooName = 'Moola interest bearing MOO';
  string constant mmooSymbol = 'mMOO';

  struct Debt {
    address account;
    uint96 debt;
  }

  struct IllGain {
    address account;
    uint96 gain;
  }

  // storing celo and ceur bad debt account => amount because they cannot be fully repaid, will need to know the account and amount to burn debt tokens and update liquidity index
  struct Mem {
    Debt[2] celo;
    Debt[7] ceur;
  }

  constructor(
    address _newATokenImplementation,
    address _originalATokenImplementation,
    address _lendingPoolWithUpdateLiquityIndexAddress,
    address _lendingPoolImplWithGracePeriodEnabled
  ) public {
    newATokenImplementation = _newATokenImplementation;
    originalATokenImplementation = _originalATokenImplementation;
    lendingPoolWithUpdateLiquityIndexAddress = _lendingPoolWithUpdateLiquityIndexAddress;
    lendingPoolImplWithGracePeriodEnabled = _lendingPoolImplWithGracePeriodEnabled;

    transferOwnership(OwnedWallet);

    IERC20(CELO).approve(lendingPoolAddress, type(uint256).max);
    IERC20(cUSD).approve(lendingPoolAddress, type(uint256).max);
    IERC20(cEUR).approve(lendingPoolAddress, type(uint256).max);
    IERC20(cREAL).approve(lendingPoolAddress, type(uint256).max);
    IERC20(MOO).approve(lendingPoolAddress, type(uint256).max);

    DataTypes.ReserveData memory celoReserveData = lendingPool.getReserveData(CELO);
    DataTypes.ReserveData memory cusdReserveData = lendingPool.getReserveData(cUSD);
    DataTypes.ReserveData memory ceurReserveData = lendingPool.getReserveData(cEUR);
    DataTypes.ReserveData memory crealReserveData = lendingPool.getReserveData(cREAL);
    DataTypes.ReserveData memory mooReserveData = lendingPool.getReserveData(MOO);

    mCELO = celoReserveData.aTokenAddress;
    mcUSD = cusdReserveData.aTokenAddress;
    mcEUR = ceurReserveData.aTokenAddress;
    mcREAL = crealReserveData.aTokenAddress;
    mMOO = mooReserveData.aTokenAddress;

    mceloStableDebt = celoReserveData.stableDebtTokenAddress;
    mceloVariableDebt = celoReserveData.variableDebtTokenAddress;
    mcusdStableDebt = cusdReserveData.stableDebtTokenAddress;
    mcusdVariableDebt = cusdReserveData.variableDebtTokenAddress;
    mceurStableDebt = ceurReserveData.stableDebtTokenAddress;
    mceurVariableDebt = ceurReserveData.variableDebtTokenAddress;
    mcrealStableDebt = crealReserveData.stableDebtTokenAddress;
    mcrealVariableDebt = crealReserveData.variableDebtTokenAddress;
    mmooStableDebt = mooReserveData.stableDebtTokenAddress;
    mmooVariableDebt = mooReserveData.variableDebtTokenAddress;
  }

  function transferToMoolaFix(
    address token,
    address from,
    uint256 amount,
    string memory error
  ) internal {
    try
      ATokenWithTransferForMoolaFix(token).transferForMoolaFixSingle(from, address(this), amount)
    {} catch (bytes memory err) {
      // console.log(error);
      // console.log('transferToMoolaFix');
      // console.log(token);
      // console.log(from);
      // console.log(amount);
      // console.log('balance');
      // console.log(ATokenWithTransferForMoolaFix(token).balanceOf(from));
      assembly {
        revert(add(err, 32), err)
      }
    }
  }

  // For stpe 8/9: trasnfer mCELO, mcUSD, mcEUR from OwnedWallet to MoolaFix for repaying bad debt
  function transferTokensFromOwnedWallet()
    internal
    returns (
      uint256 mCeloTransferAmount,
      uint256 mcUSDTransferAmount,
      uint256 mcEURTransferAmount,
      uint256 mcREALTransferAmount
    )
  {
    mCeloTransferAmount = 1_655_727647999204334996; // ALL
    transferToMoolaFix(
      mCELO,
      OwnedWallet,
      mCeloTransferAmount,
      'MoolaFix: transferTokensFromOwnedWallet mCELO failed'
    );
    mcUSDTransferAmount = 3_792_807757762638659755; // ALL
    transferToMoolaFix(
      mcUSD,
      OwnedWallet,
      mcUSDTransferAmount,
      'MoolaFix: transferTokensFromOwnedWallet mcUSD failed'
    );
    mcEURTransferAmount = 78_104307936956667012; // ALL
    transferToMoolaFix(
      mcEUR,
      OwnedWallet,
      mcEURTransferAmount,
      'MoolaFix: transferTokensFromOwnedWallet mcEUR failed'
    );
    mcREALTransferAmount = 48_578966742446084975; // ALL
    transferToMoolaFix(
      mcREAL,
      OwnedWallet,
      mcREALTransferAmount,
      'MoolaFix: transferTokensFromOwnedWallet mcREAL failed'
    );
  }

  // for step 10: transfer exploiter's all mCELO to MoolaFix
  function transferMceloFromExploiter() internal returns (uint256 mceloAmountFromAttacker) {
    // transfer mCelo from attacker
    uint first = 447_386386370725523222;
    uint second = 1_998_218281124763710708;
    transferToMoolaFix(mCELO, 0x1Df15534d350377732944e5bCE2FE65C5aE6766D, first, 'mCELO Exploiter 1');
    transferToMoolaFix(mCELO, 0xeDFc4dD20A77Dd5E802724576E822Fe1A9Cf27e3, second, 'mCELO Exploiter 2');
    return first + second;
  }

  // for step 11: Transfer mCELO from advantagers (i.e. ULP liquidity removers and traders) to MoolaFix
  function transferMceloFromAdvantagers() internal returns (uint256 totalAmountTransferred) {
    IllGain[11] memory advantagersMcelo = [
      IllGain(0xbbe97c3fa452b95E0A4603Bffbee475dFaD44e3B, 93_120_927152610164336331),
      IllGain(0x9FD3E70FF099d3bf347D469d35A75ca1847177d9, 119_215_462299749841714410),
      IllGain(0x86d208A677DA4F7d460AFcf2bb239B885B0cC451, 11_860_097768889023321286),
      IllGain(0x70Fb402e73FefB025F93E70eaD8cFA0ec8e092Ba, 34_200_000000000000000000), // Has 44_946_635254037394277138, but also has debt.
      IllGain(0x4532CC41475b46f4A12da4f03B806655D2c692fB, 6_578_450000000000000000),
      IllGain(0xd4DC77165051bc2AeAdFf2C8A681B87163E47820, 7_015_470000000000000000),
      IllGain(0x278B972Fc3c3eE80a3e7Da9ea7431c9637161D5B, 918_570000000000000000),
      IllGain(0x65E0d48f7B8eB2f33E8Eb38a33b8Bb4E2C0Be001, 401_320000000000000000),
      IllGain(0x6860Aefc5f684Dc757908De2fb624b44982134a2, 57_110000000000000000),
      IllGain(0x54F95b76E12F848760864b802d0225E31a343d70, 657_144_100000000000000000),
      IllGain(0x3f92B0032cBCA6787D94e2C737F7C7Cd3351aF91, 381_824972519241633264)
    ];

    for (uint i = 0; i < advantagersMcelo.length; i++) {
      transferToMoolaFix(mCELO, advantagersMcelo[i].account, advantagersMcelo[i].gain, "transferMceloFromAdvantagers failed");
      totalAmountTransferred += advantagersMcelo[i].gain;
    }
    return totalAmountTransferred;
  }

  // for step 13: Deposit MOO token and transfer mCELO from the mCELO-MOO pool to MoolaFix to reset mCELO-MOO ratio
  function transferMceloFromAndDepositMooToPool() internal returns (uint256 mceloFromPool) {
    // transfer mCELO from pool to MoolaFix
    mceloFromPool = 675_929_253603686065263591;

    transferToMoolaFix(
      mCELO,
      mCeloMooPool,
      mceloFromPool,
      'MoolaFix:transferMceloFromAndDepositMooToPool: mCelo transfer failed'
    );

    // transfer MOO from MoolaFix into pool
    uint256 mooDepositAmountToPool = 2_461_294_965967200813100394;
    IERC20(MOO).transfer(mCeloMooPool, mooDepositAmountToPool);

    // call sync() to reset the ratio in the pool
    try IUbeswapPair(mCeloMooPool).sync() {} catch (bytes memory) {
      revert('MoolaFix:transferMceloFromAndDepositMooToPool: mCELO-MOO pool sync failed.');
    }
  }

  // needed after done with all actions related to transferring mToken from attecker and advantagers, this resets the mToken impl
  function setMtokenImpl(address implementation) internal {
    // revert mCelo to original
    ILendingPoolConfigurator.UpdateATokenInput memory mceloRevertInput = ILendingPoolConfigurator
      .UpdateATokenInput(
        CELO,
        OwnedWallet,
        incentivesController,
        mceloName,
        mceloSymbol,
        implementation,
        tokenParams
      );
    lendingPoolConfigurator.updateAToken(mceloRevertInput);

    ILendingPoolConfigurator.UpdateATokenInput memory mcusdRevertInput = ILendingPoolConfigurator
      .UpdateATokenInput(
        cUSD,
        OwnedWallet,
        incentivesController,
        mcusdName,
        mcusdSymbol,
        implementation,
        tokenParams
      );
    lendingPoolConfigurator.updateAToken(mcusdRevertInput);

    ILendingPoolConfigurator.UpdateATokenInput memory mceurRevertInput = ILendingPoolConfigurator
      .UpdateATokenInput(
        cEUR,
        OwnedWallet,
        incentivesController,
        mceurName,
        mceurSymbol,
        implementation,
        tokenParams
      );
    lendingPoolConfigurator.updateAToken(mceurRevertInput);

    ILendingPoolConfigurator.UpdateATokenInput memory mcrealRevertInput = ILendingPoolConfigurator
      .UpdateATokenInput(
        cREAL,
        OwnedWallet,
        incentivesController,
        mcrealName,
        mcrealSymbol,
        implementation,
        tokenParams
      );
    lendingPoolConfigurator.updateAToken(mcrealRevertInput);

    // revert mMOO to original
    ILendingPoolConfigurator.UpdateATokenInput memory mooRevertInput = ILendingPoolConfigurator
      .UpdateATokenInput(
        MOO,
        OwnedWallet,
        incentivesController,
        mmooName,
        mmooSymbol,
        implementation,
        tokenParams
      );
    lendingPoolConfigurator.updateAToken(mooRevertInput);
  }

  // iterate through celoBadDebtAccounts and ceurBadDebtAccounts, burn all bad debt token of the accounts that cannot be repaid
  function writeOffBadDebt(Mem memory mem) internal returns (uint256 celoBadDebtBurnt, uint256 ceurBadDebtBurnt) {
    // celo

    for (uint256 i = 0; i < mem.celo.length; i++) {
      uint256 burnt = burnOneAccountBadDebt(
        CELO,
        mceloVariableDebt,
        mceloStableDebt,
        mem.celo[i].account,
        mem.celo[i].debt
      );
      celoBadDebtBurnt = celoBadDebtBurnt.add(burnt);
    }

    // ceur

    for (uint256 i = 0; i < mem.ceur.length; i++) {
      uint256 burnt = burnOneAccountBadDebt(
        cEUR,
        mceurVariableDebt,
        mceurStableDebt,
        mem.ceur[i].account,
        mem.ceur[i].debt
      );
      ceurBadDebtBurnt = ceurBadDebtBurnt.add(burnt);
    }
  }

  function updateDebtTokenImpl(
    address asset,
    string memory stableName,
    string memory stableSymbol,
    string memory variableName,
    string memory variableSymbol,
    address stableImpl,
    address variableImpl
  ) internal {
    ILendingPoolConfigurator.UpdateDebtTokenInput memory stableInput = ILendingPoolConfigurator
      .UpdateDebtTokenInput(
        asset,
        incentivesController,
        stableName,
        stableSymbol,
        stableImpl,
        tokenParams
      );
    ILendingPoolConfigurator.UpdateDebtTokenInput memory variableInput = ILendingPoolConfigurator
      .UpdateDebtTokenInput(
        asset,
        incentivesController,
        variableName,
        variableSymbol,
        variableImpl,
        tokenParams
      );

    lendingPoolConfigurator.updateVariableDebtToken(variableInput);
    lendingPoolConfigurator.updateStableDebtToken(stableInput);
  }

  function requireBalance(
    address token,
    uint256 balance,
    string memory error
  ) internal view {
    require(IERC20(token).balanceOf(address(this)) >= balance, error);
  }

  // for step 12: Transfer MOO from MoolaFix to advantagers
  function transferMooToAdvantagers() internal {
    requireBalance(
      MOO,
      2_393_718_942463223448120007,
      'MoolaFix: not enough MOO for transferMooToAdvantagers'
    );

    IllGain[10] memory toAdvantagersMoo = [
      IllGain(0xbbe97c3fa452b95E0A4603Bffbee475dFaD44e3B, 22_620_415311425833000000),
      IllGain(0x9FD3E70FF099d3bf347D469d35A75ca1847177d9, 33_325_450585013636917729),
      IllGain(0x86d208A677DA4F7d460AFcf2bb239B885B0cC451, 3_421_645084954286261176),
      IllGain(0x4532CC41475b46f4A12da4f03B806655D2c692fB, 10178_000000000000000000),
      IllGain(0xd4DC77165051bc2AeAdFf2C8A681B87163E47820, 10900_340000000000000000),
      IllGain(0x278B972Fc3c3eE80a3e7Da9ea7431c9637161D5B, 1469_700000000000000000),
      IllGain(0x65E0d48f7B8eB2f33E8Eb38a33b8Bb4E2C0Be001, 1308_120000000000000000),
      IllGain(0x6860Aefc5f684Dc757908De2fb624b44982134a2, 207_430000000000000000),
      IllGain(0x54F95b76E12F848760864b802d0225E31a343d70, 2_283_957_000000000000000000),
      IllGain(0x3f92B0032cBCA6787D94e2C737F7C7Cd3351aF91, 121_194297701153499321)
    ];

    for (uint256 i = 0; i < toAdvantagersMoo.length; i++) {
      IERC20(MOO).transfer(toAdvantagersMoo[i].account, toAdvantagersMoo[i].gain);
    }
  }

  // for step 18: Update the liquidity indexes of MToken holders to account for bad debt
  function updateLiquidityIndex(uint256 remainingMCeloDebtAmount, uint256 remainingMceurDebtAmount)
    internal
  {
    LendingPoolWithUpdateLiquidityIndex updatedLendingPool = LendingPoolWithUpdateLiquidityIndex(
      lendingPoolAddress
    );
    updatedLendingPool.updateLiquidtyIndexForLoss(CELO, remainingMCeloDebtAmount);
    updatedLendingPool.updateLiquidtyIndexForLoss(cEUR, remainingMceurDebtAmount);
  }

  // for step 22: Enable grace period (pause withdraw, borrow, liquidations) by adding a modifier disabledDuringGracePeriod on all actions on LendingPool that have "whenNotPaused" except deposit and repay
  function enableGracePeriodOnLendingPool() internal {
    addressesProvider.setLendingPoolImpl(lendingPoolImplWithGracePeriodEnabled);
  }

  // for step 14: Repay for exploiter's debt in CELO, cUSD, cEUR using all balance in MoolaFix
  function firstRoundRepay(Mem memory mem) internal {
    uint256 celoRepayAmount = 8_126_913_980204805125286141;
    uint256 cusdRepayAmount = 644_523_140000000000000000;
    uint256 ceurRepayAmount = 765_106_120000000000000000;

    // console.log('CELO balance', IERC20(CELO).balanceOf(address(this)));
    lendingPool.repay(CELO, celoRepayAmount, 2, exploiterAddress);
    // console.log('cUSD balance', IERC20(cUSD).balanceOf(address(this)));
    // console.log('cUSD debt before repay', IERC20(mcusdVariableDebt).balanceOf(exploiterAddress));
    lendingPool.repay(cUSD, cusdRepayAmount, 2, exploiterAddress);
    // console.log('cUSD debt after repay', IERC20(mcusdVariableDebt).balanceOf(exploiterAddress));
    // console.log('cEUR balance', IERC20(cEUR).balanceOf(address(this)));
    lendingPool.repay(cEUR, ceurRepayAmount, 2, exploiterAddress);

    // reduce the remaining bad debt amounts in the mappings to keep a record of how much bad debt are still remaining
    mem.celo[mem.celo.length - 1].debt = uint96(uint(mem.celo[mem.celo.length - 1].debt).sub(celoRepayAmount));
    mem.ceur[mem.ceur.length - 1].debt = uint96(uint(mem.ceur[mem.ceur.length - 1].debt).sub(ceurRepayAmount));
  }

  function logBalances() view internal {
    // console.log('moolafix balances');
    // console.log('celo', IERC20(CELO).balanceOf(address(this)));
    // console.log('cusd', IERC20(cUSD).balanceOf(address(this)));
    // console.log('ceur', IERC20(cEUR).balanceOf(address(this)));
    // console.log('creal', IERC20(cREAL).balanceOf(address(this)));
    // console.log('moo', IERC20(MOO).balanceOf(address(this)));
    // console.log('mcelo', IERC20(mCELO).balanceOf(address(this)));
    // console.log('mcusd', IERC20(mcUSD).balanceOf(address(this)));
    // console.log('mceur', IERC20(mcEUR).balanceOf(address(this)));
    // console.log('mmoo', IERC20(mMOO).balanceOf(address(this)));
  }

  // for Step 16 Second repayment of exploiter's bad debt in CELO / cEUR / MOO, and everyone's bad debt in cUSD, cREAL, MOO
  function secondRoundRepay(Mem memory mem) internal {
    uint256 totalCeloAvailableAmount = IERC20(CELO).balanceOf(address(this));

    logBalances();
    // repay for everyone's celo, ceur debt, including the attacker's remaining debt amount. Bad debt in these 2 assets will not be repaid fully
    // update the remaining bad debt numbers in accountToCeloBadDebt and accountToCeurBadDebt mapping to know how much bad debt are left that need to be burnt
    for (uint256 i = 0; i < mem.celo.length; i++) {
      address repayAccount = mem.celo[i].account;
      uint256 repayAmount = mem.celo[i].debt;
      if (totalCeloAvailableAmount == 0) {
        break;
      }
      if (repayAmount > totalCeloAvailableAmount) {
        repayAmount = totalCeloAvailableAmount;
      }
      uint256 repaidAmount = repayOneAccountBadDebt(
        CELO,
        mceloVariableDebt,
        mceloStableDebt,
        repayAccount,
        repayAmount
      );
      totalCeloAvailableAmount = totalCeloAvailableAmount.sub(repaidAmount);
      mem.celo[i].debt = uint96(uint(mem.celo[i].debt).sub(repaidAmount));
    }

    uint256 totalCeurAvailableAmount = IERC20(cEUR).balanceOf(address(this));
    for (uint256 i = 0; i < mem.ceur.length; i++) {
      address repayAccount = mem.ceur[i].account;
      uint256 repayAmount = mem.ceur[i].debt;
      if (totalCeurAvailableAmount == 0) {
        break;
      }
      if (repayAmount > totalCeurAvailableAmount) {
        repayAmount = totalCeurAvailableAmount;
      }
      uint256 repaidAmount = repayOneAccountBadDebt(
        cEUR,
        mceurVariableDebt,
        mceurStableDebt,
        repayAccount,
        repayAmount
      );
      totalCeurAvailableAmount = totalCeurAvailableAmount.sub(repaidAmount);
      mem.ceur[i].debt = uint96(uint(mem.ceur[i].debt).sub(repaidAmount));
    }

    // Those with debt value < 0.1 are excluded to fit transaction into a block.
    // repay for everyone's cusd, creal, moo debt, all bad debt will be repaid fully
    Debt[18] memory cusdBadDebts = [
      // Debt(0x530D27a6EC2063237909B2c758759AA693797A9C, 2447677037234280),
      // Debt(0xc313B1AaBbB26E8B1f3Ea8e94dCfc260ecab58ff, 224434987632907),
      Debt(0x63826928e81E7b7421928A27fe43Aa24779bD534, 1_474784263319849839),
      // Debt(0xbCf31A6Eb94Bf6450358992e81A526c7A02fD332, 2410228572885440),
      Debt(0x35526705230f795C5ed433891952a25c5aefB861, 336098358142651401),
      // Debt(0x8AffafE32705f3BA043CA11B240c5010748Aa2F2, 875634953784077),
      Debt(0x2D678940F979815f6B3E65816697Bc7093CDf374, 145225770570570508),
      // Debt(0xfB8CF7100B4E46Bb4feffF1EF13ff59834f2884D, 39575930541323),
      // Debt(0xA027751946f97DD7847C5a75fA4677E5Eb3eBcCa, 661574746636),
      // Debt(0x0bE8ffE44bE281708A7DDe13Af68120fD4c974ea, 49298014739234656),
      // Debt(0x9B1dfF66d21D3b099d1819d3526eA23DD05f9E24, 3664689686115345),
      // Debt(0x28EC929A839663d1b9C527C6B5169a44bF8874CE, 2789136995806296),
      Debt(0x7C5BA47745c42dA90Fc777FF349E8Ae3f7688ca5, 155516562655215208),
      // Debt(0xB1Bd9dd2c910EbC52Fd85a6224F4BE29970Ca6AC, 258260822858410),
      // Debt(0x156Dd464e12B6E0E4141051B9a2e885A040898b3, 994386616639496),
      // Debt(0x16C5951d53E2A548a6C515351AEeC1Dc86435b52, 115664071728346),
      // Debt(0x309e1f58710F0217114Becc7c401F88b2dC794D7, 9015702224230),
      // Debt(0xDBb6bC3b01d65eA15E6ac919461D9A7E9Cd4f015, 42617684887135465),
      // Debt(0x63678999c2152Af43bB2F3E06D1C0a1A0CBC7FFC, 5919169829509),
      Debt(0xf4788fF714729F15A233233241806217a3b4eb54, 1_680172534170049014),
      // Debt(0x04B57E13963cb1D97E0da6Ba34e5F8866e0d3f99, 4557160616586),
      Debt(0xb13f760bEf3cDd7aF3Fdbc6455243B0512E673bb, 513046386072598241),
      // Debt(0x902a3Ff7522963a352458b543A522291aE1563c2, 776813274826769),
      Debt(0x200c815702b0376befe68c2c71701929799063c1, 1_775720222188384203),
      Debt(0x64a35288bbc2b113f979893921a6832993324644, 286216933397485949),
      // Debt(0xb621dba5aAA1092CbBE4C9b3cE08FD1808FAd096, 1365040482028888),
      // Debt(0x24201abB25d37DeB650BCc12C2b671eE765Ba2A8, 74942707283354676),
      Debt(0xDBe729650e697E04e99345E568f450c443a10309, 4_532056329935100228),
      // Debt(0xe631c55401FfF31e2797EAA0df327dB8E2a4E7C9, 30878771962572634),
      // Debt(0x7F11C91f3f3088C3fF0e983F55ebe83d2e3C5AE6, 29722902568142),
      // Debt(0x2D32D10e9B903102dbC0FF99C5D25e6b333e15B2, 1007572179259133),
      // Debt(0x926b3DC71Fb55CebDDED307A5f4F737edca93149, 608593136140849),
      // Debt(0x6EDa5bB8A40206E805E98d86D8F4486041AdE4c5, 697648819623704),
      // Debt(0xb8c1E2ef920E3a3162657696c3D86B2D0598562A, 1576624914334790),
      Debt(0xdE5D3956160AC0a6F12Cf80632fdCe4b9BDA4837, 1_695318783751585387),
      // Debt(0x0C502fFC944bFf5a87691cB4Cf9285f1Aa829f43, 21343342873141),
      Debt(0x8BAbBbd8a1Fbc600f27761b571e451a4D5AE1756, 6_897050963106151329),
      // Debt(0x10a5A4961cEbed6E86C9Ff8744e4F2360BF160AA, 885381772043104),
      // Debt(0xf3472174fa006A0bed9319651D624bC5B938dE19, 26710146503791826),
      // Debt(0xD657d64EaF9387Ad3829163e93b0CaA98d29f826, 1446782937653611),
      // Debt(0x80dFad37dDE8Db3b0fF8ddC6E35F02DE4fD3fF53, 1977370067648578),
      // Debt(0xaB26641fbf3Fd29D8659758193585C8817125876, 625406458311796),
      // Debt(0x94B2e058Ef4E4c56a7105ac5a6784774b18Df25C, 445455328985769),
      Debt(0xc278C9D375bC453B38006eA339325E462C2D9C60, 51_026934351617644061),
      Debt(0x0C266223C8dB48cA1238103f5bD8772146F860a3, 197336643700190304),
      Debt(0xD9215a154Cb0148451fD418da07D8842F3cd7e59, 403384730405633595),
      // Debt(0x276FCe7A3521a4e3492F1E8e5feB835eB0b13096, 2654908278416105),
      // Debt(0xdFe8bbBB231e1C5dB90d2d8dfE95CE07f2113F3e, 3377530940231867),
      Debt(0x5C22CE6FCAaab070054bBe17e963c58543D04d93, 472_124328189291684740),
      Debt(0x720E5D6f26A2780c0015580CAcCD28FE1E3D89cF, 319968324803052809),
      // Debt(0xfC3db2eF7Fcf386CcAC6262Ab5Ad7F6518d6E500, 3115854161176229),
      Debt(0xF38560b3EF42A677f9155569D5214802C3415fF5, 114_961302065122736295),
      // Debt(0x6328Ddc9df14ADFDF0a4bec752bF91523d8D5cf5, 4161380885568620),
      Debt(exploiterAddress, 644_578_143432907564741586)
    ];

    for (uint256 i = 0; i < cusdBadDebts.length; i++) {
      repayOneAccountBadDebt(
        cUSD,
        mcusdVariableDebt,
        mcusdStableDebt,
        cusdBadDebts[i].account,
        cusdBadDebts[i].debt
      );
    }

    Debt[2] memory crealBadDebts = [
      // Debt(0x7C5BA47745c42dA90Fc777FF349E8Ae3f7688ca5, 68291033133483557),
      Debt(0xB5d3a65803E87756c997679453DD9d92556314e2, 289570977399798342),
      // Debt(0xdfdc7300AB9Ef82BB413805d6Dcea23Df07fdc10, 33119088772203),
      // Debt(0x97F8A86531Cdbe33c94921Fe8b497955b19887Fa, 14525733133439755),
      // Debt(0x125FaACD642bDcA6A4f1919f618BD3a68168925C, 5388867808614434),
      // Debt(0x5964B615bEfBe77F229b0662d9880D8963bD997D, 82065780863463065),
      Debt(0xF38560b3EF42A677f9155569D5214802C3415fF5, 170_282258987749346387)
    ];

    for (uint256 i = 0; i < crealBadDebts.length; i++) {
      repayOneAccountBadDebt(
        cREAL,
        mcrealVariableDebt,
        mcrealStableDebt,
        crealBadDebts[i].account,
        crealBadDebts[i].debt
      );
    }

    Debt[16] memory mooBadDebts = [
      // Debt(0x7C5BA47745c42dA90Fc777FF349E8Ae3f7688ca5, 99984214439),
      Debt(0xA0BdA5d71291f391A71bF2d695b4Ea620AC7B0E6, 65_611162059784683624),
      Debt(0x7B167C2Ca7A13757331B2F124EB52a46d43C416C, 137073872284927792),
      Debt(0x9eb664b0f2278aed42BE6F35EB58Da1C4C470952, 11_022_806534770056168733),
      Debt(0xB5d3a65803E87756c997679453DD9d92556314e2, 308486916923631318),
      Debt(0xdfdc7300AB9Ef82BB413805d6Dcea23Df07fdc10, 593472974527412096),
      // Debt(0x62Ba54EeE636987dC13Ad88600c3fb0F4F228CD1, 11614015440136653),
      Debt(0xD9215a154Cb0148451fD418da07D8842F3cd7e59, 70_935039656090390506),
      // Debt(0x24758Bf40BDeF801a680EA35Fa090Ec66CADdC9c, 16344940236140821),
      Debt(0xAc4B966e4e01662DccA10f96a05415d31efCB761, 595431985255603069),
      Debt(0xdFe8bbBB231e1C5dB90d2d8dfE95CE07f2113F3e, 42_027134246275478731),
      // Debt(0x47020d3dF05a272349D04319B327F5173f61cBA2, 247927025692551),
      Debt(0x97F8A86531Cdbe33c94921Fe8b497955b19887Fa, 9_710815065905166657),
      // Debt(0x99411EBAA7fc5c53A4519e5C81fc04EB67F7D292, 23531775010714436),
      Debt(0x60dE7F647dF2448eF17b9E0123411724De6e373D, 2_112970618556644040),
      // Debt(0x125FaACD642bDcA6A4f1919f618BD3a68168925C, 2674220019419703),
      Debt(0x7930C009F33cd6324529c34728C2EE8BD2c06b69, 165154580783568248),
      // Debt(0xEe47be7A2Aa7952B4C4d8067Baa76cADFf21e643, 12546091700797),
      // Debt(0x5964B615bEfBe77F229b0662d9880D8963bD997D, 95697872172336413),
      Debt(0xF38560b3EF42A677f9155569D5214802C3415fF5, 1_485_062165177141974589),
      Debt(0x1Df15534d350377732944e5bCE2FE65C5aE6766D, 1_857_856_435642747156059627), // Repaid separately.
      Debt(0x37F9b381B74B2Ebd0EF38EDf2B9d99946b44B8A5, 5_203769781467740524),
      // Debt(0x1060730685E443Dfbb4Bd8C6DD058d2122a553D6, 89969856671161670),
      // Debt(0x2293207BcE35c44C36E191C3c784ED57383CA1De, 95383661993252547),
      Debt(0x54dA11a90d36F292B3a995D1A447dFE6923cF454, 5_079058256740697062),
      Debt(exploiterAddress, 251_787_209718779806092340)
    ];

    for (uint256 i = 0; i < mooBadDebts.length; i++) {
      repayOneAccountBadDebt(
        MOO,
        mmooVariableDebt,
        mmooStableDebt,
        mooBadDebts[i].account,
        mooBadDebts[i].debt
      );
    }
  }

  // for step 23, test grace period actions, should be able to deposit and repay, but cannot borrow, withdraw, liquidationCall
  function testGracePeriodActions() internal {
    uint256 testAmount = 1e18;
    address testAcount = 0xb3208649Fa0835368EfeD20b686402B60497475f;
    lendingPool.deposit(cUSD, testAmount, address(this), 0);
    lendingPool.repay(cUSD, 0.05 * 1e18, 2, testAcount);

    try IERC20(mcUSD).transfer(OwnedWallet, testAmount / 2) {
      revert('Should not allow transfers');
    } catch {}
    try lendingPool.borrow(CELO, 0.1 * 1e18, 2, 0, address(this)) {
      revert('Should not allow borrow');
    } catch {}
    try lendingPool.withdraw(cUSD, testAmount, address(this)) {
      revert('Should not allow withdraw');
    } catch {}
    try lendingPool.liquidationCall(CELO, cUSD, testAcount, 0.1 * 1e18, false) {
      revert('Should not allow liquidationCall');
    } catch Error(string memory revertReason) {
      // console.log(revertReason);
      require(
        keccak256(abi.encodePacked(revertReason)) ==
          keccak256(
            abi.encodePacked(
              'The protocol is on grace period and it only allows deposit and repay.'
            )
          ),
        'Invalid revert reason for liquidation'
      );
    }
  }

  function testFrozenMoo() internal {
    uint256 testAmount = 1e18;
    address testAcount = 0xF3f8d518347a3F46E8a3cDb4207fB92e177Be5e2;

    lendingPool.repay(MOO, 0.05 * 1e18, 2, testAcount);
    IERC20(mMOO).transfer(OwnedWallet, testAmount / 2);
    lendingPool.withdraw(MOO, testAmount / 2, address(this));
    try lendingPool.liquidationCall(MOO, cEUR, 0x8f3ea6acaa7faFF240A088ffFeae3A404F4018B4, 0.1 * 1e18, false) {
      revert('Should not allow liquidationCall');
    } catch Error(string memory revertReason) {
      // console.log(revertReason);
      require(
        keccak256(abi.encodePacked(revertReason)) ==
          keccak256(
            abi.encodePacked(
              Errors.LP_LIQUIDATION_CALL_FAILED
            )
          ),
        'Liquidation should be allowed'
      );
    }

    try lendingPool.deposit(MOO, testAmount, address(this), 0) {
      revert('Should not allow deposits');
    } catch {}
    try lendingPool.borrow(MOO, 0.01 * 1e18, 2, 0, address(this)) {
      revert('Should not allow borrow');
    } catch {}
  }

  function populateMem() internal pure returns(Mem memory mem) {
    mem.celo = [
      // Debt(0xbCf31A6Eb94Bf6450358992e81A526c7A02fD332, 1312364060849360),
      // Debt(0x2D32D10e9B903102dbC0FF99C5D25e6b333e15B2, 424078912462672),
      // Debt(0xb621dba5aAA1092CbBE4C9b3cE08FD1808FAd096, 9540276164),
      // Debt(0x9eb664b0f2278aed42BE6F35EB58Da1C4C470952, 3148574194397373),
      Debt(0x0C266223C8dB48cA1238103f5bD8772146F860a3, 126987237838906220),
      // Debt(0x62Ba54EeE636987dC13Ad88600c3fb0F4F228CD1, 2624935728067455),
      // Debt(0x97F8A86531Cdbe33c94921Fe8b497955b19887Fa, 156795942465707),
      // Debt(0x5964B615bEfBe77F229b0662d9880D8963bD997D, 221356652516165),
      // Debt(0x7930C009F33cd6324529c34728C2EE8BD2c06b69, 1840596701568063),
      // Debt(0xB5c4362fC8a4ef81de4153f5565a39BA8515008C, 62537987276984),
      // Debt(0x2293207BcE35c44C36E191C3c784ED57383CA1De, 956904512189790),
      Debt(exploiterAddress, 10_576_392_878544270729781152) // +1 wei for rounding errors.
    ];
    mem.ceur = [
      // Debt(0x530D27a6EC2063237909B2c758759AA693797A9C, 2034228478202060),
      // Debt(0xbCf31A6Eb94Bf6450358992e81A526c7A02fD332, 2334198589345838),
      // Debt(0x6c6Bb19c74D7CA16e3cECDC1Ee1E57F246CC353c, 1887908770346544),
      // Debt(0x28EC929A839663d1b9C527C6B5169a44bF8874CE, 2413110286588716),
      Debt(0x0699aA97868209C2c9fBd48214Cc084e6E59117a, 6_342870585715428175),
      Debt(0x7C5BA47745c42dA90Fc777FF349E8Ae3f7688ca5, 154793934591756377),
      // Debt(0xfAe8D53A9Ce471B65B010Ad019aA4c8EDA78FE85, 45020198796775118),
      // Debt(0x1841D0aD97d74672E789f7E3687026abbCB9310F, 535815097491554),
      // Debt(0x11a840ef3b1192b0bda9953E48b7D322312C5fD6, 43408257814728),
      // Debt(0x63678999c2152Af43bB2F3E06D1C0a1A0CBC7FFC, 9918109919895),
      Debt(0xE312D7d632F147c0C4963F2B1c14D010971C11A9, 22_273_657728307716488537),
      // Debt(0x04B57E13963cb1D97E0da6Ba34e5F8866e0d3f99, 2805396035008),
      // Debt(0x371101af457A01EA1Cf94164494cA7f76f8309c2, 1633792522938571),
      Debt(0x9aD4779B7f952060ddC300F531819e9Ed859b57C, 176699836249279146),
      // Debt(0x2D32D10e9B903102dbC0FF99C5D25e6b333e15B2, 661124418915007),
      // Debt(0x926b3DC71Fb55CebDDED307A5f4F737edca93149, 429027505452419),
      // Debt(0x6EDa5bB8A40206E805E98d86D8F4486041AdE4c5, 310807783270577),
      // Debt(0x7B167C2Ca7A13757331B2F124EB52a46d43C416C, 40035443857428375),
      // Debt(0x6da311Df457CB92855673E7AC565AB323e1a1f5B, 45458069823202),
      Debt(0x0C266223C8dB48cA1238103f5bD8772146F860a3, 127301702231891590),
      // Debt(0xAc4B966e4e01662DccA10f96a05415d31efCB761, 9957839840449948),
      Debt(0x276FCe7A3521a4e3492F1E8e5feB835eB0b13096, 48_049952992641588129),
      // Debt(0xdFe8bbBB231e1C5dB90d2d8dfE95CE07f2113F3e, 2689502660456288),
      // Debt(0x125FaACD642bDcA6A4f1919f618BD3a68168925C, 2679252908598575),
      // Debt(0x6328Ddc9df14ADFDF0a4bec752bF91523d8D5cf5, 3477030167969919),
      // Debt(0xA6Efa78EbAF6a48c961544b195592cA85dCfF327, 313509922559522),
      Debt(exploiterAddress, 765_165_853429229290723260)
    ];
    return mem;
  }

  function setReserveParams(address reserve, uint ltv, uint threshold, uint bonus) internal {
    lendingPoolConfigurator.configureReserveAsCollateral(reserve, ltv, threshold, bonus);
  }

  function setReserveFacrot(address reserve, uint percent) internal {
    lendingPoolConfigurator.setReserveFactor(reserve, percent);
  }

  function execute() external onlyOwner {
    Mem memory mem = populateMem();

    // console.log('MOOLAFIX: totalSupply mCELO', IERC20(mCELO).totalSupply());
    // console.log('MOOLAFIX: totalSupply mcUSD', IERC20(mcUSD).totalSupply());
    // console.log('MOOLAFIX: totalSupply mcEUR', IERC20(mcEUR).totalSupply());
    // console.log('MOOLAFIX: totalSupply mcREAL', IERC20(mcREAL).totalSupply());
    // console.log('MOOLAFIX: totalSupply mMOO', IERC20(mMOO).totalSupply());
    // console.log('MOOLAFIX: liquidity CELO', IERC20(CELO).balanceOf(mCELO));
    // console.log('MOOLAFIX: liquidity cUSD', IERC20(cUSD).balanceOf(mcUSD));
    // console.log('MOOLAFIX: liquidity cEUR', IERC20(cEUR).balanceOf(mcEUR));
    // console.log('MOOLAFIX: liquidity cREAL', IERC20(cREAL).balanceOf(mcREAL));
    // console.log('MOOLAFIX: liquidity MOO', IERC20(MOO).balanceOf(mMOO));

    // step 5 : Transfer EmergencyAdmin to the MoolaFix in order to unpause / pause the pool
    // console.log('MOOLAFIX: start execute ');
    addressesProvider.setEmergencyAdmin(address(this));
    // console.log('MOOLAFIX: setEmergencyAdmin success');
    addressesProvider.setPoolAdmin(address(this));
    // console.log('MOOLAFIX: setPoolAdmin success');
    
    // Additional step moved from updateLiquidityIndex, because it is needed to writeOffBadDebt and to disable interest.
    // console.log('MOOLAFIX: setLendingPoolImpl lendingPoolWithUpdateLiquityIndexAddress');
    addressesProvider.setLendingPoolImpl(lendingPoolWithUpdateLiquityIndexAddress);
    // console.log('MOOLAFIX: mMOO', mMOO);

    // console.log('MOOLAFIX: set reserve factor ');
    // Additional step so that repayments do not accumulate profit in treasury.
    setReserveFacrot(CELO, 0);
    setReserveFacrot(cUSD, 0);
    setReserveFacrot(cEUR, 0);
    setReserveFacrot(cREAL, 0);
    setReserveFacrot(MOO, 0);

    // console.log('MOOLAFIX: unpase pool ');
    // step 7: unpause the pool
    lendingPoolConfigurator.setPoolPause(false);

    // console.log('MOOLAFIX: udpate mToken impl', newATokenImplementation);
    // Needed for step 10, update mTokenImpl with an added function transferForMoolaFix to allow transfer mToken from attacker and advantagers to MoolaFix to account for bad debt
    setMtokenImpl(newATokenImplementation);
    
    // console.log('MOOLAFIX: transfer mTOKEN ');
    // step 8/9: Transfer all mCELO/mcEUR, and ~2761.74 mcUSD from OwnedWallet to MoolaFix for repaying bad debt
    (
      uint256 mceloFromOwnedWallet,
      uint256 mcusdFromOwnedWallet,
      uint256 mceurFromOwnedWallet,
      uint256 mcrealFromOwnedWallet
    ) = transferTokensFromOwnedWallet();
    // console.log('MOOLAFIX: mceloFromOwnedWallet', mceloFromOwnedWallet);

    // console.log('MOOLAFIX: first repay of MOO');
    // Additional step to repay MOO debt of the exploiter to be able to transfer mCELO.
    lendingPool.repay(
      MOO,
      1_858_113_235812542542102024,
      2,
      0x1Df15534d350377732944e5bCE2FE65C5aE6766D
    );
    // step 10 Transfer mCELO from attacker to MoolaFix
    // console.log('MOOLAFIX: transferMceloFromExploiter');
    uint256 mCeloFromAttacker = transferMceloFromExploiter();
    // console.log('MOOLAFIX: mCeloFromAttacker', mCeloFromAttacker);

    // step 11 Transfer mCELO from advantagers (i.e. ULP liquidity removers and traders) to MoolaFix for repaying bad debt
    // console.log('MOOLAFIX: transferMceloFromAdvantagers');
    uint256 mceloFromAdvantagers = transferMceloFromAdvantagers();
    // console.log('MOOLAFIX: mceloFromAdvantagers', mceloFromAdvantagers);

    // step 12 Transfer MOO from MoolaFix to advantagers in return
    // console.log('MOOLAFIX: transferMooToAdvantagers');
    transferMooToAdvantagers();

    // step 13 Deposit MOO token and transfer mCELO from the mCELO-MOO pool to MoolaFix (which sets pool ratio at: 1 MOO = 0.023772784 mCELO)
    // console.log('MOOLAFIX: transferMceloFromAndDepositMooToPool');
    uint256 mceloFromPool = transferMceloFromAndDepositMooToPool();
    // console.log('MOOLAFIX: mceloFromPool', mceloFromPool);

    // step 14: Repay for exploiter's debt in CELO, cUSD, cEUR, MOO as much as possible
    // console.log('MOOLAFIX: firstRoundRepay');
    firstRoundRepay(mem);
    // console.log('MOOLAFIX: CELO', IERC20(CELO).balanceOf(address(this)));

    // step 15: burn mTokens to withdraw native assets, pool should have liquitidy after the previous repayments
    uint256 totalMceloFromAllSources = mceloFromOwnedWallet
      .add(mCeloFromAttacker)
      .add(mceloFromAdvantagers)
      .add(mceloFromPool);

    // console.log('MOOLAFIX: withdraw CELO');
    // console.log('balance', IERC20(mCELO).balanceOf(address(this)));
    // console.log('amount', totalMceloFromAllSources);
    lendingPool.withdraw(CELO, type(uint).max, address(this));
    // console.log('MOOLAFIX: withdraw cUSD');
    // console.log('balance', IERC20(mcUSD).balanceOf(address(this)));
    // console.log('amount', mcusdFromOwnedWallet);
    lendingPool.withdraw(cUSD, type(uint).max, address(this));
    // console.log('MOOLAFIX: withdraw cEUR');
    // console.log('balance', IERC20(mcEUR).balanceOf(address(this)));
    // console.log('amount', mceurFromOwnedWallet);
    lendingPool.withdraw(cEUR, type(uint).max, address(this));
    // console.log('MOOLAFIX: withdraw cREAL');
    // console.log('balance', IERC20(mcREAL).balanceOf(address(this)));
    // console.log('amount', mcrealFromOwnedWallet);
    lendingPool.withdraw(cREAL, type(uint).max, address(this));

    // step 16: Second repayment of bad debt in CELO/CUSD/CEUR/MOO
    // console.log('MOOLAFIX: secondRoundRepay');
    // console.log('balance CELO', IERC20(CELO).balanceOf(address(this)));
    secondRoundRepay(mem);

    logBalances();
    // step 17: write off all remaining bad debt that won't be repaid
    // console.log('MOOLAFIX: writeOffBadDebt');
    (uint256 remainingMCeloDebtAmount, uint256 remainingMceurDebtAmount) =
      writeOffBadDebt(mem);

    // Additional step to transfer mMOO from attacker, have to happen after the bad debt writeOff.
    // console.log('MOOLAFIX: transferForMoolaFixSingle mMOO from attacker');
    ATokenWithTransferForMoolaFix(mMOO).transferForMoolaFixSingle(
      exploiterAddress,
      address(this),
      5_667_837_247900688785843099
    );

    uint256 attckerMooDeposit = 5_667_837_247900688785843099; // Reverting attacker deposits.
    // console.log('MOOLAFIX: withdraw mMOO');
    lendingPool.withdraw(MOO, attckerMooDeposit, address(this));

    // Reset mTokenImpl to the original code
    // console.log('MOOLAFIX: revertMtokenImpl');
    setMtokenImpl(originalATokenImplementation);

    // step 18: update liquidity indexes of mToken holders to account for a bad debt by updating lendingPoolImpl and lendingPoolConfiguratorImpl
    // console.log('MOOLAFIX: user 0x70Fb402e73FefB025F93E70eaD8cFA0ec8e092Ba mCELO', IERC20(mCELO).balanceOf(0x70Fb402e73FefB025F93E70eaD8cFA0ec8e092Ba));
    // console.log('MOOLAFIX: user 0x5472895f8de2424AAE41CfEBA18D39145Fa8E685 mcEUR', IERC20(mCELO).balanceOf(0x5472895f8de2424AAE41CfEBA18D39145Fa8E685));
    // console.log('MOOLAFIX: updateLiquidityIndex');
    updateLiquidityIndex(remainingMCeloDebtAmount, remainingMceurDebtAmount);
    // console.log('MOOLAFIX: user 0x70Fb402e73FefB025F93E70eaD8cFA0ec8e092Ba mCELO', IERC20(mCELO).balanceOf(0x70Fb402e73FefB025F93E70eaD8cFA0ec8e092Ba));
    // console.log('MOOLAFIX: user 0x5472895f8de2424AAE41CfEBA18D39145Fa8E685 mcEUR', IERC20(mCELO).balanceOf(0x5472895f8de2424AAE41CfEBA18D39145Fa8E685));

    // step 19: change asset risk parameters CELO, cEUR, cREAL
    setReserveParams(CELO, 6500, 7000, 10500); // 65% LTV, 70% threshold, 5% bonus
    setReserveParams(cEUR, 4500, 5000, 11000); // 45% LTV, 50% threshold, 10% bonus
    setReserveParams(cREAL, 1, 1, 11000); // 0.01% LTV, 0.01% threshold, 10% bonus, effectively removed as collateral
    setReserveParams(MOO, 1, 1, 11000); // 0.01% LTV, 0.01% threshold, 10% bonus, effectively removed as collateral

    // Additional step so that repayments start accumulating profits again.
    setReserveFacrot(CELO, 1000);
    setReserveFacrot(cUSD, 1000);
    setReserveFacrot(cEUR, 1000);
    setReserveFacrot(cREAL, 1000);
    setReserveFacrot(MOO, 1000);

    // console.log('MOOLAFIX: checks step 21');
    logBalances();
    // step 21: check by trying deposit, borrow, repay, withdraw
    uint256 testAmount = 1e18;

    // console.log('Deposit cUSD');
    lendingPool.deposit(cUSD, testAmount, address(this), 0);
    // console.log('Borrow CELO');
    lendingPool.borrow(CELO, testAmount / 100, 2, 0, address(this));
    // console.log('Borrow stable CELO');
    lendingPool.borrow(CELO, testAmount / 100, 1, 0, address(this));
    // console.log('Deposit CELO');
    lendingPool.deposit(CELO, testAmount / 100, address(this), 0);
    // console.log('Withdraw CELO');
    lendingPool.withdraw(CELO, testAmount / 100, address(this));
    // console.log('Borrow cEUR');
    lendingPool.borrow(cEUR, testAmount / 100, 2, 0, address(this));
    // console.log('Borrow stable cEUR');
    lendingPool.borrow(cEUR, testAmount / 100, 1, 0, address(this));
    // console.log('Repay CELO');
    lendingPool.repay(CELO, type(uint256).max, 2, address(this));
    // console.log('Repay stable CELO');
    lendingPool.repay(CELO, type(uint256).max, 1, address(this));
    // console.log('Repay cEUR');
    lendingPool.repay(cEUR, type(uint256).max, 2, address(this));
    // console.log('Repay stable cEUR');
    lendingPool.repay(cEUR, type(uint256).max, 1, address(this));
    // console.log('Withdraw cUSD');
    lendingPool.withdraw(cUSD, type(uint256).max, address(this));

    // transfer CELO left from test back to OwnedWallet
    // IERC20(CELO).transfer(OwnedWallet, IERC20(CELO).balanceOf(address(this)));

    // Additional step deposit MOO to be able to test transfers after freeze.
    // Moved this up to be able to fully test frozen reserve before enabling grace period.
    // console.log('Deposit MOO');
    lendingPool.deposit(MOO, testAmount, address(this), 0);
    // step 24: freeze the moo pool
    // console.log('freezeReserve(MOO)');
    lendingPoolConfigurator.freezeReserve(MOO);

    // Additional step to make sure MOO is properly frozen.
    // console.log('testFrozenMoo');
    testFrozenMoo();

    // step 22: enable grace period
    // console.log('enableGracePeriodOnLendingPool');
    enableGracePeriodOnLendingPool();

    // step 23: Test grace period actions, deposit and repay should work, borrow and withdraw should fail, liquidationCall with a specific error message
    // console.log('testGracePeriodActions');
    testGracePeriodActions();

    // step 25: pause pool again
    // console.log('setPoolPause');
    lendingPoolConfigurator.setPoolPause(true);
    require(lendingPool.paused(), 'Pool did not pause');

    // step 26: Transfer EmergencyAdmin to the OwnedWallet
    // console.log('set admins to OwnedWallet');
    addressesProvider.setEmergencyAdmin(OwnedWallet);
    addressesProvider.setPoolAdmin(OwnedWallet);

    // Step 27: Transfer AddressesProvider ownership from MoolaFix to OwnedWallet
    // console.log('transfer ownership to OwnedWallet');
    addressesProvider.transferOwnership(OwnedWallet);

    // Step 28: Transfer any remaining assets to OwnedWallet. There should only be MOO left in here.
    // There should be no mTokens left here.
    IERC20(MOO).transfer(OwnedWallet, IERC20(MOO).balanceOf(address(this)));
    IERC20(cUSD).transfer(OwnedWallet, IERC20(cUSD).balanceOf(address(this)));
    IERC20(cREAL).transfer(OwnedWallet, IERC20(cREAL).balanceOf(address(this)));

    logBalances();
    requireMTotalLessThan(mCELO, 8_206_100_000000000000000000);
    requireMTotalLessThan(mcUSD, 3_484_550_000000000000000000);
    requireMTotalLessThan(mcEUR, 1_135_950_000000000000000000);
    requireMTotalLessThan(mcREAL, 177_500_000000000000000000);
    requireMTotalLessThan(mMOO, 1_888_050_000000000000000000);
    requireUnderlyingGreaterThan(CELO, mCELO, 8_126_850_000000000000000000);
    requireUnderlyingGreaterThan(cUSD, mcUSD, 641_600_000000000000000000);
    requireUnderlyingGreaterThan(cEUR, mcEUR, 765_100_000000000000000000);
    requireUnderlyingGreaterThan(cREAL, mcREAL, 3_700_000000000000000000);
    requireUnderlyingGreaterThan(MOO, mMOO, 1_884_550_000000000000000000);
  }

  function requireMTotalLessThan(address token, uint amount) internal view {
    require(IERC20(token).totalSupply() < amount);
  }

  function requireUnderlyingGreaterThan(address token, address mToken, uint amount) internal view {
    require(IERC20(token).balanceOf(mToken) > amount);
  }

  // helper functions

  // With the totalAmount given, the function tries to repay account's variable debt first, if there is token left, tries to repay as much stable debt as possible, returns the total repaid amount
  function repayOneAccountBadDebt(
    address asset,
    address variableDebtTokenAddress,
    address stableDebtTokenAddress,
    address account,
    uint256 totalAmount
  ) internal returns (uint256 totalRepaid) {
    // console.log('repayOneAccountBadDebt');
    // console.log(asset);
    // console.log(account, totalAmount);
    // console.log('balance', IERC20(asset).balanceOf(address(this)));
    uint256 accountVariableDebt = IERC20(variableDebtTokenAddress).balanceOf(account);
    uint256 amountLeft = totalAmount;

    // console.log('try variable', accountVariableDebt);
    if (accountVariableDebt > 0) {
      // repay total amount
      uint256 variableRepaid = lendingPool.repay(asset, amountLeft, 2, account);
      amountLeft = amountLeft.sub(variableRepaid);
      totalRepaid = totalRepaid.add(variableRepaid);
    }

    if (amountLeft > 0) {
      uint256 accountStableDebt = IERC20(stableDebtTokenAddress).balanceOf(account);
      // console.log('try stable', accountStableDebt);
      if (accountStableDebt > 0) {
        uint256 stableRepaid = lendingPool.repay(asset, amountLeft, 1, account);
        totalRepaid = totalRepaid.add(stableRepaid);
      }
    }
    // console.log('repayOneAccountBadDebt done');
  }

  // With the totalAmount given, the function tries to burn the account's variable debt first, if there is more needed to burn, tries to burn as much stable debt token as possible
  function burnOneAccountBadDebt(
    address asset,
    address variableDebtTokenAddress,
    address stableDebtTokenAddress,
    address account,
    uint256 totalAmount
  ) internal returns (uint256 totalBurnt) {
    if (totalAmount == 0) {
      return totalBurnt;
    }
    // console.log('burnOneAccountBadDebt');
    // console.log(asset);
    // console.log(account, totalAmount);
    uint256 accountVariableDebt = IERC20(variableDebtTokenAddress).balanceOf(account);
    uint256 amountLeft = totalAmount;

    // console.log('try variable', accountVariableDebt);
    if (accountVariableDebt > 0) {
      uint256 variableBurnt = LendingPoolWithUpdateLiquidityIndex(
        lendingPoolAddress
      ).writeOff(asset, amountLeft, 2, account);
      amountLeft = amountLeft.sub(variableBurnt);
      totalBurnt = totalBurnt.add(variableBurnt);
    }

    if (amountLeft > 0) {
      uint256 accountStableDebt = IERC20(stableDebtTokenAddress).balanceOf(account);
      // console.log('try stable', accountStableDebt);
      if (accountStableDebt > 0) {
        uint256 stableBurnt = LendingPoolWithUpdateLiquidityIndex(
          lendingPoolAddress
        ).writeOff(asset, amountLeft, 1, account);

        totalBurnt = totalBurnt.add(stableBurnt);
      }
    }
  }

  function returnTokenToOwnedWallet(address token) external onlyOwner {
    uint balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
      IERC20(token).safeTransfer(OwnedWallet, balance);
    }
  }

  // In case something gets stuck on the contract.
  function rootCall(address payable to, uint amount, bytes calldata data) external onlyOwner {
    (bool success, bytes memory reason) = to.call{value: amount}(data);
    if (!success) {
      assembly {
        revert(add(reason, 32), reason)
      }
    }
  }
}
