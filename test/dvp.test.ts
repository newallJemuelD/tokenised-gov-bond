import { expect } from "chai";
import { ethers } from "hardhat";
import type {
  Whitelist,
  BondToken,
  MockCBDC,
  DvPSettlement,
} from "../typechain-types";
import type {
  Whitelist__factory,
  BondToken__factory,
  MockCBDC__factory,
  DvPSettlement__factory,
} from "../typechain-types";

describe("Tokenised Gov Bond - Permissioned DvP", function () {
  it("whitelist gating + issuer mint + atomic DvP", async () => {
    const [admin, issuer, centralBank, seller, buyer, outsider] = await ethers.getSigners();

    // Deploy Whitelist (admin is deployer)
    const Whitelist = (await ethers.getContractFactory("Whitelist")) as Whitelist__factory;
    const wl = (await Whitelist.connect(admin).deploy()) as Whitelist;
    await wl.waitForDeployment();

    // Whitelist institutions (issuer, central bank, seller, buyer)
    await wl.connect(admin).setWhitelisted(issuer.address, true);
    await wl.connect(admin).setWhitelisted(centralBank.address, true);
    await wl.connect(admin).setWhitelisted(seller.address, true);
    await wl.connect(admin).setWhitelisted(buyer.address, true);
    // outsider intentionally not whitelisted

    // Deploy BondToken
    const BondToken = await ethers.getContractFactory("BondToken");
    const maturity = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;
    const bond = await BondToken.connect(admin).deploy(
      "UK Gilt 2030",
      "UKT30",
      "UKT-2030-4.50",
      450,
      maturity,
      "GBP",
      issuer.address,
      await wl.getAddress()
    );
    await bond.waitForDeployment();

    // Deploy MockCBDC
    const MockCBDC = await ethers.getContractFactory("MockCBDC");
    const cbdc = await MockCBDC.connect(admin).deploy(
      centralBank.address,
      await wl.getAddress()
    );
    await cbdc.waitForDeployment();

    // Deploy DvPSettlement
    const DvP = await ethers.getContractFactory("DvPSettlement");
    const dvp = await DvP.connect(admin).deploy();
    await dvp.waitForDeployment();

    // Issuer mints bond to seller (primary dealer / custodian)
    const bondAmount = ethers.parseEther("100"); // 100 units
    await bond.connect(issuer).mint(seller.address, bondAmount);
    expect(await bond.balanceOf(seller.address)).to.equal(bondAmount);

    // Central bank mints CBDC to buyer (bank cash leg)
    const cashAmount = ethers.parseEther("1000"); // price paid
    await cbdc.connect(centralBank).mint(buyer.address, cashAmount);
    expect(await cbdc.balanceOf(buyer.address)).to.equal(cashAmount);

    // Approvals for DvP
    await bond.connect(seller).approve(await dvp.getAddress(), bondAmount);
    await cbdc.connect(buyer).approve(await dvp.getAddress(), cashAmount);

    // Atomic DvP swap
    await expect(
      dvp.connect(admin).settleDvP(
        buyer.address,
        seller.address,
        await bond.getAddress(),
        await cbdc.getAddress(),
        bondAmount,
        cashAmount
      )
    ).to.emit(dvp, "Settled");

    // Post-settlement balances
    expect(await bond.balanceOf(buyer.address)).to.equal(bondAmount);
    expect(await bond.balanceOf(seller.address)).to.equal(0n);

    expect(await cbdc.balanceOf(seller.address)).to.equal(cashAmount);
    expect(await cbdc.balanceOf(buyer.address)).to.equal(0n);

    // Whitelist gating check: outsider cannot receive bonds
    await bond.connect(issuer).mint(seller.address, bondAmount);
    await expect(bond.connect(seller).transfer(outsider.address, 1n))
      .to.be.revertedWith("not whitelisted");
  });

  it("pause halts transfers", async () => {
    const [admin, issuer, centralBank, seller, buyer] = await ethers.getSigners();

    const Whitelist = await ethers.getContractFactory("Whitelist");
    const wl = await Whitelist.connect(admin).deploy();
    await wl.waitForDeployment();

    await wl.connect(admin).setWhitelisted(issuer.address, true);
    await wl.connect(admin).setWhitelisted(seller.address, true);
    await wl.connect(admin).setWhitelisted(buyer.address, true);

    const BondToken = await ethers.getContractFactory("BondToken");
    const maturity = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;
    const bond = await BondToken.connect(admin).deploy(
      "UK Gilt 2030",
      "UKT30",
      "UKT-2030-4.50",
      450,
      maturity,
      "GBP",
      issuer.address,
      await wl.getAddress()
    );
    await bond.waitForDeployment();

    await bond.connect(issuer).mint(seller.address, ethers.parseEther("1"));

    await bond.connect(issuer).setPaused(true);
    await expect(bond.connect(seller).transfer(buyer.address, 1n))
      .to.be.revertedWith("paused");
  });
});
