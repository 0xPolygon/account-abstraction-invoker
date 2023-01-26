// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InvokerBase} from "./InvokerBase.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";
import {Ownable} from "./utils/Ownable.sol"; // TODO: TBD.

/**
 * @title Session Batch Invoker
 * @author Paul O'Leary <poleary@polygon.technology>, Zero Ekkusu <zeroekkusu.eth>
 * @notice An EIP-3074, session based contract that can send one or more arbitrary transactions in the context of an Externally
 *  Owned Address (EOA), by using `AUTH` and `AUTHCALL`. See https://github.com/0xPolygon/account-abstraction-invoker for more
 *  information.
 */
contract SessionBatchInvoker is InvokerBase, ReentrancyGuard, Ownable {
    struct Transaction {
        address from;
        SessionToken token;
        TransactionPayload[] payloads;
    }

    struct SessionToken {
        address delegate; // token is bound to specific (trusted) delegate
        uint256 expiration; // time of token expiration
        bool revocable;
    }

    struct WhitelistChange {
        address to;
        bool allowed;
    }

    struct WhitelistUpdate {
        WhitelistChange[] changes;
        uint256 applicableFrom;
    }

    bytes32 private constant TRANSACTION_TYPE = keccak256(
        "Transaction(address from,SessionToken token,TransactionPayload[] payloads)SessionToken(address delegate,uint256 expiration,bool revocable)TransactionPayload(address to,uint256 value,uint256 gasLimit,bytes data)"
    );

    bytes32 private constant SESSION_TOKEN_TYPE =
        keccak256("SessionToken(address delegate,uint256 expiration,bool revocable)");

    uint256 private immutable maxSessionTokenDuration;

    mapping(address => bool) private whitelist;

    // Workaround for arrays of structs.
    mapping(uint256 => WhitelistUpdate) private whitelistUpdates;
    uint256 private whitelistUpdatesLength;
    uint256 private whitelistUpdatesPointer;

    mapping(address => mapping(bytes32 => bool)) private revokedTokens;

    event WhitelistUpdateScheduled(WhitelistChange[] changes, uint256 applicableFrom);

    constructor(uint256 _maxSessionTokenDuration, address[] memory allowed)
        InvokerBase("Session Batch Invoker", "1.0.0")
    {
        maxSessionTokenDuration = _maxSessionTokenDuration;

        for (uint256 i = 0; i < allowed.length; i++) {
            whitelist[allowed[i]] = true;
        }
    }

    function getTransactionType() external pure returns (bytes32) {
        return TRANSACTION_TYPE;
    }

    function getSessionTokenType() external pure returns (bytes32) {
        return SESSION_TOKEN_TYPE;
    }

    function getMaxSessionTokenDuration() external view returns (uint256) {
        return maxSessionTokenDuration;
    }

    /*//////////////////////////////////////////////////////////////
                                INVOKING
    //////////////////////////////////////////////////////////////*/

    function invoke(Signature calldata signature, Transaction calldata transaction) external payable nonReentrant {
        require(transaction.payloads.length > 0, "No payloads");

        address signer = authenticate(signature, transaction.token);
        require(signer == transaction.from, "Invalid signature");

        require(transaction.token.expiration - block.timestamp <= maxSessionTokenDuration, "Invalid token");

        if (transaction.token.revocable) {
            require(!isRevoked(signer, transaction.token), "Revoked token");
        }

        require(transaction.token.expiration < block.timestamp, "Expired token");
        require(msg.sender == transaction.token.delegate, "Not delegate");

        uint256 startBalance = address(this).balance - msg.value;

        for (uint256 i = 0; i < transaction.payloads.length; i++) {
            bool success = call(transaction.payloads[i]);
            require(success, "Transaction failed");
        }

        require(address(this).balance <= startBalance, "Invalid balance");
    }

    function validatePayload(TransactionPayload calldata payload) internal view override returns (bool) {
        return whitelist[payload.to];
    }

    function authenticate(Signature calldata signature, SessionToken calldata token)
        internal
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

    /*//////////////////////////////////////////////////////////////
                                REVOKING
    //////////////////////////////////////////////////////////////*/

    function revokeToken(Signature calldata signature, SessionToken calldata token) external {
        require(token.revocable, "Not revocable");

        address signer = authenticate(signature, token);
        require(signer == msg.sender || msg.sender == token.delegate, "Unauthorized");

        revokedTokens[signer][getCommitHash(token)] = true;
    }

    function isRevoked(address account, SessionToken calldata token) public view returns (bool) {
        return revokedTokens[account][getCommitHash(token)];
    }

    /*//////////////////////////////////////////////////////////////
                            WHITELISTING
    //////////////////////////////////////////////////////////////*/

    /* How whitelist updates work:

    All session tokens signed before or at the time of scheduling a new whitelist update
    will expire before the update takes effect, making sure the new rules never apply to them. */

    function scheduleWhitelistUpdate(WhitelistChange[] calldata changes) external onlyOwner {
        WhitelistUpdate storage whitelistUpdate = whitelistUpdates[whitelistUpdatesLength];
        uint256 applicableFrom = block.timestamp + maxSessionTokenDuration;

        for (uint256 i = 0; i < changes.length; i++) {
            whitelistUpdate.changes.push(changes[i]);
        }
        whitelistUpdate.applicableFrom = applicableFrom;

        whitelistUpdatesLength++;

        emit WhitelistUpdateScheduled(changes, applicableFrom);
    }

    function updateWhitelist() external {
        uint256 _whitelistUpdatesPointer = whitelistUpdatesPointer;
        uint256 _whitelistUpdatesLength = whitelistUpdatesLength;
        WhitelistUpdate storage whitelistUpdate;

        while (_whitelistUpdatesPointer < _whitelistUpdatesLength) {
            whitelistUpdate = whitelistUpdates[_whitelistUpdatesPointer];

            if (whitelistUpdate.applicableFrom > block.timestamp) break;

            for (uint256 i = 0; i < whitelistUpdate.changes.length; i++) {
                whitelist[whitelistUpdate.changes[i].to] = whitelistUpdate.changes[i].allowed;
            }

            delete whitelistUpdates[_whitelistUpdatesPointer];
            _whitelistUpdatesPointer++;
        }

        whitelistUpdatesPointer = _whitelistUpdatesPointer;
    }

    function isWhitelisted(address addr) public view returns (bool) {
        return whitelist[addr];
    }

    /*//////////////////////////////////////////////////////////////
                                HASHING
    //////////////////////////////////////////////////////////////*/

    function getCommitHash(SessionToken calldata token) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), getDomainSeparator(), hashSessionToken(token)));
    }

    // TODO: Is it encoded correctly?
    function hashSessionToken(SessionToken calldata token) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(SESSION_TOKEN_TYPE, token.delegate, token.expiration, uint256(token.revocable ? 1 : 0))
        );
    }
}
