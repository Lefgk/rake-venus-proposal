# Returning RAKE's frozen Venus funds to depositors

**Proposer:** RAKE founder and owner of the affected strategy contracts
**Contact:** Discord 5ubse7en · f0r3x_shark@protonmail.com

## Summary

Since February 2021, about $1,075,000 of depositor funds has been frozen in seven Venus markets because of a bug in RAKE's own strategy contracts. Neither RAKE nor the depositors can reach these funds. The only remaining way to release them is a Venus governance action.

We are asking Venus to approve one atomic transaction that does three things:

1. It settles the frozen positions' debt against their own collateral, at no cost to other Venus suppliers.
2. It pays Venus a 20% recovery fee.
3. It sends the remainder to a claim contract, where each original depositor can withdraw their share directly from their own wallet.

Once the funds have arrived, the claim contract's deployer opens a 90-day claim window.

Neither we nor anyone else holds the funds at any point. They move from the frozen positions to the claim contract inside a single Venus transaction.

**At a glance:**
- Funds frozen, net of debt: about $1,074,900 (BSC block 131,610,085, 4 Nov 2026, Venus oracle prices)
- Venus recovery fee, 20%: about $214,980
- Founder fee, 10%: about $107,490, recovery cost
- Available to depositors, 70%: about $752,430
- Affected depositor wallets: 103
- Claim window: 90 days from when the window is opened
- After the window: unclaimed funds go to the contract owner

## 1. What happened

RAKE was an auto-compounding yield farm on BNB Chain, launched on 25 February 2021. Alongside its liquidity pools it offered single-asset vaults that supplied to Venus: BUSD, BTC, ETH, LINK, USDT, USDC and DOT.

About an hour and twenty minutes after launch, we noticed a minor issue on the website and, as a precaution, paused deposits. Pausing is a routine safety measure. In our case it triggered a bug.

The strategy code was based on an outdated copy of AutoFarm's leveraged Venus strategy. In that copy, the function that un-pauses a vault restores most of its permissions but leaves one of them, the permission to interact with its Venus market, switched off. Once the vaults were un-paused, none of the seven could supply, repay or withdraw. The funds were frozen.

We hold the owner keys to these contracts, and they do not help. The contracts have no function that can turn the permission back on, they cannot be upgraded, and the emergency function deliberately excludes the exact tokens involved. We have tested every available route, including deliberately triggering liquidation of our own positions, and none of them works. *(Appendix A1.)*

The only party that can still act is Venus, which controls the market contracts holding these positions.

## 2. What we did in 2021

When the vaults froze, we chose to compensate affected depositors immediately, at our own expense, and we did not wait for a technical fix.

**We kept paying them.** Other farms that hit similar problems cut rewards to their broken pools, because those pools no longer earned the platform anything. We did the opposite. The frozen vaults kept receiving their full share of RAKE rewards, so affected depositors kept earning.

**We stopped selling the founder allocation.** RAKE raised no outside money. The founder's only compensation for building the platform was a share of newly issued RAKE, which was meant to be sold gradually over time. We stopped selling it entirely. The founder's allocation, 13.8% on top of every emission, was at least as large as what the frozen pools received (10.8% of emissions at the freeze, falling to 6.3% later). Every RAKE the founder sold would have drained the same liquidity affected depositors needed to sell their rewards into. By not selling, the founder left that liquidity to them. In effect, the founder's pay was transferred to affected depositors.

The result can be checked on-chain today:

- **Of the RAKE minted to the founder, 92% has never moved.** It is still in the wallet it was minted to. It was held through a price decline from over $43,000 to under $1. Only 0.046% was ever sold.
- **On the 25 March 2021 measure, 80 of 103 affected wallets had received RAKE worth more than their entire frozen position**, counting only rewards from the frozen pools. The total shortfall across 21 others was about $4,100. The last 2 hold only dust, worth $0.
- **97 of the 103 wallets sold their RAKE** and realised that value. The six that never sold held a combined frozen balance of under $70.

