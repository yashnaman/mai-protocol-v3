import { BuidlerConfig, usePlugin } from "@nomiclabs/buidler/config";
usePlugin("@nomiclabs/buidler-ethers");

const config: BuidlerConfig = {
    solc: {
        version: "0.7.4"
    }
};

export default config;