import { ethers } from "hardhat";

async function main() {
  const [admin, issuer, centralBank, seller, buyer] = await ethers.getSigners();

  const Whitelist = await ethers.getContractFactory("Whitelist");
  const wl = await Whitelist.connect(admin).deploy();
  await wl.waitForDeployment();

  await wl.connect(admin).setWhitelisted(issuer.address, true);
  await wl.connect(admin).setWhitelisted(centralBank.address, true);
  await wl.connect(admin).setWhitelisted(seller.address, true);
  await wl.connect(admin).setWhitelisted(buyer.address, true);

  const maturity = Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60;

  const BondToken = await ethers.getContractFactory("BondToken");
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

  const MockCBDC = await ethers.getContractFactory("MockCBDC");
  const cbdc = await MockCBDC.connect(admin).deploy(
    centralBank.address,
    await wl.getAddress()
  );
  await cbdc.waitForDeployment();

  const DvP = await ethers.getContractFactory("DvPSettlement");
  const dvp = await DvP.connect(admin).deploy();
  await dvp.waitForDeployment();

  const bondAmount = ethers.parseEther("100");
  const cashAmount = ethers.parseEther("1000");

  await bond.connect(issuer).mint(seller.address, bondAmount);
  await cbdc.connect(centralBank).mint(buyer.address, cashAmount);

  await bond.connect(seller).approve(await dvp.getAddress(), bondAmount);
  await cbdc.connect(buyer).approve(await dvp.getAddress(), cashAmount);

  await dvp.settleDvP(
    buyer.address,
    seller.address,
    await bond.getAddress(),
    await cbdc.getAddress(),
    bondAmount,
    cashAmount
  );

  console.log("DvP done.");
  console.log("Buyer bond:", (await bond.balanceOf(buyer.address)).toString());
  console.log("Seller cash:", (await cbdc.balanceOf(seller.address)).toString());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
