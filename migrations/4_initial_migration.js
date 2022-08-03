const SimpleStaking = artifacts.require("SimpleStaking");

module.exports = function (deployer) {
  deployer.deploy(SimpleStaking, "0x7Da1D2EDFF62311d2bd35234a9A0dFfd753aFB71");
};