These coverage figures value each frozen position at 24 July 2026 prices (BSC block 114,966,322). The summary figures above use today's prices; each wallet's share of the recovery does not depend on either.

Most affected depositors therefore did not lose money from the freeze, and many came out ahead, because the founder gave up the compensation that would otherwise have been paid out. *(Appendix A4.)*

## 3. Why now

We first raised this with Venus in 2021, Venus had a full plate at the time due to unrelated events, so we put our focus on compensating affected users through the above means. Since then we hired an expert to ensure we have exhausted all options in our power to recover the funds and are confident it will require action from Venus. We have also completed development of the scripts, contracts and frontend that will be required to do a proper recovery. This proposal is coming after significant communication with the Venus team.

It is also urgent. Every month of delay costs money:

- **The positions are losing value.** Their debt keeps accruing interest that cannot be repaid.
- **Venus's own risk management is eroding them.** When Venus deprecated DOT as collateral, the frozen DOT position was liquidated sixteen times in under a minute, and most of its value was lost to liquidation penalties and interest. The LINK position is exposed to the same thing.
- **They are a liability for Venus.** These are positions that nobody can repay or manage. Closing them cleanly removes that exposure for good.

## 4. The proposal

### One transaction, no intermediary

The recovery happens entirely inside one Venus governance transaction. For each of the seven markets, Venus temporarily installs a narrowly scoped contract. That contract settles the frozen position's debt using the position's own collateral and moves what remains out of the frozen account, and then the original Venus contract is restored, all within the same transaction. The same contract sends 20% of what it moves to the Venus treasury and the rest to the claim contract, as Venus market tokens (vTokens). The claim contract converts its share back to the original tokens when the claim window opens.

Settling the debt this way costs other Venus suppliers nothing. The market's exchange rate and cash are unchanged, and the contract is built to fail if that is ever not true. *(Appendix A2 and A5.)*

No capital has to be advanced, nobody has to be trusted to forward funds afterwards, and if any step fails, the entire transaction reverts and nothing moves.

**We will give Venus the claim contract address once terms are agreed.** Venus then deploys the seven rescue patches, each with that address fixed inside it. Before the vote, Venus should check every address the transaction touches: the seven strategy positions, the seven markets, the rescue contract, the Venus treasury that receives the 20%, and the claim contract.

### How depositors claim

The claim contract records, at deployment, each of the 103 affected wallets and its share of each frozen pool, taken directly from RAKE's farm contract. Nobody types in an amount.

Each depositor claims by calling the contract from the same wallet they deposited with. They receive their share of each pool in the original token (BTC, ETH, USDC and so on), not converted to a dollar figure. The per-wallet table, each wallet's percentage of each pool, is published in this repo so every depositor can check their own share. Token amounts follow from it on the day the funds arrive. *(Appendix A3.)*

### Fees

- **Venus, 20%**, for the governance action and for taking on the review.
- **Founder, 10%**, recovery cost.
- **Depositors, 70%**, claimable in full by every affected wallet.

Neither fee depends on how many depositors claim.

### Unclaimed funds

The claim window is 90 days from when the claim contract's deployer opens it (`open()`). Any balance still unclaimed after that goes to the strategy contracts' owner.

As a safeguard, if the window is never opened, everything in the claim contract goes to the owner 120 days after the contract was deployed, so funds can never be locked in it permanently.

We expect a significant portion to go unclaimed, and we are saying so plainly rather than leaving reviewers to work it out. These deposits were made in February 2021, at the height of a market cycle, and many of the wallets have been inactive for years. We are proposing that unclaimed funds go to the owner for four reasons:

