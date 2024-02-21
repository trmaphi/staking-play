const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Staking", function () {
  let Staking, staking, owner, addr1, addr2, token;

  beforeEach(async function () {
    const Token = await ethers.getContractFactory("Token");
    token = await Token.deploy(); // 18 by default
    await token.waitForDeployment();

    Staking = await ethers.getContractFactory("Staking");
    [owner, addr1, addr2, _] = await ethers.getSigners();
    staking = await Staking.deploy(await token.getAddress());
    await staking.waitForDeployment();
    const stakingAddress = await staking.getAddress();

    await token.mint(stakingAddress, 1_000_000);
    await token.connect(addr1).approve(stakingAddress, 1_000_000);
    await token.connect(addr2).approve(stakingAddress, 1_000_000);
    await token.mint(addr1.address, 1_000_000);
    await token.mint(addr2.address, 1_000_000);
  });

  describe("Staking", function () {
    it("Should allow users to stake tokens", async function () {
      await expect(staking.connect(addr1).stake(100))
        .to.emit(staking, "Staked")
        .withArgs(addr1, 100);
      expect((await staking.stakes(addr1.address)).stakedAmount).to.equal(100);
    });

    it("Should update total staked amount", async function () {
      await expect(staking.connect(addr1).stake(100))
        .to.emit(staking, "Staked")
        .withArgs(addr1, 100);
      await expect(staking.connect(addr2).stake(200))
        .to.emit(staking, "Staked")
        .withArgs(addr2, 200);
      expect(await staking.totalDepositAmt()).to.equal(300);
    });
  });

  describe("Unstaking", function () {
    it("Should return only staked amount when unstake under or exact 1 day", async function () {
      await expect(staking.connect(addr1).stake(100))
        .to.emit(staking, "Staked")
        .withArgs(addr1, 100);
      await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
      await expect(staking.connect(addr1).unstake())
        .to.emit(staking, "Unstaked")
        .withArgs(addr1, 100)
        .to.emit(token, "Transfer")
        .withArgs(await staking.getAddress(), addr1, 100);

      expect((await staking.stakes(addr1.address)).stakedAmount).to.equal(0);
    });

    it("Should return staked amount + reward connect when unstake over 1 day", async function () {
      await expect(staking.connect(addr1).stake(100))
        .to.emit(staking, "Staked")
        .withArgs(addr1, 100);
      await ethers.provider.send("evm_increaseTime", [86401]); // Increase time by 1 day + 1 second
      await expect(staking.connect(addr1).unstake())
        .to.emit(staking, "Unstaked")
        .withArgs(addr1, 200)
        .to.emit(token, "Transfer")
        .withArgs(await staking.getAddress(), addr1, 200); // only 1 staker so earn all

      expect((await staking.stakes(addr1.address)).stakedAmount).to.equal(0);
    });
  });
});
