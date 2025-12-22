# ───────────────────────────────────────────────
#   Marketplace Engines Makefile
# ───────────────────────────────────────────────

# Variables
include .env

# paths
DEPLOY_ORDER_ENGINE = script/DeployOrderEngine.s.sol
PATH_DEV = script/dev

PATH_BOOTSTRAP = $(PATH_DEV)/genesis/bootstrap
PATH_HISTORY = $(PATH_DEV)/history

PATH_ORDERS = $(PATH_DEV)/orders
PATH_EXPORT = $(PATH_ORDERS)/export

WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
RPC_URL = $(ANVIL_RPC_URL)

# ───────────────────────────────────────────────
#   LOGGING / VERBOSITY
# ───────────────────────────────────────────────

# set SILENT=0 to enable forge output
SILENT ?= 1

ifeq ($(SILENT),1)
FORGE_SILENT = --silent
else
FORGE_SILENT =
endif

# ───────────────────────────────────────────────
#   FORGE COMMON FLAGS
# ───────────────────────────────────────────────

FORGE_COMMON_FLAGS = \
	--rpc-url $(RPC_URL) \
	--broadcast \
	--sender $(SENDER) \
	--private-key $(PRIVATE_KEY) \
	$(FORGE_SILENT)

# ───────────────────────────────────────────────
#   DEV — PRIMARY ENTRYPOINTS
# ───────────────────────────────────────────────
dev-start: dev-fork dev-bootstrap-accounts dev-deploy-core dev-bootstrap-nfts dev-approve
	@echo "🚀 Dev environment ready"

dev-export: dev-build-orders dev-sanitize-orders dev-export-orders
	@echo "🚀 Dev environment ready"

dev-reset: kill-anvil dev-start
	@echo "♻️ Dev reset complete"

# ───────────────────────────────────────────────
#   DEV ENV SETUP - ON CHAIN
# ───────────────────────────────────────────────

# ❗ TODO: MAKE THIS WHOLE PROCESS DOCKERIZED
# https://getfoundry.sh/guides/foundry-in-docker/

dev-fork:
	@echo "🧬 Starting anvil fork..."
	@cd $(PATH_DEV) && bash start.sh

dev-bootstrap-accounts:
	@echo "💻 Bootstrapping dev accounts..."
	forge script $(PATH_BOOTSTRAP)/BootstrapAccounts.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-deploy-core:
	@echo "🧾 Deploying core contracts..."
	forge script $(PATH_DEV)/genesis/DeployCore.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-bootstrap-nfts:
	@echo "🖼️ Bootstrapping NFTs..."
	forge script $(PATH_BOOTSTRAP)/BootstrapNFTs.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-approve:
	@echo "✔ Executing approvals..."
	forge script $(PATH_BOOTSTRAP)/Approve.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-history:
	@echo "📊 Making history..."
	forge script $(PATH_HISTORY)/MakeHistory.s.sol --sig "week1()" \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--sender $(SENDER) \
		--private-key $(PRIVATE_KEY) \

dev-build-orders:
	@echo "🔨 Building orders..."
	forge script $(PATH_ORDERS)/BuildOrders.s.sol \
		$(FORGE_COMMON_FLAGS)


# ───────────────────────────────────────────────
#   DEV ENV SETUP - OFF CHAIN ORDERS
# ───────────────────────────────────────────────
dev-sanitize-orders:
	@echo "🧽 Sanitizing orders..."
	node $(PATH_EXPORT)/sanitize-orders.js

dev-export-orders: dev-sanitize-orders
	@echo "📩 Exporting orders..."
	node $(PATH_EXPORT)/export-orders.js

# ───────────────────────────────────────────────
#   RESET / PROCESS CONTROL
# ───────────────────────────────────────────────
kill-anvil:
	@echo "💀 Killing anvil..."
	pkill anvil 2>/dev/null || true

# ───────────────────────────────────────────────
#   CHAIN READ / WRITE HELPERS
# ───────────────────────────────────────────────
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
		--rpc-url $(RPC_URL) | cast from-wei

# ───────────────────────────────────────────────
#   ETC.
# ───────────────────────────────────────────────
tree:
	@if [ -z "$(DEPTH)" ]; then DEPTH=3; fi; \
	tree -L $$DEPTH -I "out|lib|broadcast|cache|notes"
