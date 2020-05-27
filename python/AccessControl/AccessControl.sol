pragma solidity >=0.4.22 <0.7.0;

import "./IAccessControl.sol";

contract AccessControl is IAccessControl{ 
    /**
     * mappa gli utenti con la loro tipologia:
     * 0 is not user 
     * 1 is user
     * 2 is root 
     * 3 is temp user, la validità della data viene comtrollata dal modifier isUser con la funzione isValidTemp
     **/
    mapping (address => uint8) previleges;
    
    /**
     * mappa gli utenti con le relative informazioni sulla finestra temporale
     **/
    //mapping (address => timeAccess[]) tempUser;

    /**
     * Controlla che l'utente abbia i permessi
     * chiama la funzione isValidTemp per verificare che l'utente temporaneo abbia ancora i permessi
     **/
    modifier isUser(address _usr){
        require(previleges[_usr] == 1 || previleges[_usr] == 2 || (previleges[_usr] == 3 /*&& isValidTemp(_usr)*/));
        _;
    }
        
    /**
     * Controlla che l'utente abbia i permessi di root
     **/
    modifier onlyRoot(address _usr){
        require(previleges[_usr] == 2);
        _;
    }
    /*
    event accessControlCreated(uint256 block, address user);
    
    event userAdded(uint256 block, address fromUser, address to);
    
    event userUpgraded(uint256 block, address fromUser, address to);
    
    event userDeleted(uint256 block, address fromUser, address to);
    */
    constructor(address _usr) public{
        previleges[_usr] = 2; //setta il creator a utente root
        //users.push(_usr);//aggiunge il creator alla lista di utenti
        emit accessControlCreated(block.number, _usr);
    }

    /**
     * Garantisce i permessi di accesso base ad un nuovo utente
     **/
    function addUser(address _newUSer) onlyRoot(msg.sender) external{
        previleges[_newUSer] = 1; //permessi base al nuovo utente
        //users.push(_newUSer); //aggiungo l'utente alla lista
        //aggregator.addUser(_newUSer); //questo è da gestire, perchè quando è scaduto il tempo andrebbe eliminato dall'aggregator
        emit userAdded(block.number, msg.sender, _newUSer);
    }

    /**
     * aggiorna i permessi di un utente da base a root
     * richiede i permessi di root per effettuare l'upgrade
     **/
    function upgradeUser(address _stdUser) onlyRoot(msg.sender) external{
        require(previleges[_stdUser] == 1);
        previleges[_stdUser] = 2; //setto l'utente a root
        emit userUpgraded(block.number, msg.sender, _stdUser);
    }

    /**
     * toglie i permessi di accesso ad un utente base o root
     * richiede i permessi di root
     **/
    function deleteUser(address _usr) onlyRoot(msg.sender) isUser(_usr) external{
        previleges[_usr] = 0; //tolgo ogni tipo di permesso all'utente
        //aggregator.deleteUser(_usr); //lo elimino anche dall'aggregator in modo che non gli compaia più la porta
        emit userDeleted(block.number, msg.sender, _usr);
    }

    function getUserRole(address _usr) external view onlyRoot(msg.sender) isUser(_usr) returns(uint8){
        return previleges[_usr];
    }

    function getMyRole() external view isUser(msg.sender) returns(uint8){
        return previleges[msg.sender];
    }

}

