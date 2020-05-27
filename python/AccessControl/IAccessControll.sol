pragma solidity >=0.4.22 <0.7.0;

interface IAccessControl{

    event accessControlCreated(uint256 block, address user);
    
    event userAdded(uint256 block, address fromUser, address to);
    
    event userUpgraded(uint256 block, address fromUser, address to);
    
    event userDeleted(uint256 block, address fromUser, address to);
    
    function addUser(address _newUSer) external;

    function upgradeUser(address _stdUser) external;
    
    function deleteUser(address _usr) external;
    

}