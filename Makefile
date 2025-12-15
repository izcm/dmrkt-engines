# ───────────────────────────────────────────────
#   Marketplace Engines Makefile 
# ───────────────────────────────────────────────

# Variables
include .env

# paths
DEPLOY_ORDER_ENGINE = script/DeployOrderEngine.s.sol
PATH_DEV_SETUP = script/setup-dev
WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

# ───────────────────────────────────────────────
#   Deploy 
# ───────────────────────────────────────────────
dev-fork:
	@echo "🧬 Starting anvil fork..."
	@cd script/setup-dev && bash start.sh


dev-build-orders: 
	@echo "🔨 Building orders..." && \
	forge script $(PATH_DEV_SETUP)/BuildOrders.s.sol \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast \
		--sender $(SENDER) \
		--private-key $(PRIVATE_KEY) 

dev-bootstrap:dev-fork
	@echo "💻 Bootstraping dev accounts..." && \
	forge script $(PATH_DEV_SETUP)/Bootstrap.s.sol \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast \
		--sender $(SENDER) \
		--private-key $(PRIVATE_KEY)

dev-reset:
	@echo "FULL DEV RESET"
	$(MAKE) dev-fork
	$(MAKE) dev-bootstrap
	$(MAKE) dev-build-orders

weth-balance:
	@if [ -z "$(ADDR)" ]; then \
		echo "❌ Missing ADDR. Usage: make weth-balance ADDR=0xYourAddress"; \
		exit 1; \
	fi
	@echo "WETH balance for $(ADDR):"
	@cast call \
		$(WETH) \
		"balanceOf(address)" \
		$(ADDR) \
		--rpc-url http://127.0.0.1:8545 | cast from-wei

tree:
	@if [ -z "$(DEPTH)" ]; then DEPTH=2; fi; \
	tree -L $$DEPTH -I "out|lib|broadcast|cache|notes"

