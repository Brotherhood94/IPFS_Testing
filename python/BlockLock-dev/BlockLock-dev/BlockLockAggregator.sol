pragma solidity >=0.4.22 <0.7.0;

import "./BlockLock.sol";

//----------------------Il contratto non deve essere mai chiuso, Non implementare la closecontract---------------------

contract BlocklockAggregator {

    address creator; //potrebbe non servire
    
    uint256 globalCounter; //tiene traccia del numero di blocklock create. Necessario perchè non tiene in considerazione i reset



    /**
     * utenti relativi ad una porta
     * primo parametro è la porta, il seconondo è l'array di utenti
     **/
    //mapping(address => address[]) doorsUser;
    //Posso prenderlo già da blocklock 

    /**
     * Porte relative ad un singolo utente
     * primo parametro è l'address dell'utente, il seconondo è l'array di porte (identificate da struct)
     **/
    mapping(address => address) userToDoors;
    
    mapping(address => bool) registeredBlockLock;
    
    modifier isValidBlockLock(address _bl){
        require(registeredBlockLock(_bl));
        _;
    }
    
    event blockLockAdded(uint256 block, address blocklockAddress, address creator);

    constructor() public{
        creator = msg.sender;
    }

    /**
     * Aggiunge una nuova Blocklock
     **/
    function addBlocklock(bytes32 _lockId) external{
        BlockLock bl = new BlockLock(msg.sender, _lockId, address(this));
        userToDoors[_usr].push(address(bl));
        globalCounter += 1;
        registeredBlockLock[address(bl)] = true;
        emit blockLockAdded(block.number, _blocklockAddress, _usr);
    }

    /**
     * aggiunge l'utente alla porta
     **/
    function addUser(address _usr) external isValidBlockLock(msg.sender){
        userToDoors[_usr].push(msg.sender);
    }

    /**
     * Elimina l'utente associato alla porta
     **/
    function deleteUser(address _usr) external isValidBlockLock(msg.sender){ 
        for(uint i = 0; i < userToDoors[_usr].length; i++){
            if(userToDoors[_usr][i] == msg.sender){
                delete userToDoors[_usr][i];
                break;
            }
        }
    }

    /**
     * esegue il reset di blocklock settando a inattiva la porta precedente
     * deploya un nuovo contratto
     **/
    function resetBlocklock(address _usr) external isValidBlockLock(msg.sender){
        BlockLock old_bl =  BlockLock(msg.sender);
        bytes32 lockId = old_bl.getLockId();
        old_bl.closeContract();
        Blocklock bl = new Blocklock(_usr, lockId, address(this)); //deploya un nuovo contratto
        userToDoors[_usr].push(address(bl)); //aggiungo la nuova porta alla lista
    }
    
    /**
     * restituisce il counter di blocklock
     **/
    function getCounter() public view returns(uint256){
        return globalCounter;
    }

}
