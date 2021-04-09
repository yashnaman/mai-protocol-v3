const { ethers } = require("hardhat");
import * as fs from 'fs';

import { retrieveLinkReferences } from "./linkReferenceParser"

export function toWei(n) { return ethers.utils.parseEther(n) };
export function fromWei(n) { return ethers.utils.formatEther(n); }

export interface AddressBook {

}

export interface DeploymentOptions {
    network: string
    artifactDirectory: string
    addressOverride: { [key: string]: string; }
}

export interface DeploymentRecord {
    type: string
    name: string
    address: string
    dependencies: {}
}

export class Deployer {

    public SAVE_POSTFIX = '.deployment.js'

    public options: DeploymentOptions
    public linkReferences = {}
    public deployedContracts = {}
    public signer = null

    public beforeDeployed = null
    public afterDeployed = null

    constructor(options: DeploymentOptions, signer: any) {
        this.options = options
        this.signer = signer
    }

    public async initialize(...args) {
        this.linkReferences = await retrieveLinkReferences(this.options.artifactDirectory)
        this.load()
        for (var contractName in this.options.addressOverride) {
            if (contractName in this.deployedContracts) {
                this.deployedContracts[contractName] = {
                    type: "preset",
                    name: contractName,
                    address: this.options.addressOverride[contractName],
                }
            }
        }
    }

    public async finalize(...args) {
        this.save();
    }

    public async load() {
        try {
            const savedProgress = JSON.parse(
                fs.readFileSync(this.options.network + this.SAVE_POSTFIX, 'utf-8')
            )
            this.deployedContracts = savedProgress
        } catch (err) {
            console.log("[DEPLOYER] save not found")
        }
    }

    public async save() {
        fs.writeFileSync(
            this.options.network + this.SAVE_POSTFIX,
            JSON.stringify(this.deployedContracts)
        )
    }

    private async deploy(contractName: string, ...args): Promise<any> {
        const deployed = await this._deploy(contractName, ...args)
        this.deployedContracts[contractName] = {
            type: "plain",
            name: contractName,
            address: deployed.address,
        }
        this._logDeployment(contractName, deployed)
        return deployed
    }

    public async deployOrSkip(contractName: string, ...args): Promise<any> {
        if (contractName in this.deployedContracts) {
            return this.getDeployedContract(contractName)
        }
        return await this.deploy(contractName);
    }

    public async deployAsUpgradeable(contractName: string, admin: string): Promise<any> {
        const implementation = await this._deploy(contractName)
        const deployed = await this._deploy("TransparentUpgradeableProxy", implementation.address, admin, "0x")
        this.deployedContracts[contractName] = {
            type: "upgradeable",
            name: contractName,
            address: deployed.address,
            dependencies: { admin, implementation: implementation.address }
        }
        this._logDeployment(contractName, deployed, `(implementation[${implementation.address}] admin[${admin}]`)
        return deployed
    }

    public async getDeployedContract(contractName: string): Promise<any> {
        if (!(contractName in this.deployedContracts)) {
            throw `${contractName} has not yet been deployed`
        }
        const factory = await this._getFactory(contractName)
        return await factory.attach(this.deployedContracts[contractName].address)
    }

    public addressOf(contractName: string) {
        return this.deployedContracts[contractName].address
    }

    private async _deploy(contractName: string, ...args): Promise<any> {
        return this._deployWith(this.signer, contractName, ...args)
    }

    private async _deployWith(signer, contractName: string, ...args): Promise<any> {
        const factory = await this._getFactory(contractName)
        if (this.beforeDeployed != null) {
            this.beforeDeployed(contractName, factory, ...args)
        }
        const deployed = await factory.connect(signer).deploy(...args)
        if (this.afterDeployed != null) {
            this.afterDeployed(contractName, deployed, ...args)
        }
        return deployed
    }

    private async _getFactory(contractName: string): Promise<any> {
        let links = {}
        if (contractName in this.linkReferences) {
            for (let i = 0, j = this.linkReferences[contractName].length; i < j; i++) {
                const linkedContractName = this.linkReferences[contractName][i]
                if (linkedContractName in this.deployedContracts) {
                    links[linkedContractName] = this.deployedContracts[linkedContractName].address
                } else {
                    const deployed = await this.deploy(linkedContractName)
                    links[linkedContractName] = deployed.address;
                }
            }
        }
        return await ethers.getContractFactory(contractName, { libraries: links })
    }

    private _logDeployment(contractName, deployed, message = null) {
        console.log(`[DEPLOYER] ${contractName} has been deployed to ${deployed.address} ${message == null ? "" : message}`)
    }
}

export class MirrorDeployer extends Deployer {

    public l1Provider
    public l2Provider

    public async initialize(...args) {
        super.initialize(...args)


    }
}