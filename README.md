# Marketplace Engines

## Project Structure

### contracts/

Core protocol implementations:

- `orderbook/` - OrderEngine and settlement logic
- `amm/` - Pool-based automated market making
- `nfts/` - Mock ERC721 contracts for testing

### script/

Deployment and development scripts:

- `DeployOrderEngine.s.sol` - Main deployment script
- `dev/` - Bootstrap scripts, account setup, and local dev utilities

### test/

Test suite organized by scope:

- `unit/` - Isolated component tests
- `integration/` - End-to-end settlement and revert scenarios
- `helpers/` - Shared test utilities (OrderHelper, AccountsHelper, SettlementHelper)
- `mocks/` - Test-only contracts (MockWETH, MockERC721)

## Known Edge Cases

### Non-Collection Bids & `fill.tokenId`

For **non-collection bids**, `fill.tokenId` is **intentionally ignored**.

The traded `tokenId` is always taken from `order.tokenId`.  
This avoids introducing sentinel values (e.g. `0`) or partial validation rules for `fill.tokenId`, which would be ambiguous since `tokenId = 0` is a valid ERC-721 identifier.

Only **collection bids** require `fill.tokenId` to be meaningful.  
In all other cases, the filler implicitly accepts the exact token specified by the order.
