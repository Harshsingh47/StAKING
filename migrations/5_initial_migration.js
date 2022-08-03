const Staking = artifacts.require("Staking");

module.exports = function (deployer) {
  deployer.deploy(Staking, "0xa1d70035768FA5E5E34732feeD9dbB7f9557C2bf");
};
