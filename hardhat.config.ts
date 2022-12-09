import { HardhatUserConfig, subtask } from "hardhat/config";
import { TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD } from "hardhat/builtin-tasks/task-names";
import { resolve } from "path";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
import { Common } from "@nomicfoundation/ethereumjs-common";

dotenv.config();

// EIP-3074 support
const originalCustom = Common.custom;
Common.custom = (params, opts) => {
  return originalCustom.call(Common, params, {
    ...opts,
    eips: [...(opts.eips ?? []), 3074],
  });
};

/**
 * This overrides the standard compiler version to use a custom compiled version.
 */
subtask<{ solcVersion: string }>(
  TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD,
  async (args, hre, next) => {
    if (args.solcVersion === "0.8.2") {
      const compilerPath = resolve(__dirname, "bin/solcjs-0.8.2.js");

      return {
        compilerPath,
        isSolcJs: true,
        version: args.solcVersion,
        longVersion: "0.8.2-develop.2021.5.12+commit.ee654cc3",
      };
    }

    return next();
  }
);

const config: HardhatUserConfig = {
  //defaultNetwork: "devnet",
  solidity: {
    version: "0.8.2",
  },
  networks: {
    devnet: {
      chainId: 4056,
      url: process.env.RPC_URL || "",
      accounts:
        process.env.PK_ALICE !== undefined && process.env.PK_BOB !== undefined
          ? [process.env.PK_ALICE, process.env.PK_BOB]
          : [],
    },
  },
};

export default config;
