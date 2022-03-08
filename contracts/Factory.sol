// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./Collection.sol";

contract Factory is Ownable {

    event CollectionTokenCreated(address tokenAddress);

    address[] collectionAddresses;

    constructor() {
        
    }

     /**
     * @dev deploy a new collection contract.
     */

    function deployNewCollectionContract(string memory _name, string memory _symbol,string memory _baseURI) onlyOwner()
        external
        returns (address)
    {
        require(bytes(_name).length != 0,"Factory: Use valid _name");
        require(bytes(_symbol).length != 0,"Factory: Use valid _symbol");
        Collection collection = new Collection(_name, _symbol,_baseURI);
        collection.transferOwnership(msg.sender);
        emit CollectionTokenCreated(address(collection));
        collectionAddresses.push(address(collection));
        return address(collection);
    }

    function getAllCollectionAddress() external view returns(address[] memory){
        return collectionAddresses;
    }

    function getCollectionAddress(uint _gameId) external view returns(address){
        return collectionAddresses[_gameId];
    }
}