1. **Funds should not be sent to wallets nobody controls.** Paying out automatically to all 103 addresses would send money to wallets that may be lost or abandoned. Requiring each depositor to claim from their own wallet means only someone in control of that wallet receives funds.
2. **The owner is a party to this recovery.** The frozen positions are held by the owner's contracts, so the owner has to agree to these terms. Without a fallback, unclaimed funds would sit in an abandoned contract forever.
3. **The owner already compensated depositors once, at their own cost.** In 2021, the founder gave up selling the RAKE allocation that was their only payment for building the platform, and held it through a fall from over $43,000 to under $1. Every depositor who comes back still receives their full share. Only funds that nobody claims go to the party that bore that cost.
4. **The owner made this recovery possible.** The investigation, contracts, tests and this proposal were done and paid for by the owner. Without that work, nothing would be returned to anyone.

### Notifying depositors

So that the 90 days is a real window and not a formality, we will:

- send an on-chain message to each of the 103 depositing wallets when the window opens: a zero-value transaction whose data carries the claim link and the deadline, visible on BscScan; and
- publish the opening and closing dates on the claim page: https://claim-frontend-one.vercel.app

## 5. What Venus is being asked to accept

Venus is being asked to accept a temporary change to seven market contracts, inside one transaction, that:

- touches only the seven frozen RAKE positions, hard-coded and not adjustable;
- creates no bad debt, because each position's debt is cleared before anything moves;
- leaves other suppliers' balances, the exchange rate and the market's cash unchanged;
- does not create XVS for anyone: the XVS of the claim contract and the treasury is settled first, so the recovery earns no back-dated rewards (tested: 0 XVS, versus about 3,246 XVS without that step). The XVS the seven strategies earned (about 8,022 XVS) cannot be moved by the strategies; it is up to Venus whether to grant it to the claim contract, in the same transaction or later, in which case depositors receive it pro-rata, and otherwise it stays with Venus;
- restores the original contracts before the transaction ends; and
- reverts completely if any step fails.

In return, Venus gets:

- a 20% recovery fee, about $215,000;
- seven positions that nobody can manage removed from its books; and
- an in-house audited, fully tested recovery, paid for by us; the contracts and their tests are published with this proposal.

## 6. Precedent

We expect Venus to ask whether approving this invites every failed 2021 project to ask for the same. We think the answer should be no, and we would support a clear standard for any future request. It would require:

- that the problem was caused by the project's own code, not by Venus;
- proof that no owner-side fix exists;
- no bad debt and no change to other users' balances or rewards;
- a narrowly scoped, fully reversible, single-transaction change;
- funds returned to affected users through a contract, not through the project team; and
- reproducible tests anyone can run.

This proposal is built to meet all of those conditions.

We are aware that a previous recovery of this kind, AutoFarm's, damaged trust: funds went to the project owner on a promise of later compensation to users that was never kept. This proposal is structured the other way round. Depositors were compensated in 2021, and the evidence is on-chain. The recovered funds now go to depositors first, through a contract we do not control.

## 7. Disclosures

- **Figures will change.** Token amounts are fixed, but dollar values move with prices. Every figure will be refreshed on the day of filing; `contracts/script/RescueAmounts.s.sol` reproduces them from the chain at any block.
- **Our data is our own.** The per-wallet compensation figures are reconstructed by us from public blockchain data. They can be checked independently, and we welcome that.
- **Where part of the BUSD position went.** The position's equity peaked at about 315,956 BUSD in mid-2023. After Venus wound down BUSD, the market stopped paying supply interest while the frozen borrow kept accruing, which cost about 57,000 BUSD. On 27 October 2023 the position was liquidated through Venus's Liquidator in one transaction (`0x40c6147f55b66c4b11a4780723e0e92756000cce0634c342f2366fa1f0370273`): it repaid the 521,222 BUSD borrow and seized 573,344 BUSD of collateral, a 52,123 BUSD penalty. 206,755 BUSD remains, with no debt, and is part of this recovery.

## Technical appendix

The full technical appendix is in [APPENDIX.md](APPENDIX.md):

- **A1:** the bug, and why there is no owner-side fix
- **A2:** the rescue, one VIP transaction
- **A3:** the claim contract, with the per-wallet table in [depositor_share_of_each_frozen_pool.csv](data/depositor_share_of_each_frozen_pool.csv)
- **A4:** the 2021 compensation data
- **A5:** tests and reproduction
