import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BatchInvoker } from "../typechain-types/BatchInvoker";
import { MockContract } from "../typechain-types/MockContract";
import { expect } from "chai";
import getSignature from "../scripts/signing/getSignature";
import * as tracking from "../scripts/tracking/track";

describe("BatchInvoker", () => {
  let invoker: BatchInvoker;
  let mock: MockContract;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let alicePk: string;

  // 4-byte signatures of mock functions
  const increment = "0xd09de08a";
  const causeRevert = "0x67192b63";

  // Deployment fixture
  async function deployContracts() {
    const BatchInvoker = await ethers.getContractFactory("BatchInvoker");
    const MockContract = await ethers.getContractFactory("MockContract");

    const invoker = await BatchInvoker.deploy();
    await invoker.deployed();
    const mock = await MockContract.deploy();
    await invoker.deployed();

    return { invoker, mock };
  }

  // Deploy contracts if scripts/tracking/out/record.json does not exist
  // Otherwise, use existing contracts from record.json
  // Set REDEPLOY=true to force re-deployment
  before(async () => {
    [alice, bob] = await ethers.getSigners();
    alicePk = process.env.PK_ALICE!;

    const record = tracking.read();
    const redeploy = record === undefined || process.env.REDEPLOY === "true";

    if (redeploy) {
      const deployments = await deployContracts();
      invoker = deployments.invoker;
      mock = deployments.mock;

      tracking.write({
        chainId: network.config["chainId"],
        invoker: invoker.address,
        mock: mock.address,
      });
    } else {
      invoker = await ethers.getContractAt("BatchInvoker", record.invoker);
      mock = await ethers.getContractAt("MockContract", record.mock);
    }
  });

  describe("constructor", () => {
    it("Should set types", async () => {
      const eip712DomainType = ethers.utils.solidityKeccak256(
        ["string"],
        [
          "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)",
        ]
      );
      const transactionType = ethers.utils.solidityKeccak256(
        ["string"],
        [
          "Transaction(address from,uint256 nonce,TransactionPayload[] payloads)TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)",
        ]
      );
      const transactionPayloadType = ethers.utils.solidityKeccak256(
        ["string"],
        [
          "TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)",
        ]
      );

      expect(await invoker.getEIP712DomainType()).to.equal(eip712DomainType);
      expect(await invoker.getTransactionType()).to.equal(transactionType);
      expect(await invoker.getTransactionPayloadType()).to.equal(
        transactionPayloadType
      );
    });

    it("Should set domain separator", async () => {
      const eip712DomainType = ethers.utils.solidityKeccak256(
        ["string"],
        [
          "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)",
        ]
      );
      const name = "Batch Invoker";
      const version = "1.0.0";
      const domainSeparator = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
          ["bytes32", "bytes32", "bytes32", "uint256", "address"],
          [
            eip712DomainType,
            ethers.utils.solidityKeccak256(["string"], [name]),
            ethers.utils.solidityKeccak256(["string"], [version]),
            network.config["chainId"]!,
            invoker.address,
          ]
        )
      );

      expect(await invoker.getDomainSeparator()).to.equal(domainSeparator);
    });
  });

  describe("invoke", () => {
    it("Should revert on no payload", async () => {
      const nonce = await invoker.getNonce(alice.address);
      const messageWithoutPayload = {
        from: alice.address,
        nonce: nonce,
        payloads: [],
      };
      const signature = getSignature(messageWithoutPayload, alicePk);

      await expect(
        invoker.invoke(signature, messageWithoutPayload)
      ).to.be.revertedWith("No payloads");
    });

    it("Should revert on invalid signature", async () => {
      const nonce = await invoker.getNonce(alice.address);
      const message = {
        from: alice.address,
        nonce: nonce,
        payloads: [
          { to: mock.address, value: 0, gasLimit: 1000000, data: increment },
        ],
      };
      const invalidSignature = getSignature(message, alicePk);
      invalidSignature.v = !invalidSignature.v;

      await expect(
        invoker.invoke(invalidSignature, message)
      ).to.be.revertedWith("Invalid signature");
    });

    it("Should revert on invalid nonce", async () => {
      const invalidNonce = (await invoker.getNonce(alice.address)).add("1");
      const messageWithInvalidNonce = {
        from: alice.address,
        nonce: invalidNonce,
        payloads: [
          { to: mock.address, value: 0, gasLimit: 1000000, data: increment },
        ],
      };
      const signature = getSignature(messageWithInvalidNonce, alicePk);

      await expect(
        invoker.invoke(signature, messageWithInvalidNonce)
      ).to.be.revertedWith("Invalid nonce");
    });

    it("Should revert on call failure", async () => {
      const nonce = await invoker.getNonce(alice.address);
      const messageWithRevertingCall = {
        from: alice.address,
        nonce: nonce,
        payloads: [
          { to: mock.address, value: 0, gasLimit: 1000000, data: increment },
          { to: mock.address, value: 0, gasLimit: 1000000, data: causeRevert },
        ],
      };
      const signature = getSignature(messageWithRevertingCall, alicePk);

      await expect(
        invoker.invoke(signature, messageWithRevertingCall)
      ).to.be.revertedWith("Transaction failed");
    });

    it("Should revert on leftover value", async () => {
      const nonce = await invoker.getNonce(alice.address);
      const message = {
        from: alice.address,
        nonce: nonce,
        payloads: [
          { to: mock.address, value: 0, gasLimit: 1000000, data: increment },
        ],
      };
      const signature = getSignature(message, alicePk);

      await expect(
        invoker.invoke(signature, message, { value: "1" })
      ).to.be.revertedWith("Invalid balance");
    });

    it("Should bundle transactions", async () => {
      const nonce = await invoker.getNonce(alice.address);
      const message = {
        from: alice.address,
        nonce,
        payloads: [
          {
            to: mock.address,
            value: 1,
            gasLimit: 1000000,
            data: increment,
          },
          {
            to: mock.address,
            value: 1,
            gasLimit: 1000000,
            data: increment,
          },
        ],
      };
      const signature = getSignature(message, alicePk);
      const mockBalance = await ethers.provider.getBalance(mock.address);
      const mockCounter = await mock.counter();

      const tx = await invoker.invoke(signature, message, {
        value: 2,
      });
      await tx.wait();

      expect(await ethers.provider.getBalance(mock.address)).to.equal(
        mockBalance.add("2")
      );
      expect(await mock.lastSender()).to.equal(alice.address);
      expect(await mock.counter()).to.equal(mockCounter.add("2"));
    });
  });

  describe("Sponsoring examples", () => {
    let invokerAsBob: BatchInvoker;

    before(async () => {
      invokerAsBob = await ethers.getContractAt(
        "BatchInvoker",
        invoker.address,
        bob
      );
    });

    it("Enables transaction sponsoring", async () => {
      const nonce = await invoker.getNonce(alice.address);
      const message = {
        from: alice.address,
        nonce,
        payloads: [
          {
            to: mock.address,
            value: 0,
            gasLimit: 1000000,
            data: increment,
          },
        ],
      };
      const signature = getSignature(message, alicePk);
      const aliceBalance = await ethers.provider.getBalance(alice.address);
      const mockCounter = await mock.counter();

      const tx = await invokerAsBob.invoke(signature, message);
      await tx.wait();

      expect(await ethers.provider.getBalance(alice.address)).to.equal(
        aliceBalance
      );
      expect(await mock.lastSender()).to.equal(alice.address);
      expect(await mock.counter()).to.equal(mockCounter.add("1"));
    });

    it("Prevents manipulation", async () => {
      const nonce = await invoker.getNonce(alice.address);
      const message = {
        from: alice.address,
        nonce,
        payloads: [
          {
            to: mock.address,
            value: 0,
            gasLimit: 1000000,
            data: increment,
          },
        ],
      };
      const signature = getSignature(message, alicePk);

      const modifiedMessage = message;
      modifiedMessage.payloads[0].gasLimit = 5000000;

      await expect(
        invokerAsBob.invoke(signature, modifiedMessage)
      ).to.be.revertedWith("Invalid signature");
    });
  });
});
