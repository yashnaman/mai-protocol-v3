import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

describe('GovernorAlpha.test', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let user4;
    let user5;

    let stk;
    let rtk;
    let governor;
    let target;

    // enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed }
    enum ProposalState { Pending, Active, Defeated, Succeeded, Queued, Executed, Expired }


    const fromState = (state) => {
        return ProposalState[state]
    }

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[0];
        user2 = accounts[2];
        user3 = accounts[3];
        user4 = accounts[4];
        user5 = accounts[5];
    })

    beforeEach(async () => {
        stk = await createContract("TestLpGovernor");
        rtk = await createContract("CustomERC20", ["RTK", "RTK", 18]);
        target = await createContract("MockLiquidityPool");
        governor = stk;

        await stk.initialize(
            "MCDEX governor token",
            "MGT",
            user0.address,
            target.address,
            rtk.address,
            user0.address
        );

        // console.table([
        //     ["STK", stk.address],
        //     ["RTK", rtk.address],
        //     ["Target", target.address],
        //     ["LPGovernor", governor.address],
        // ])
    });

    const isDebugPrintOn = false

    const skipBlock = async (num) => {
        // console.log("blocknumber @", await ethers.provider.getBlockNumber());
        for (let i = 0; i < num; i++) {
            await rtk.approve(user3.address, 1);
        }
    }

    const printProposal = async (proposalId, accounts = [], padding = 12) => {
        const proposal = await governor.proposals(proposalId);
        const state = await governor.state(proposalId);
        console.log(`===== Proposal ${proposalId} by \x1b[36m${proposal.proposer}\x1b[0m =====`)
        console.log(`         state ${fromState(state).padStart(padding)}`)
        console.log(`         start ${proposal.startBlock.toString().padStart(padding)}`)
        console.log(`           end ${proposal.endBlock.toString().padStart(padding)}`)
        console.log(`      executed ${proposal.executed.toString().padStart(padding)}`)
        console.log(`      forVotes ${fromWei(proposal.forVotes).padStart(padding)}`)
        console.log(`  againstVotes ${fromWei(proposal.againstVotes).padStart(padding)}`)
        console.log(`   quorumVotes ${fromWei(proposal.quorumVotes).padStart(padding)}`)
        console.log(`      receipts`)

        for (let i = 0; i < accounts.length; i++) {
            const receipt = await governor.getReceipt(proposalId, accounts[i].address, { gasLimit: 8000000 });
            const unlockAt = await governor.callStatic.getUnlockBlock(accounts[i].address);
            const isLocked = await governor.callStatic.isLocked(accounts[i].address);

            if (receipt.hasVoted) {
                console.log(`             -  ${accounts[i].address} ${receipt.support ? '\x1b[36m√\x1b[0m' : '\x1b[31m×\x1b[0m'} ${isLocked ? '\x1b[31mLOCKED(' + unlockAt.toString() + ')\x1b[0m' : '\x1b[36mUNLOCK(' + unlockAt.toString() + ')\x1b[0m'} ${fromWei(receipt.votes)}`)
            } else {
                console.log(`             -  ${accounts[i].address} - ${isLocked ? '\x1b[31mLOCKED(' + unlockAt.toString() + ')\x1b[0m' : '\x1b[36mUNLOCK(' + unlockAt.toString() + ')\x1b[0m'}`)
            }
        }
        console.log("")
    }

    const printLock = async (proposalId, accounts = []) => {
        if (!isDebugPrintOn) {
            return;
        }
        console.log("block number =", await ethers.provider.getBlockNumber());
        await printProposal(proposalId, accounts);
    }

    it("exceptions", async () => {
        await expect(governor.state(1)).to.be.revertedWith("invalid proposal id")
        await expect(governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)", "setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        )).to.be.revertedWith("function information arity mismatch")
        await expect(governor.connect(user1).propose(
            [],
            [],
            "setFastCreationEnabled to true"
        )).to.be.revertedWith("must provide actions")
        await expect(governor.connect(user1).propose(
            [
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
                "setFastCreationEnabled(bool)",
            ],
            [
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000001",
            ],
            "setFastCreationEnabled to true"
        )).to.be.revertedWith("too many actions")
    });

    it("validateProposer", async () => {
        await stk.mint(user1.address, toWei("991"));
        await stk.mint(user2.address, toWei("9"));
        expect(await governor.getProposalThreshold()).to.equal(toWei("10"))
        await expect(governor.connect(user2).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        )).to.be.revertedWith("proposal threshold unmet");

        await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        await expect(governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        )).to.be.revertedWith("last proposal is pending");

        await skipBlock(2);

        await expect(governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        )).to.be.revertedWith("last proposal is active");

        await target.setOperatorDebug(user2.address);
        await governor.connect(user2).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        )

        await expect(governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        )).to.be.revertedWith("proposer must be operator when operator exists");
    });


    it("params", async () => {
        expect(await governor.quorumRate()).to.equal(toWei("0.1"))
        expect(await governor.criticalQuorumRate()).to.equal(toWei("0.2"))
        expect(await governor.proposalThresholdRate()).to.equal(toWei("0.01"))
        expect(await governor.proposalMaxOperations()).to.equal(10)
        expect(await governor.votingDelay()).to.equal(1)
        expect(await governor.votingPeriod()).to.equal(20)
        expect(await governor.executionDelay()).to.equal(20)
        expect(await governor.unlockDelay()).to.equal(20)

        await stk.mint(user1.address, toWei("1000"));
        expect(await governor.getProposalThreshold()).to.equal(toWei("10"))

        await stk.mint(user1.address, toWei("1000"));
        expect(await governor.getProposalThreshold()).to.equal(toWei("20"))
    });


    it("quorum", async () => {
        await stk.mint(user1.address, toWei("1000"));

        await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        expect(await governor.getQuorumVotes(1)).to.equal(toWei("100"));
    });

    it("quorum critical", async () => {
        await stk.mint(user1.address, toWei("1000"));
        await governor.connect(user1).propose(
            ["upgradeTo(address)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        expect(await governor.getQuorumVotes(1)).to.equal(toWei("200"));

        await stk.mint(user2.address, toWei("1000"));
        await governor.connect(user2).propose(
            ["forceToSetEmergencyState(uint256,int256)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        expect(await governor.getQuorumVotes(2)).to.equal(toWei("400"));

        await stk.mint(user3.address, toWei("1000"));
        await governor.connect(user3).propose(
            ["transferOperator(address)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        expect(await governor.getQuorumVotes(3)).to.equal(toWei("600"));
    });

    it("quorum critical - mixed", async () => {
        await stk.mint(user1.address, toWei("1000"));
        await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)", "upgradeTo(address)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        expect(await governor.getQuorumVotes(1)).to.equal(toWei("200"));
    });

    it("quorum critical - mixed", async () => {
        await stk.mint(user1.address, toWei("1000"));
        await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)", "upgradeTo(address,address)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000000000000000000000000000002"],
            "setFastCreationEnabled to true"
        );

        var { signatures, calldatas } = await governor.getActions(1);
        expect(await signatures[0]).to.be.equal("setFastCreationEnabled(bool)")
        expect(await signatures[1]).to.be.equal("upgradeTo(address,address)")
        expect(await calldatas[0]).to.be.equal("0x0000000000000000000000000000000000000000000000000000000000000001")
        expect(await calldatas[1]).to.be.equal("0x0000000000000000000000000000000000000000000000000000000000000002")
    });

    it("pass", async () => {
        await stk.mint(user1.address, toWei("1000"));

        await stk.mint(user2.address, toWei("1000"));

        let pid = await governor.connect(user1).callStatic.propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        let tx2 = await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        console.log("Proposal", pid.toString());
        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(0)

        await skipBlock(2);
        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(1)

        await skipBlock(20);
        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(3)

        await skipBlock(20);
        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(4)

        await governor.execute(pid);
        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(5)
    })

    it("rejected", async () => {
        await stk.mint(user1.address, toWei("1000"));

        await stk.mint(user2.address, toWei("1000"));

        let pid = await governor.connect(user1).callStatic.propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        let tx2 = await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        expect(await governor.state(pid)).to.equal(0)
        await skipBlock(2);
        console.log("Proposal", pid.toString());
        const tx = await governor.connect(user2).castVote(pid, false);
        console.log((await tx.wait()).cumulativeGasUsed.toString());

        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(1)
        await skipBlock(2);
        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(1)
        await skipBlock(20);
        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(2)
        await skipBlock(20);
        console.log(fromState(await governor.state(pid)));
        expect(await governor.state(pid)).to.equal(2)
        await expect(governor.execute(pid)).to.be.revertedWith("proposal can only be executed if it is success and queued")
        console.log(fromState(await governor.state(pid)));
    })

    it("lock", async () => {
        await stk.mint(user1.address, toWei("1000"));

        await stk.mint(user2.address, toWei("1000"));

        let pid = await governor.connect(user1).callStatic.propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        let tx2 = await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        const startBlock = tx2.blockNumber;
        console.log("start @", startBlock)

        expect(await governor.state(pid)).to.equal(0)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(startBlock + 1 + 20 + 1); // delay + voting + 1
        await printLock(pid, [user1, user2]);

        await skipBlock(2);
        expect(await governor.state(pid)).to.equal(1)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(startBlock + 1 + 20 + 1); // delay + voting + 1
        await printLock(pid, [user1, user2]);

        await skipBlock(20);

        await printLock(pid, [user1, user2]);
        expect(await governor.state(pid)).to.equal(3)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(startBlock + 1 + 20 + 20 + 20); // delay + voting

        await skipBlock(60);
        await printLock(pid, [user1, user2]);
        expect(await governor.state(pid)).to.equal(6)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(startBlock + 1 + 20 + 20 + 20); // delay + voting
    })

    it("lock - 2", async () => {
        await stk.mint(user1.address, toWei("1000"));

        await stk.mint(user2.address, toWei("500"));

        let pid = await governor.connect(user1).callStatic.propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        let tx2 = await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        // PENDING
        const startBlock = tx2.blockNumber;
        console.log("start @", startBlock)

        await expect(governor.connect(user2).castVote(pid, false)).to.be.revertedWith("voting is closed")
        expect(await governor.state(pid)).to.equal(0)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(startBlock + 1 + 20 + 1); // delay + voting + 1
        await printLock(pid, [user1, user2]);

        await skipBlock(2);
        // ACTIVE

        await governor.connect(user2).castVote(pid, false);
        await expect(governor.connect(user2).castVote(pid, true)).to.be.revertedWith("account already voted")
        expect(await governor.state(pid)).to.equal(1)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(startBlock + 1 + 20 + 1); // delay + voting + 1
        await printLock(pid, [user1, user2]);
        await expect(governor.execute(pid)).to.be.revertedWith("proposal can only be executed if it is success and queued")

        await expect(stk.burn(user2.address, toWei("500"))).to.be.revertedWith("sender is locked");
        await stk.mint(user2.address, toWei("500"));
        await expect(stk.burn(user2.address, toWei("1000"))).to.be.revertedWith("sender is locked");

        await skipBlock(20);
        // QUEUE

        await printLock(pid, [user1, user2]);
        expect(await governor.state(pid)).to.equal(3)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(startBlock + 1 + 20 + 20 + 20); // delay + voting

        await skipBlock(20);
        // SUCCESS

        expect(await governor.state(pid)).to.equal(4)
        await governor.execute(pid)
        await printLock(pid, [user1, user2]);
        expect(await governor.state(pid)).to.equal(5)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(startBlock + 1 + 20 + 20 + 20); // delay + voting
    })

    it("lock - 3", async () => {
        await stk.mint(user1.address, toWei("1000"));
        await stk.mint(user2.address, toWei("1000"));
        await stk.mint(user3.address, toWei("500"));

        let tx1 = await governor.connect(user1).connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t1Start = tx1.blockNumber;

        await skipBlock(2)

        let tx2 = await governor.connect(user2).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t2Start = tx2.blockNumber;

        expect(await governor.state(1)).to.equal(1)
        expect(await governor.state(2)).to.equal(0)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(t1Start + 1 + 20 + 1); // delay + voting + 1
        expect(await governor.callStatic.getUnlockBlock(user2.address)).to.equal(t2Start + 1 + 20 + 1); // delay + voting + 1
        expect(await governor.callStatic.getUnlockBlock(user3.address)).to.equal(0);

        await skipBlock(2);
        expect(await governor.state(1)).to.equal(1)
        expect(await governor.state(2)).to.equal(1)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(t1Start + 1 + 20 + 1); // delay + voting + 1
        expect(await governor.callStatic.getUnlockBlock(user2.address)).to.equal(t2Start + 1 + 20 + 1); // delay + voting + 1
        expect(await governor.callStatic.getUnlockBlock(user3.address)).to.equal(0);

        await governor.connect(user3).castVote(1, false);
        await governor.connect(user3).castVote(2, false);
        expect(await governor.callStatic.getUnlockBlock(user3.address)).to.equal(t2Start + 1 + 20 + 1); // delay + voting + 1
        await governor.connect(user1).castVote(2, false); // p2 will be defeated

        await skipBlock(20);
        expect(await governor.state(1)).to.equal(3)
        expect(await governor.state(2)).to.equal(2)
        expect(await governor.callStatic.getUnlockBlock(user1.address)).to.equal(t1Start + 1 + 20 + 20 + 20); // delay + voting + 1
        expect(await governor.callStatic.getUnlockBlock(user2.address)).to.equal(t2Start + 1 + 20 + 1); // delay + voting + 1
        expect(await governor.callStatic.getUnlockBlock(user3.address)).to.equal(t2Start + 1 + 20 + 1);
    })

    it("lock - 3", async () => {
        await stk.mint(user1.address, toWei("1000"));
        await stk.mint(user2.address, toWei("1000"));
        await stk.mint(user3.address, toWei("1000"));
        await stk.mint(user4.address, toWei("1000"));
        await stk.mint(user5.address, toWei("1000"));

        let tx1 = await governor.connect(user1).connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t1Start = tx1.blockNumber;

        await skipBlock(2)
        let tx2 = await governor.connect(user2).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t2Start = tx2.blockNumber;
        // +3

        await skipBlock(2)
        let tx3 = await governor.connect(user3).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t3Start = tx3.blockNumber;
        // +3

        await skipBlock(2)
        let tx4 = await governor.connect(user4).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t4Start = tx4.blockNumber;
        // +3

        await skipBlock(2)

        await governor.connect(user5).castVote(1, false);
        await governor.connect(user5).castVote(2, true);
        await governor.connect(user5).castVote(3, true);
        await governor.connect(user5).castVote(4, false);
        // + 4

        expect(await governor.callStatic.getUnlockBlock(user5.address)).to.equal(t4Start + 1 + 20 + 1);

        await skipBlock(6)
        // @31 last active for p1
        expect(await governor.state(1)).to.equal(1)
        expect(await governor.state(2)).to.equal(1)
        expect(await governor.state(3)).to.equal(1)
        expect(await governor.state(4)).to.equal(1)

        await skipBlock(1)
        // @32 p1 defeated
        expect(await governor.state(1)).to.equal(2)
        expect(await governor.state(2)).to.equal(1)
        expect(await governor.state(3)).to.equal(1)
        expect(await governor.state(4)).to.equal(1)
        expect(await governor.callStatic.getUnlockBlock(user5.address)).to.equal(t4Start + 1 + 20 + 1);

        await skipBlock(3)
        // @35 p2 successed
        expect(await governor.state(1)).to.equal(2)
        expect(await governor.state(2)).to.equal(3)
        expect(await governor.state(3)).to.equal(1)
        expect(await governor.state(4)).to.equal(1)
        expect(await governor.callStatic.getUnlockBlock(user5.address)).to.equal(t2Start + 1 + 20 + 20 + 20);

        await skipBlock(3)
        // @38 p3 successed
        expect(await governor.state(1)).to.equal(2)
        expect(await governor.state(2)).to.equal(3)
        expect(await governor.state(3)).to.equal(3)
        expect(await governor.state(4)).to.equal(1)
        expect(await governor.callStatic.getUnlockBlock(user5.address)).to.equal(t3Start + 1 + 20 + 20 + 20);

        await skipBlock(3)
        // @41 p4 defeated
        expect(await governor.state(1)).to.equal(2)
        expect(await governor.state(2)).to.equal(3)
        expect(await governor.state(3)).to.equal(3)
        expect(await governor.state(4)).to.equal(2)
        expect(await governor.callStatic.getUnlockBlock(user5.address)).to.equal(t3Start + 1 + 20 + 20 + 20);

        await skipBlock(40)
        // @41 p4 defeated
        expect(await governor.state(1)).to.equal(2)
        expect(await governor.state(2)).to.equal(6)
        expect(await governor.state(3)).to.equal(6)
        expect(await governor.state(4)).to.equal(2)
        expect(await governor.callStatic.getUnlockBlock(user5.address)).to.equal(t3Start + 1 + 20 + 20 + 20);

        await skipBlock(1)
        console.log("transfer");
        await stk.connect(user5).transfer(user1.address, toWei("1000"));
    })

    it("lock - 4", async () => {
        await stk.mint(user1.address, toWei("1000"));
        await stk.mint(user2.address, toWei("1000"));
        await stk.mint(user3.address, toWei("1000"));
        await stk.mint(user4.address, toWei("1000"));
        await stk.mint(user5.address, toWei("1000"));

        let tx1 = await governor.connect(user1).connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t1Start = tx1.blockNumber;

        await skipBlock(2)
        let tx2 = await governor.connect(user2).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t2Start = tx2.blockNumber;
        // +3

        await skipBlock(2)
        let tx3 = await governor.connect(user3).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t3Start = tx3.blockNumber;
        // +3

        await skipBlock(2)
        let tx4 = await governor.connect(user4).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        const t4Start = tx4.blockNumber;
        // +3

        await skipBlock(2)

        await governor.connect(user5).castVote(1, false);
        await governor.connect(user5).castVote(2, true);
        await governor.connect(user5).castVote(3, true);
        await governor.connect(user5).castVote(4, false);
        // + 4

        expect(await governor.callStatic.getUnlockBlock(user5.address)).to.equal(t4Start + 1 + 20 + 1);

        await skipBlock(6)
        await skipBlock(1)
        await skipBlock(3)
        await skipBlock(3)
        await skipBlock(3)
        await skipBlock(40)
        await skipBlock(1)
        console.log("transfer");
        await stk.connect(user5).transfer(user1.address, toWei("1000"));
    })
})