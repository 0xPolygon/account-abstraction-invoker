pragma solidity ^0.8.0;

import "./EIP3074Base.sol";

contract AccountSessionInvoker is EIP3074Base {

    function eip712Name() internal override pure returns  (string memory) { return "Account Session Invoker"; }

    function eip712Version() internal override pure returns  (string memory) { return "1.0.0"; }

    struct SessionToken {
        address delegate; // token is bound to specific (trusted) delegate
        uint256 expiration; // time of token expiration
    }

    // TODO: manage whitelist ...
    mapping(address => bool) public toWhitelist;

    function validatePayload(TransactionPayload calldata payload) internal override returns (bool) {
        return toWhitelist[payload.to];
    }

    function invoke(Signature calldata signature, SessionToken calldata token, Transaction calldata transaction) external payable {
        require(transaction.payloads.length > 0, "No transaction payload");

        address signer = authenticate(signature, token);

        require(signer == transaction.from, "Invalid signature"); // TODO: FROM is not part of signature here ...?
        require(token.expiration < block.timestamp, "token has expired");
        require(msg.sender == token.delegate, "token can only be used by designated delegate");

        for (uint256 i = 0; i < transaction.payloads.length; i++) {
            bool success = call(transaction.payloads[i]);
            require(success, "Transaction failed");
        }

        // To ensure that the caller does not send more funds than used in the transaction payload, we check if the contract
        // balance is zero here.
        require(address(this).balance == 0, "Invalid balance");
    }

    function authenticate(Signature calldata signature, SessionToken calldata token)
    private
    view
    returns (address signer)
    {
        bytes32 commit = getCommitHash(token);

        uint256 r = signature.r;
        uint256 s = signature.s;
        bool v = signature.v;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            signer := auth(commit, v, r, s)
        }
    }

    function getCommitHash(SessionToken calldata token) public view returns (bytes32) {
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), DOMAIN_SEPARATOR, hashSessionToken(token)));
    }

    bytes32 public constant SESSION_TOKEN_TYPE = keccak256(
        "SessionToken(address delegate,uint256 expiration)"
    );

    function hashSessionToken(SessionToken calldata token) public pure returns (bytes32) {
        return keccak256(abi.encode(SESSION_TOKEN_TYPE, token.delegate, token.expiration));
    }

}
