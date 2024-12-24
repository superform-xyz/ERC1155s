# Overview

ERC1155A is an extension of ERC-1155 with extended approval and transmute logic, used in SuperPositions. This allows token owners to execute single id or multiple id approvals in place of mass approving all of the ERC1155 ids to the spender and to transmute ERC1155 ids to and from registered ERC20's.

Read more about ERC1155 here: https://docs.superform.xyz/periphery-contracts/superpositions/erc1155a

## Rationale

ERC1155 `setApprovalForAll` function gives full spending permissions over all currently existing and future Ids. Addition of a single Id approval allows this token standard to improve composability through more better allowance control of funds. If external contract is an expected to spend only a single ERC1155 id there is no reason it should have access to all the user owned ids.

ERC1155s additionally do not provide large composability with the DeFi ecosystem, so we provide the ability to transmute individual token ids via `transmuteToERC20` to an ERC20 token. This may be reversed via `transmuteToERC1155A`. 

## Implementation Details

The main change in approval logic is how ERC1155A implements the `safeTransferFrom()` function. Standard ERC1155 implementations only check if the caller in `isApprovedForAll` is an owner of token ids. We propose `setApprovalForOne()` or `setApprovalForMany()` function allowing approvals for specific id in any amount. Therefore, id owner is no longer required to mass approve all of his token ids. The side effect of it is requirement of additional validation logic inside of `safeTransferFrom()` function.

With gas efficiency in mind and preservation of expected ERC1155 behavior, ERC1155A still prioritizes `isApprovedForAll` over `setApprovalForOne()`. Only `safeTransferFrom()` function works with single allowances, `safeBatchTransferFrom()` function requires owner to grant `setApprovalForAll()` to the operator. Decision is dictated by a significant gas costs overhead when required to decrease (or reset, in case of an overflow) allowances for each id in array. Moreover, if owner has `setApprovalForAll()` set to `true`, ERC1155A contract will not modify existing single allowances during `safeTransferFrom()` and `safeBatchTransferFrom()` - assuming that owner has full trust in _operator_ for granting mass approve. Therefore, ERC1155A requires owners to manage their allowances individually and be mindful of enabling `setApprovalForAll()` for external contracts.

ERC1155A token ids may also be transmuted into ERC20's, and transmuted back from the ERC20 through `transmute` functions after `registerERC20` has been called to create the ERC20 token representation on the chain. 

### Testing

You need foundry/forge to run repository.

`forge install`

`forge test`

Two set of tests are run. `ERC1155A` specific and general `ERC1155` tests forked from solmate's implementation of the standard. SuperForm's `ERC1155A` has exactly the same interface as standard `ERC1155` and expected behavior of functions follow EIP documentation.
