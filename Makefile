# Variables
include .env
export $(shell sed 's/=.*//' .env)

RPC_URL=http://127.0.0.1:8545
SCRIPT=script/DeploySimpleNFT.s.sol
OZ_LIB=base/openzeppelin-contracts

MARKETPLACE_ADDRESS_FILE=data/DeployAddress.txt
MARKETPLACE_CONTRACT=$(shell cat $(MARKETPLACE_ADDRESS_FILE))
# Start Anvil (local testnet)
anvil:
	anvil

# Install OpenZeppelin (only if not already installed)
install:
	[ -d "$(OZ_LIB)" ] || forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-commit && \
	forge install foundry-rs/forge-std@v1.8.2 --no-commit

# Build contracts (ensures OpenZeppelin is installed first)
build: install
	forge build

# Deploy contract
deploy: build
	forge script $(SCRIPT) --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY) --chain-id 1111

# Run tests
test: build
	forge test -vvv

# Format Solidity files
fmt:
	forge fmt

# Clean cache & artifacts
clean:
	forge clean
	rm -rf base/openzeppelin-contracts

deploy-market:
	forge script script/DeployDMarket.s.sol --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

# Read NFT Listing mapping
read-listing:
	cast call $(MARKETPLACE_CONTRACT) "listings(uint256)(address,address,uint256,uint256,bool)" $(LISTING_ID) --rpc-url $(RPC_URL)