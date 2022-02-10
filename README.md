# Foundry Template

This is a template for foundry that provides the basic scaffolding for quickly getting started with new projects. 

To use this template run the following in your terminal: 
```
mkdir <name of project>
cd <name of project>
forge init --template https://github.com/verumlotus/foundry-template
git submodule update --init --recursive
yarn 
```

## What's Included

This template already contains submodules & remappings for `ds-test` (assertions for testing), `solmate` (building blocks for contracts) and `forge-std` (layer on top of hevm cheatcodes to improve UX).

Additionally, the testing folder contains `Console.sol` which allows you to console.log values (similar to JS and hardhat), `Hevm.sol` providing an interface to hevm cheatcodes, and `BaseTest.sol` which includes the two contracts above and `stdlib.sol` from `forge-std`. 

## Scripts

`Prettier` and `Solhint` can be run with the commands `yarn prettier` and `yarn solhint`. 

## Inspiration

Inspiration came from previous testing templates such as gakonst's [dapptools template](https://github.com/gakonst/dapptools-template), and current foundry templates by [Frankie](https://github.com/FrankieIsLost/forge-template) and [Abigger](https://github.com/abigger87/foundry-starter). 

