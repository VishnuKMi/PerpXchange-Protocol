-include .env
deploy:; forge script script/DeployPerpX.s.sol
deploy-testnet:; forge script script/DeployPerpX.s.sol --rpc-url ${TESTNET_RPC_URL}
broadcast-deploy-testnet:; forge script script/DeployPerpX.s.sol --rpc-url ${TESTNET_RPC_URL} --broadcast --private-key ${PRIVATE_KEY}
test-mainnet:; forge test -vvvv --match-path test/unit/PerpXchange.t.sol --fork-url "${MAINNET_RPC_URL}"
test-anvil:; forge test -vvvv --match-contract PerpXchangeTestAnvil
coverage-mainnet:; forge coverage --fork-url ${MAINNET_RPC_URL} -vvvv