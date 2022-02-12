# Social Recovery Wallet

Minimal implementation of Social Recovery Wallet that keeps guardian identities private until recovery mode.

## Background

Vitalik released a [post](https://vitalik.ca/general/2021/01/11/recovery.html) last month about the need for wider adoption of social recovery wallets. Multi-sigs have thus far been the standard for more secure custody of funds, but require multiple parties to coordinate on transactions. Using just a single key paradigm (e.g. Metamask) can lead to loss of funds if the private key is lost, or theft if a hacker acquires the single private key. Thus, we have social recovery wallets. 

Social Recovery wallets are designed to mitigate against two scenarios: 
1. The user loses their private key 
2. A hacker obtains a user's private key

The image below describes the flow of a social recovery wallet. A single owner is able to sign off on transactions, but a set of guardians is able to change the owner (the signing key). 

![image](https://user-images.githubusercontent.com/97858468/153685332-03d92feb-140f-43e4-b8be-6e455206d6cc.png)

The implementation in this repo is designed to maintain privacy of the list of guardians. Guardian addresses do not have be published on-chain during creation of the wallet. Instead, a hash of the guardian's address can be posted, and can be used to verify a guardian's identity in the case of a recovery.

## Regular flow for a Owner
Social recovery wallets are meant to minimze the burden that an owner faces when making transactions. Thus, the flow consists of just a call to `executeExternalTx` that takes in a desired `callee` contract/EOA, a `value` of Ether to send, and arbitrary `data`. 

## Recovery Flow for Guardians
In the event that an owner loses their private key, guardians can be notified and a recovery process can be kicked off. 
- Guardian calls `initiateRecovery` with the address of the newOwner.
- `threshold - 1` number of guardians call `supportRecovery` with the newOwner.
- Any guardian calls `executeRecovery` to change the owner of the wallet.

## Guardian Management Flow for an Owner
Owners have the ability to swap out guardians in the case that a guardian's keys are compromised or a guardian becomes malicious. 
- Owner calls `initiateGuardianRemoval` with hash of a guardian's address. This queues the guardian for removal – the guardian can only be removed after a time delay of 3 days. 
- Owner calls `executeGuardianRemoval` after the time delay to finalize the removal of the guardian. The owner also provides the hash of a new guardian's address. 

## Build & Testing
This repo uses Foundry for both the build and testing flows. Run `forge build` to build the repo and `forge test` for tests. Note that the tests are merely sanity checks and do not make an effort to check edge cases. 

## Improvements
This social recovery wallet is optimized for the case of loss of the signing key. It is not designed to stop theft of the signing key. In it's current design, it is trivial for an attacker who has obtained the owner's private key to drain the wallet. To prevent this, Vitalik's idea of a "vault" can be layered on top of the current implementation. The vault could whitelist certain contracts/addresses to interact with, and could require guardian approval to add to the whitelist. Additionally, a daily limit of 10% of funds in the wallet can be utilized, with greater amounts requiring guardian approval. 

## Disclaimer
This was a minimal implementation created for personal uses and for fun, and should not be used in production. 

