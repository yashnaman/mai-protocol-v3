pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract Timelock {
    using SafeMath for uint256;

    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature,  bytes data, uint256 eta);

    uint256 public constant GRACE_PERIOD = 80640;  // 14 days
    uint256 public constant MINIMUM_DELAY = 11520;  // 2 days
    uint256 public constant MAXIMUM_DELAY = 172800;  // 30 days

    uint256 public delay;

    constructor(uint256 delay_) public {
        require(delay_ >= MINIMUM_DELAY, "Timelock::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");

        delay = delay_;
    }

    receive() external payable { }

    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) public payable returns (bytes memory) {

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(block.number >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(block.number <= eta.add(GRACE_PERIOD), "Timelock::executeTransaction: Transaction is stale.");

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{ value : value}(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }
}
