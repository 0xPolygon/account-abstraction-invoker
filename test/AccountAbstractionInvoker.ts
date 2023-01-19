import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { AccountAbstractionInvoker } from "../typechain-types/AccountAbstractionInvoker";
import { MockContract } from "../typechain-types/MockContract";
import { expect } from "chai";
import getSignature from "../scripts/signing/getSignature";
import * as tracking from "../scripts/tracking/track";

describe("AccountAbstractionInvoker", () => {
  let invoker: AccountAbstractionInvoker;
  let mock: MockContract;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let alicePk: string;

  // 4-byte signatures of mock functions
  const increment = "0xd09de08a";
  const causeRevert = "0x67192b63";

  // Deployment fixture
  async function deployContracts() {
    const AccountAbstractionInvoker = await ethers.getContractFactory(
      "AccountAbstractionInvoker"
    );
    const MockContract = await ethers.getContractFactory("MockContract");

    const invoker = await AccountAbstractionInvoker.deploy();
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

      // modify runtime code
      /*await network.provider.send("hardhat_setCode", [
        invoker.address,
        "0x6080604052600436106100555760003560e01c80633644e5151461005a5780637ecebe0014610085578063c994de72146100c2578063cc60f545146100ed578063e6d011c914610118578063ee9fb11614610143575b600080fd5b34801561006657600080fd5b5061006f61015f565b60405161007c9190610bdd565b60405180910390f35b34801561009157600080fd5b506100ac60048036038101906100a79190610905565b610183565b6040516100b99190610d30565b60405180910390f35b3480156100ce57600080fd5b506100d761019b565b6040516100e49190610bdd565b60405180910390f35b3480156100f957600080fd5b506101026101bf565b60405161010f9190610bdd565b60405180910390f35b34801561012457600080fd5b5061012d6101e3565b60405161013a9190610bdd565b60405180910390f35b61015d60048036038101906101589190610957565b610207565b005b7f000000000000000000000000000000000000000000000000000000000000000081565b60006020528060005260406000206000915090505481565b7f8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f81565b7f7e78c6e5723a05fb86c72eb2f059bbce3bae9ed4ae123fab4e6b377b890618f181565b7f163d146384498b85aeb72b0ba8d8b4e513049dec38966b6673a7fd99b9fa163181565b60008180604001906102199190610d4b565b90501161025b576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161025290610cd0565b60405180910390fd5b600061026783836104e1565b905081600001602081019061027c9190610905565b73ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16146102e9576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016102e090610cb0565b60405180910390fd5b6000808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205482602001351461036d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161036490610c90565b60405180910390fd5b60016000808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060008282546103bc9190610e6c565b9250508190555060005b8280604001906103d69190610d4b565b90508110156104985760006104428480604001906103f49190610d4b565b8481811061042b577f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b905060200281019061043d9190610df9565b610529565b905080610484576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040161047b90610cf0565b60405180910390fd5b50808061049090610f4f565b9150506103c6565b50600047146104dc576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016104d390610d10565b60405180910390fd5b505050565b6000806104ed836105c4565b90506000846000013590506000856020013590506000866040016020810190610516919061092e565b90508183826080f694505050505092915050565b6000808260400135905060008360000160208101906105489190610905565b905060008460200135905060008580606001906105659190610da2565b8080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f820116905080830192505050505050509050600080825160208401600086888af7945050505050919050565b6000601960f81b600160f81b7f00000000000000000000000000000000000000000000000000000000000000006105fa8561062a565b60405160200161060d9493929190610b76565b604051602081830303815290604052805190602001209050919050565b60007f163d146384498b85aeb72b0ba8d8b4e513049dec38966b6673a7fd99b9fa16318260000160208101906106609190610905565b836020013561067d8580604001906106789190610d4b565b6106ad565b6040516020016106909493929190610bf8565b604051602081830303815290604052805190602001209050919050565b6000808383905067ffffffffffffffff8111156106f3577f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b6040519080825280602002602001820160405280156107215781602001602082028036833780820191505090505b50905060005b848490508110156107dd5761078585858381811061076e577f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b90506020028101906107809190610df9565b61080e565b8282815181106107be577f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b60200260200101818152505080806107d590610f4f565b915050610727565b50806040516020016107ef9190610b5f565b6040516020818303038152906040528051906020012091505092915050565b60007f7e78c6e5723a05fb86c72eb2f059bbce3bae9ed4ae123fab4e6b377b890618f18260000160208101906108449190610905565b8360200135846040013585806060019061085e9190610da2565b60405161086c929190610bc4565b6040518091039020604051602001610888959493929190610c3d565b604051602081830303815290604052805190602001209050919050565b6000813590506108b4816110a8565b92915050565b6000813590506108c9816110bf565b92915050565b6000606082840312156108e157600080fd5b81905092915050565b6000606082840312156108fc57600080fd5b81905092915050565b60006020828403121561091757600080fd5b6000610925848285016108a5565b91505092915050565b60006020828403121561094057600080fd5b600061094e848285016108ba565b91505092915050565b6000806080838503121561096a57600080fd5b6000610978858286016108cf565b925050606083013567ffffffffffffffff81111561099557600080fd5b6109a1858286016108ea565b9150509250929050565b60006109b78383610a56565b60208301905092915050565b6109cc81610ec2565b82525050565b60006109dd82610e2d565b6109e78185610e45565b93506109f283610e1d565b8060005b83811015610a23578151610a0a88826109ab565b9750610a1583610e38565b9250506001810190506109f6565b5085935050505092915050565b610a41610a3c82610ee0565b610f98565b82525050565b610a5081610f0c565b82525050565b610a5f81610f0c565b82525050565b610a76610a7182610f0c565b610fa2565b82525050565b6000610a888385610e50565b9350610a95838584610f40565b82840190509392505050565b6000610aae600d83610e5b565b9150610ab982610fdb565b602082019050919050565b6000610ad1601183610e5b565b9150610adc82611004565b602082019050919050565b6000610af4601683610e5b565b9150610aff8261102d565b602082019050919050565b6000610b17601283610e5b565b9150610b2282611056565b602082019050919050565b6000610b3a600f83610e5b565b9150610b458261107f565b602082019050919050565b610b5981610f36565b82525050565b6000610b6b82846109d2565b915081905092915050565b6000610b828287610a30565b600182019150610b928286610a30565b600182019150610ba28285610a65565b602082019150610bb28284610a65565b60208201915081905095945050505050565b6000610bd1828486610a7c565b91508190509392505050565b6000602082019050610bf26000830184610a47565b92915050565b6000608082019050610c0d6000830187610a47565b610c1a60208301866109c3565b610c276040830185610b50565b610c346060830184610a47565b95945050505050565b600060a082019050610c526000830188610a47565b610c5f60208301876109c3565b610c6c6040830186610b50565b610c796060830185610b50565b610c866080830184610a47565b9695505050505050565b60006020820190508181036000830152610ca981610aa1565b9050919050565b60006020820190508181036000830152610cc981610ac4565b9050919050565b60006020820190508181036000830152610ce981610ae7565b9050919050565b60006020820190508181036000830152610d0981610b0a565b9050919050565b60006020820190508181036000830152610d2981610b2d565b9050919050565b6000602082019050610d456000830184610b50565b92915050565b60008083356001602003843603038112610d6457600080fd5b80840192508235915067ffffffffffffffff821115610d8257600080fd5b602083019250602082023603831315610d9a57600080fd5b509250929050565b60008083356001602003843603038112610dbb57600080fd5b80840192508235915067ffffffffffffffff821115610dd957600080fd5b602083019250600182023603831315610df157600080fd5b509250929050565b600082356001608003833603038112610e1157600080fd5b80830191505092915050565b6000819050602082019050919050565b600081519050919050565b6000602082019050919050565b600081905092915050565b600081905092915050565b600082825260208201905092915050565b6000610e7782610f36565b9150610e8283610f36565b9250827fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff03821115610eb757610eb6610fac565b5b828201905092915050565b6000610ecd82610f16565b9050919050565b60008115159050919050565b60007fff0000000000000000000000000000000000000000000000000000000000000082169050919050565b6000819050919050565b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b6000819050919050565b82818337600083830152505050565b6000610f5a82610f36565b91507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff821415610f8d57610f8c610fac565b5b600182019050919050565b6000819050919050565b6000819050919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b7f496e76616c6964206e6f6e636500000000000000000000000000000000000000600082015250565b7f496e76616c6964207369676e6174757265000000000000000000000000000000600082015250565b7f4e6f207472616e73616374696f6e207061796c6f616400000000000000000000600082015250565b7f5472616e73616374696f6e206661696c65640000000000000000000000000000600082015250565b7f496e76616c69642062616c616e63650000000000000000000000000000000000600082015250565b6110b181610ec2565b81146110bc57600080fd5b50565b6110c881610ed4565b81146110d357600080fd5b5056fea2646970667358221220f184e0abab324dab308a0ab03cd2097af27860c926d57984376e3ee881824ece64736f6c637822302e382e322d63692e323032312e332e33312b636f6d6d69742e65653635346363330053",
      ]);*/

      tracking.write({
        chainId: network.config["chainId"],
        invoker: invoker.address,
        mock: mock.address,
      });
    } else {
      invoker = await ethers.getContractAt(
        "AccountAbstractionInvoker",
        record.invoker
      );
      mock = await ethers.getContractAt("MockContract", record.mock);
    }

    //console.log(await ethers.provider.getCode(invoker.address));
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
          "Transaction(address from,uint256 nonce,TransactionPayload[] payload)TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)",
        ]
      );
      const transactionPayloadType = ethers.utils.solidityKeccak256(
        ["string"],
        [
          "TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)",
        ]
      );

      expect(await invoker.EIP712DOMAIN_TYPE()).to.equal(eip712DomainType);
      expect(await invoker.TRANSACTION_TYPE()).to.equal(transactionType);
      expect(await invoker.TRANSACTION_PAYLOAD_TYPE()).to.equal(
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
      const name = "Account Abstraction Invoker";
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

      expect(await invoker.DOMAIN_SEPARATOR()).to.equal(domainSeparator);
    });
  });

  describe("invoke", () => {
    it("Should revert on no payload", async () => {
      const nonce = await invoker.nonces(alice.address);
      const messageWithoutPayload = {
        from: alice.address,
        nonce: nonce,
        payload: [],
      };
      const signature = getSignature(messageWithoutPayload, alicePk);

      await expect(
        invoker.invoke(signature, messageWithoutPayload)
      ).to.be.revertedWith("No transaction payload");
    });

    it("Should revert on invalid signature", async () => {
      const nonce = await invoker.nonces(alice.address);
      const message = {
        from: alice.address,
        nonce: nonce,
        payload: [
          { to: mock.address, value: 0, gasLimit: 1000000, data: increment },
        ],
      };
      const invalidSignature = getSignature(message, alicePk);
      invalidSignature.v = !invalidSignature.v;

      //console.log(invalidSignature);

      await expect(
        invoker.invoke(invalidSignature, message, { gasLimit: 30000000 })
      ).to.be.revertedWith("Invalid signature");
    });

    it("Should revert on invalid nonce", async () => {
      const invalidNonce = (await invoker.nonces(alice.address)).add("1");
      const messageWithInvalidNonce = {
        from: alice.address,
        nonce: invalidNonce,
        payload: [
          { to: mock.address, value: 0, gasLimit: 1000000, data: increment },
        ],
      };
      const signature = getSignature(messageWithInvalidNonce, alicePk);

      await expect(
        invoker.invoke(signature, messageWithInvalidNonce)
      ).to.be.revertedWith("Invalid nonce");
    });

    it("Should revert on call failure", async () => {
      const nonce = await invoker.nonces(alice.address);
      const messageWithRevertingCall = {
        from: alice.address,
        nonce: nonce,
        payload: [
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
      const nonce = await invoker.nonces(alice.address);
      const message = {
        from: alice.address,
        nonce: nonce,
        payload: [
          { to: mock.address, value: 0, gasLimit: 1000000, data: increment },
        ],
      };
      const signature = getSignature(message, alicePk);

      await expect(
        invoker.invoke(signature, message, { value: "1" })
      ).to.be.revertedWith("Invalid balance");
    });

    it("Should bundle transactions", async () => {
      const nonce = await invoker.nonces(alice.address);
      const message = {
        from: alice.address,
        nonce,
        payload: [
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
    let invokerAsBob: AccountAbstractionInvoker;

    before(async () => {
      invokerAsBob = await ethers.getContractAt(
        "AccountAbstractionInvoker",
        invoker.address,
        bob
      );
    });

    it("Enables transaction sponsoring", async () => {
      const nonce = await invoker.nonces(alice.address);
      const message = {
        from: alice.address,
        nonce,
        payload: [
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
      const nonce = await invoker.nonces(alice.address);
      const message = {
        from: alice.address,
        nonce,
        payload: [
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
      modifiedMessage.payload[0].gasLimit = 5000000;

      await expect(
        invokerAsBob.invoke(signature, modifiedMessage)
      ).to.be.revertedWith("Invalid signature");
    });
  });
});
