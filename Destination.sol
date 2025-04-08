// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
	mapping( address => address) public underlying_tokens;
	mapping( address => address) public wrapped_tokens;
	address[] public tokens;

	event Creation( address indexed underlying_token, address indexed wrapped_token );
	event Wrap( address indexed underlying_token, address indexed wrapped_token, address indexed to, uint256 amount );
	event Unwrap( address indexed underlying_token, address indexed wrapped_token, address frm, address indexed to, uint256 amount );

    constructor( address admin ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    //The first time a user wishes to transfer an ERC20 (e.g. USDC) over the bridge, the owner of the destination contract will need create new BridgeToken instance on the destination chain.
    // When the createToken function is called, it will deploy a new BridgeToken contract, and return the address of the newly created contract.
    function createToken(address _underlying_token, string memory name, string memory symbol ) public onlyRole(CREATOR_ROLE) returns(address) {
        require(underlying_tokens[_underlying_token]==address(0),"Token is already registered");

        BridgeToken bridgeToken = new BridgeToken(_underlying_token, name,symbol,address(this));
        address tokenAddress=address(bridgeToken);
        underlying_tokens[_underlying_token]=tokenAddress;
        wrapped_tokens[_underlying_token]=tokenAddress;
        underlying_tokens[tokenAddress]=_underlying_token;

        emit Creation(_underlying_token,tokenAddress);
        return tokenAddress;
    }

    //When a user deposits tokens on the source chain, the bridge operator will call the wrap() function to mint them the correct BridgeToken on the destination chain.
    //This function should lookup the BridgeToken that corresponds to the underlying asset, and mint the correct amount of BridgeTokens to the recipient.
    //This function must check that underlying asset has been “registered,” i.e., that the owner of the destination contract has called createToken on the underlying asset.
    function wrap(address _underlying_token, address _recipient, uint256 _amount ) public onlyRole(WARDEN_ROLE) {
        address bridgeTokenAddress=underlying_tokens[_underlying_token];
        require(bridgeTokenAddress!=address(0),"Token is not registered");

        BridgeToken token=BridgeToken(bridgeTokenAddress);
        token.mint(_recipient,_amount);

        emit Wrap(_underlying_token,bridgeTokenAddress,_recipient,_amount);
    }

    //When a user wishes to return back across the bridge, they will burn their BridgeToken by calling unwrap()
    function unwrap(address _wrapped_token, address _recipient, uint256 _amount ) public {
        BridgeToken token=BridgeToken(_wrapped_token);
        token.burnFrom(msg.sender,_amount);
        address underlying=underlying_tokens[_wrapped_token];
        emit Unwrap(underlying,_wrapped_token,msg.sender,_recipient,_amount);
    }


}


