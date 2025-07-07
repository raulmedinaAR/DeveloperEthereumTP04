import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { SimpleSwap, RaulMedinaToken } from "../typechain-types";

describe("SimpleSwap", function () {

    const INITIAL_VALUE_TO_MINT = 100_000;

    let simpleSwap: SimpleSwap;
    let raulMedinaTokenA: RaulMedinaToken;
    let raulMedinaTokenB: RaulMedinaToken;
    let contractOwner: any;

    before(async () => {
        const [owner] = await ethers.getSigners();
        contractOwner = owner;

        const raulMedinaTokenFactory = await ethers.getContractFactory("RaulMedinaToken");
        raulMedinaTokenA = (await raulMedinaTokenFactory.deploy("Raul Medina Token A", "RM$A", INITIAL_VALUE_TO_MINT)) as RaulMedinaToken;
        await raulMedinaTokenA.waitForDeployment();
        raulMedinaTokenB = (await raulMedinaTokenFactory.deploy("Raul Medina Token B", "RM$B", INITIAL_VALUE_TO_MINT)) as RaulMedinaToken;
        await raulMedinaTokenB.waitForDeployment();

        const simpleSwapFactory = await ethers.getContractFactory("SimpleSwap");
        simpleSwap = (await simpleSwapFactory.deploy()) as SimpleSwap;
        await simpleSwap.waitForDeployment();
    });

    describe("getAmountOut", function () {
        it("Should calculate output amount", async function () {
            const amountOut = await simpleSwap.getAmountOut(100, 100, 200)
            expect(amountOut).to.be.gt(0);
        });

        it("Should fail with zero input amount", async function () {
            await expect(
            simpleSwap.getAmountOut(0, 100, 200)
            ).to.be.revertedWith("Insufficient input amount");
        });

        it("Should fail with zero reserves", async function () {
            await expect(
            simpleSwap.getAmountOut(100, 0, 200)
            ).to.be.revertedWith("Insufficient liquidity");
        });
    });

    describe("addLiquidity", function () {
        it("Should add liquidity", async function () {
            const amountA = 100;
            const amountB = 100;

            // Approve tokens
            await raulMedinaTokenA.approve(simpleSwap.target, amountA);
            await raulMedinaTokenB.approve(simpleSwap.target, amountB);

            const deadline = (await time.latest()) + 1000;
            await simpleSwap.addLiquidity(
                await raulMedinaTokenA.getAddress(),
                await raulMedinaTokenB.getAddress(),
                amountA,
                amountB,
                1,
                1,
                contractOwner.address,
                deadline
            );

            // Check LP tokens minted
            const lpBalance = await simpleSwap.balanceOf(contractOwner.address);
            expect(lpBalance).to.be.gt(0);
        });

        it("Should fail with expired deadline", async function () {
            const pastDeadline = (await time.latest()) - 1;
            await expect(
                simpleSwap.addLiquidity(
                    await raulMedinaTokenA.getAddress(),
                    await raulMedinaTokenB.getAddress(),
                    100,
                    100,
                    1,
                    1,
                    contractOwner.address,
                    pastDeadline
                )
            ).to.be.revertedWith("Expired");
        });

        it("Should fail with desired amount is zero", async function () {
            const deadline = (await time.latest()) + 1000;
            
            await expect(
                simpleSwap.addLiquidity(
                    await raulMedinaTokenA.getAddress(),
                    await raulMedinaTokenB.getAddress(),
                    0,
                    0,
                    1,
                    1,
                    contractOwner.address,
                    deadline
                )
                ).to.be.revertedWith("Desired amount is zero");
        });

        it("Should fail with min amount is zero", async function () {
            const deadline = (await time.latest()) + 1000;
            
            await expect(
                simpleSwap.addLiquidity(
                    await raulMedinaTokenA.getAddress(),
                    await raulMedinaTokenB.getAddress(),
                    100,
                    100,
                    0,
                    0,
                    contractOwner.address,
                    deadline
                )
            ).to.be.revertedWith("Min amount is zero");
        });

        it("Should fail with the token address is zero", async function () {
            const deadline = (await time.latest()) + 1000;
            
            await expect(
                simpleSwap.addLiquidity(
                    ethers.ZeroAddress,
                    await raulMedinaTokenB.getAddress(),
                    100,
                    100,
                    1,
                    1,
                    contractOwner.address,
                    deadline
                )
            ).to.be.revertedWith("Zero addresses");
        });

        it("Should fail with the 'to' address is zero", async function () {
            const deadline = (await time.latest()) + 1000;
            
            await expect(
                simpleSwap.addLiquidity(
                    await raulMedinaTokenA.getAddress(),
                    await raulMedinaTokenB.getAddress(),
                    100,
                    100,
                    1,
                    1,
                    ethers.ZeroAddress,
                    deadline
                )
            ).to.be.revertedWith("The 'to' address is zero");
        });
    });

    describe("swapExactTokensForTokens", function () {
        it("Should swap tokens", async function () {
            const amountIn     = 10;
            const minAmountOut = 1;
            const path         = [await raulMedinaTokenA.getAddress(), await raulMedinaTokenB.getAddress()];
            const deadline     = (await time.latest()) + 1000;

            // Approve tokens
            await raulMedinaTokenA.approve(simpleSwap.target, amountIn);

            const balanceBefore = await raulMedinaTokenB.balanceOf(contractOwner.address);
            await simpleSwap.swapExactTokensForTokens(
                amountIn,
                minAmountOut,
                path,
                contractOwner.address,
                deadline
            );
            const balanceAfter = await raulMedinaTokenB.balanceOf(contractOwner.address);

            expect(balanceAfter).to.be.gt(balanceBefore);
        });

        it("Should fail with invalid path length", async function () {
            const deadline = (await time.latest()) + 1000;
            
            await expect(
                simpleSwap.swapExactTokensForTokens(
                    100,
                    1,
                    [await raulMedinaTokenA.getAddress()],
                    contractOwner.address,
                    deadline
                )
            ).to.be.revertedWith("Path is not valid");
        });

        it("Should fail with zero address in path", async function () {
            const deadline = (await time.latest()) + 1000;
            
            await expect(
                simpleSwap.swapExactTokensForTokens(
                    100,
                    1,
                    [await raulMedinaTokenA.getAddress(), ethers.ZeroAddress],
                    contractOwner.address,
                    deadline
                )
            ).to.be.revertedWith("Path is not valid");
        });
    });

    describe("getPrice", function () {
        it("Should return the price", async function () {
            const price = await simpleSwap.getPrice(
                await raulMedinaTokenA.getAddress(), 
                await raulMedinaTokenB.getAddress()
            );
            expect(price).to.be.gt(0);
        });

        it("Should fail with insufficient reserves", async function () {
            // Deploy new tokens with no liquidity
            const tokenFactory = await ethers.getContractFactory("RaulMedinaToken");
            const newTokenA = (await tokenFactory.deploy("Raul Medina Token A", "RM$A", 0)) as RaulMedinaToken;
            await newTokenA.waitForDeployment();
            const newTokenB = (await tokenFactory.deploy("Raul Medina Token B", "RM$B", 0)) as RaulMedinaToken;
            await newTokenB.waitForDeployment();

            await expect(simpleSwap.getPrice(await newTokenA.getAddress(), await newTokenB.getAddress()))
                .to.be.revertedWith("Insufficient reserves A");
        });
    });

    describe("removeLiquidity", function () {
        it("Should remove liquidity", async function () {
            const lpBalance = await simpleSwap.balanceOf(contractOwner.address);
            expect(lpBalance).to.be.gt(0);

            const deadline = (await time.latest()) + 1000;
            await simpleSwap.removeLiquidity(
                await raulMedinaTokenA.getAddress(),
                await raulMedinaTokenB.getAddress(),
                lpBalance,
                1,
                1,
                contractOwner.address,
                deadline
            );

            // Check LP tokens burned
            const newLpBalance = await simpleSwap.balanceOf(contractOwner.address);
            expect(newLpBalance).to.be.lt(lpBalance);
        });

        it("Should fail with zero liquidity", async function () {
            const deadline = (await time.latest()) + 1000;

            await expect(
                simpleSwap.removeLiquidity(
                    await raulMedinaTokenA.getAddress(),
                    await raulMedinaTokenB.getAddress(),
                    0,
                    1,
                    1,
                    contractOwner.address,
                    deadline
                )
            ).to.be.revertedWith("Liquidity is zero");
        });

        it("Should fail with insufficient liquidity", async function () {
            const bigAmount = ethers.parseEther("1000000000");
            const deadline = (await time.latest()) + 1000;

            await expect(
                simpleSwap.removeLiquidity(
                    await raulMedinaTokenA.getAddress(),
                    await raulMedinaTokenB.getAddress(),
                    bigAmount,
                    1,
                    1,
                    contractOwner.address,
                    deadline
                )
            ).to.be.revertedWith("You are trying to withdraw more liquidity than you have");
        });
    });
});
