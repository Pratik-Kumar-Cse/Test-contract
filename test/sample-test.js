const { expect } = require("chai");
const { ethers } = require("hardhat");
describe("NFT-Test", async () => {
  let owner,
    address1,
    address2,
    Factoryinstance,
    CollectableAddress,
    collectableinstance,
    WethInstance;
  beforeEach(async () => {
    const GetFactory = await ethers.getContractFactory("Factory");
    [owner, address1, address2] = await ethers.getSigners();
    Factoryinstance = await GetFactory.deploy();
    await Factoryinstance.deployed();
    const deployCollectable = await Factoryinstance.deployNewCollectionContract(
      "simple",
      "simple",
      "ipfs://QmeD1LWyfAyuEufXhoZChJrrWQzs7o6TSvqBopzazh216w/"
    );
    CollectableAddress = await Factoryinstance.getCollectionAddress(0);
    console.log(CollectableAddress);
    collectableinstance = await ethers.getContractAt(
      "Collection",
      CollectableAddress
    );
    const GetWeth = await ethers.getContractFactory("WPULSE");
    WethInstance = await GetWeth.deploy();
    await WethInstance.deployed();
  });
  it("Is the collectable is deployed and it is there", async () => {
    const getCollectableSize = await Factoryinstance.getAllCollectionAddress();
    expect(getCollectableSize.length).to.be.equal(1);
    const name = await collectableinstance.name();
    expect(name).to.be.equal("simple");
    const symbol = await collectableinstance.symbol();
    expect(symbol).to.be.equal("simple");
  });
  //Minting
  it("Mint the collectable", async () => {
    await collectableinstance.mint(owner.address, "");
    const Tokens = await collectableinstance.getTokens(owner.address);
    expect(Tokens.length).to.be.equal(1);
    const totalsupply = await collectableinstance.totalSupply();
    expect(totalsupply).to.be.equal(1);
  });
  it("Mint the Batch collectable", async () => {
    await collectableinstance.batchMint(owner.address, 3, ["", "", ""]);
    const Tokens = await collectableinstance.getTokens(owner.address);
    expect(Tokens.length).to.be.equal(3);
    const totalsupply = await collectableinstance.totalSupply();
    expect(totalsupply).to.be.equal(3);
  });
  it("Mint with out the authorized user", async () => {
    await expect(collectableinstance.connect(address1).mint(owner.address, ""))
      .to.be.reverted;
  });
  it("Mint with  the authorized user", async () => {
    console.log(collectableinstance);
    await collectableinstance.addAuthorized(address1.address);
    await collectableinstance.connect(address1).mint(address1.address, "");
    const Tokens = await collectableinstance.getTokens(address1.address);
    expect(Tokens.length).to.be.equal(1);
    const totalsupply = await collectableinstance.totalSupply();
    expect(totalsupply).to.be.equal(1);
  });

  //Verifying the signature
  describe("Tokens Needs to be already there", async () => {
    beforeEach(async () => {
      await collectableinstance.batchMint(owner.address, 3, ["", "", ""]);
    });
    it("Verify the signature", async () => {
      const hash = await collectableinstance.getMessageHash(
        address1.address,
        1,
        ethers.utils.parseEther("1")
      );
      const sig = await owner.signMessage(ethers.utils.arrayify(hash));
      const verifybool = await collectableinstance
        .connect(address1)
        .getTokenOwnership(1, ethers.utils.parseEther("1"), sig);
      const Owner = await collectableinstance.ownerOf(1);
      expect(Owner).to.be.equal(address1.address);
      //Check the holder of the token
      let addr1index = await collectableinstance.tokenOfOwnerByIndex(
        address1.address,
        0
      );
      let Ownerindex = await collectableinstance.tokenOfOwnerByIndex(
        owner.address,
        1
      );
      expect(addr1index).to.be.equal(1);
      expect(Ownerindex).to.be.equal(2);
    });
    it("Test burn function", async () => {
      let hashi = await collectableinstance.burn(3);
      let Ownertokens = await collectableinstance.getTokens(owner.address);
      expect(Ownertokens.length).to.be.equal(2);
    });
    it("Test approve function", async () => {
      let app = await collectableinstance.approve(address1.address, 1);
      await app.wait();
      let appinst = await collectableinstance.getApproved(1);
      expect(appinst).to.equal(address1.address);
    });
    it("setApprovalForAll", async () => {
      let app = await collectableinstance.setApprovalForAll(
        address1.address,
        true
      );
      await app.wait();
      let appinst = await collectableinstance.isApprovedForAll(
        owner.address,
        address1.address
      );
      expect(appinst).to.be.equal(true);
    });
    it("Test approve function if it is contract and not whitelisted", async () => {
      await expect(collectableinstance.approve(Factoryinstance.address, 1)).to
        .be.reverted;
    });
    it("Test approve function if it is contract and  whitelisted", async () => {
      await collectableinstance.addAddress(Factoryinstance.address);
      await collectableinstance.approve(Factoryinstance.address, 1);
      let appinst = await collectableinstance.getApproved(1);
      expect(appinst).to.be.equal(Factoryinstance.address);
    });
    it("Test Setapproveall function if it is contract and not whitelisted", async () => {
      await expect(
        collectableinstance.setApprovalForAll(Factoryinstance.address, true)
      ).to.be.reverted;
    });
    it("Test Setapproveall function if it is contract and  whitelisted", async () => {
      await collectableinstance.addAddress(Factoryinstance.address);
      let app = await collectableinstance.setApprovalForAll(
        Factoryinstance.address,
        true
      );
      await app.wait();
      let appinst = await collectableinstance.isApprovedForAll(
        owner.address,
        Factoryinstance.address
      );
      console.log(appinst);
      expect(appinst).to.be.equal(true);
    });
    it("transferFrom Test", async () => {
      let app = await collectableinstance.approve(address1.address, 1);
      await collectableinstance.transferFrom(
        owner.address,
        address2.address,
        1
      );
      let addr = await collectableinstance.ownerOf(1);
      expect(addr).to.be.equal(address2.address);
    });
    // it("safeTransferFrom Test", async () => {
    //   let app = await collectableinstance.approve(address1.address, 1);
    //   console.log(collectableinstance);
    //   await collectableinstance.safeTransferFrom(
    //     owner.address,
    //     address2.address,
    //     1
    //   );
    //   //   let addr = await collectableinstance.ownerOf(1);
    //   //   expect(addr).to.be.equal(address2.address);
    // });
    it("transferTokenOwnership test", async () => {
      let transfer = await collectableinstance.transferTokenOwnership(
        1,
        address1.address
      );
      let addr = await collectableinstance.ownerOf(1);
      expect(addr).to.be.equal(address1.address);
    });
    it("tokenURI", async () => {
      let tokenUri = await collectableinstance.tokenURI(1);
      expect(tokenUri).to.be.equal(
        "ipfs://QmeD1LWyfAyuEufXhoZChJrrWQzs7o6TSvqBopzazh216w/1.json"
      );
      console.log(tokenUri);
    });
    //Royality functions
    it("Set the royality Info", async () => {
      await collectableinstance.setDefaultRoyalty(owner.address, 1000);
      let Feedenominator = 10000;
      let royalityi1 = await collectableinstance.royaltyInfo(
        1,
        "1000000000000000000"
      );
      let percent = 1 * (1000 / 10000);
      let percentInWei = ethers.utils.parseEther(percent.toString());
      console.log("percentInWei------------->", percentInWei);
      console.log("royalityi1------------->", royalityi1[1]);
      expect(royalityi1[1]).to.be.equal(percentInWei);
    });
    it("set royality for token", async () => {
      await collectableinstance.setRoyaltyforToken(1, owner.address, 1000);
      let Feedenominator = 10000;
      let royalityi1 = await collectableinstance.royaltyInfo(
        1,
        "1000000000000000000"
      );
      let percent = 1 * (1000 / 10000);
      let percentInWei = ethers.utils.parseEther(percent.toString());
      console.log("percentInWei------------->", percentInWei);
      console.log("royalityi1------------->", royalityi1[1]);
      expect(royalityi1[1]).to.be.equal(percentInWei);
    });
    it("delete default royality", async () => {
      await collectableinstance.deleteDefaultRoyalty();
      let royalityi1 = await collectableinstance.royaltyInfo(
        1,
        "1000000000000000000"
      );
      console.log("royalityi1---------->", royalityi1);
      expect(royalityi1[1]).to.be.equal(0);
    });
  });
  describe("Running the MarketPlace", async () => {
    beforeEach(async () => {
      //deploy the marketplace contract
    });
  });
});
