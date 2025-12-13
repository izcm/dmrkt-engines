# ───────────────────────────────────────────────
#   Marketplace Engines Makefile 
# ───────────────────────────────────────────────

# Variables
include .env

# paths
DEPLOY_ORDER_ENGINE = script/DeployOrderEngine.s.sol
PATH_DEV_SETUP = script/setup-dev

# ───────────────────────────────────────────────
#   Deploy 
# ───────────────────────────────────────────────
dev-fork:
	@echo "🧬 Starting anvil fork..."
	@cd script/setup-dev && bash start.sh

dev-setup-script:dev-fork
	@echo "💻 Running DEV Setup Script..." && \
	forge script $(PATH_DEV_SETUP)/foundry/Setup.s.sol \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast \
		--sender $(SENDER) \
		--private-key $(PRIVATE_KEY)

	

