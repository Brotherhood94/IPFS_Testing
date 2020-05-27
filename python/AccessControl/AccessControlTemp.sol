pragma solidity >=0.4.22 <0.7.0;

import "./AccessControl.sol";

contract AccessControlTemp is AccessControl{
    
        /**
     * informazioni relative alla finestra temporale
     * inizio e fine espressa in blocchi
     **/
    struct timeAccess{
        uint256 start;
        uint256 end;
    }

    /**
     * mappa gli utenti con le relative informazioni sulla finestra temporale
     **/
    mapping (address => timeAccess[]) tempUser;

    /**
     * Controlla che l'utente abbia i permessi
     * chiama la funzione isValidTemp per verificare che l'utente temporaneo abbia ancora i permessi
     **/
    modifier isUser(address _usr) override{
        require(previleges[_usr] == 1 || previleges[_usr] == 2 || (previleges[_usr] == 3 && isValidTemp(_usr)));
        _;
    }

    /**
     * Garantisce i permessi di accesso base ad un nuovo utente
     **/
    function addUser(address _newUSer) onlyRoot(msg.sender) external{
        super.addUser(_newUSer);
        //previleges[_newUSer] = 1; //permessi base al nuovo utente
        //users.push(_newUSer); //aggiungo l'utente alla lista
        //aggregator.addUser(_newUSer); //questo è da gestire, perchè quando è scaduto il tempo andrebbe eliminato dall'aggregator
        //emit userAdded(block.number, msg.sender, _newUSer);
    }

    /**
     * aggiorna i permessi di un utente da base a root
     * richiede i permessi di root per effettuare l'upgrade
     **/
    function upgradeUser(address _stdUser) onlyRoot(msg.sender) external{
        require(previleges[_stdUser] == 1);
        super.upgradeUser(_stdUser);
        //previleges[_stdUser] = 2; //setto l'utente a root
        //emit userUpgraded(block.number, msg.sender, _stdUser);
    }

    /**
     * toglie i permessi di accesso ad un utente base o root
     * richiede i permessi di root
     **/
    function deleteUser(address _usr) onlyRoot(msg.sender) external{
        super.deleteUser(_usr);
        //previleges[_usr] = 0; //tolgo ogni tipo di permesso all'utente
        //aggregator.deleteUser(_usr); //lo elimino anche dall'aggregator in modo che non gli compaia più la porta
        //emit userDeleted(block.number, msg.sender, _usr);
    }

    constructor(address _usr) AccessControl(_usr) public{
        //previleges[_usr] = 2; //setta il creator a utente root
        //users.push(_usr);//aggiunge il creator alla lista di utenti
        //emit blocklockCreated(block.number, _usr);
    }
    
    /**
     * Garantisce i permessi di accesso base ad un nuovo utente solo per una certa finestra temporale
     * richiede i permessi di root per effettuare l'add
     **/
    function addTimeUser(address _newUSer, uint256 _duration, uint256 _startBlock) onlyRoot(msg.sender) external{
        previleges[_newUSer] = 3; //permessi temporanei all'utente
        //users.push(_newUSer); //aggiungo l'utente alla lista
        tempUser[_newUSer].push(timeAccess(_startBlock, _startBlock + _duration));
        emit userAdded(block.number,  msg.sender, _newUSer);
    }

    function getUserRole(address _usr) external view onlyRoot(msg.sender) isUser(_usr) returns(uint8){
        return super.getUserRole();
    }

    function getMyRole() external view isUser(msg.sender) returns(uint8){
        return super.getMyRole();
    }
    
        /**
     * Controlla che gli utenti temporanei abbiano attualmente il tempo di accesso
     **/
    function isValidTemp(address _usr) internal view returns(bool){
        for(uint i = 0; i < tempUser[_usr].length; i++){
            if( block.number >= tempUser[_usr][i].start &&  block.number <= tempUser[_usr][i].end){
                return true;
            }
        }
        return false;
    }

}

