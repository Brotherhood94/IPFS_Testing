pragma solidity >=0.4.22 <0.7.0;

import "./BlockLockAggregator.sol";

contract Blocklock {
    
    bytes32 lockId; //id della porta
    BlocklockAggregator aggregator; 
    address[] users; //lista di utenti, serve solo per far restituire gli utenti della porta senza scorrere la map

    /**
     * informazioni relative alla finestra temporale
     * inizio e fine espressa in blocchi
     **/
    struct timeAccess{
        uint256 start;
        uint256 end;
    }
    
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
    mapping (address => timeAccess[]) tempUser;

    /**
     * Controlla che l'utente abbia i permessi
     * chiama la funzione isValidTemp per verificare che l'utente temporaneo abbia ancora i permessi
     **/
    modifier isUser(address _usr){
        require(previleges[_usr] == 1 || previleges[_usr] == 2 || (previleges[_usr] == 3 && isValidTemp(_usr)));
        _;
    }
    
    modifier isStandardUser()
    
    /**
     * Controlla che l'utente abbia i permessi di root
     **/
    modifier onlyRoot(address _usr){
        require(previleges[_usr] == 2);
        _;
    }
    
    modifier isAggregator(address _agr){
        require(_agr == aggregator);
        _;
    }
    
 
    
    //Eventi
    event statusChanged(uint256 block, address user); 
    
    event blocklockCreated(uint256 block, address user);
    
    event userAdded(uint256 block, address fromUser, address to);
    
    event userUpgraded(uint256 block, address fromUser, address to);
    
    event userDeleted(uint256 block, address fromUser, address to);
    
    constructor(address _usr, bytes32 _lockId, address _aggregator) public{
        aggregator = BlocklockAggregator(_aggregator); //setta l'address dell'aggregator
        lockId = _lockId; //trasforma la stringa in bytes per risparmiare spazio e setta l'id di blocklock 
        previleges[_usr] = 2; //setta il creator a utente root
        users.push(_usr);//aggiunge il creator alla lista di utenti
        emit blocklockCreated(block.number, _usr);
    }
    
    /**
     * Cambia lo stato della porta solo se l'utente ha i permessi di accesso
     **/
    function changeDoorStatus() isUser(msg.sender) external{
        emit statusChanged(block.number, msg.sender);
    }
    
    /**
     * Garantisce i permessi di accesso base ad un nuovo utente
     **/
    function addUser(address _newUSer) onlyRoot(msg.sender) external{
        previleges[_newUSer] = 1; //permessi base al nuovo utente
        users.push(_newUSer); //aggiungo l'utente alla lista
        aggregator.addUser(_newUSer); //questo è da gestire, perchè quando è scaduto il tempo andrebbe eliminato dall'aggregator
        emit userAdded(block.number, msg.sender, _newUSer);
    }
    
    /**
     * Garantisce i permessi di accesso base ad un nuovo utente solo per una certa finestra temporale
     * richiede i permessi di root per effettuare l'add
     **/
    function addTimeUser(address _newUSer, uint256 _duration, uint256 _startBlock) onlyRoot(msg.sender) external{
        previleges[_newUSer] = 3; //permessi temporanei all'utente
        users.push(_newUSer); //aggiungo l'utente alla lista
        tempUser[_newUSer].push(timeAccess(_startBlock, _startBlock + _duration));
        aggregator.addUser(address(this), _newUSer); //questo è da gestire, perchè quando è scaduto il tempo andrebbe eliminato dall'aggregator
        emit userAdded(block.number,  msg.sender, _newUSer);
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
    function deleteUser(address _usr) onlyRoot(msg.sender) external{
        previleges[_usr] = 0; //tolgo ogni tipo di permesso all'utente
        aggregator.deleteUser(_usr); //lo elimino anche dall'aggregator in modo che non gli compaia più la porta
        emit userDeleted(block.number, msg.sender, _usr);
    }
    
    /**
     * Resetta la smart lock, il contratto attuale viene chiuso, viene eliminata la porta assegnata agli utenti nell'aggregator 
     * e viene creato un nuovo contratto. il nuovo contratto non incrementa il counter dei contratti creati
     **/
    function resetLock()  onlyRoot(msg.sender) external{
        aggregator.resetBlocklock(address(this), msg.sender, lockId); //l'aggregator crea un nuovo contrattto
    }
    
 
    /**
     * restituisce gli utenti associati alla porta
     **/
    function getUser() external view returns(address[] memory){
        address[] memory res;
        uint count;
        //aggiungo utenti base e root
        for(uint i = 0; i < users.length; i++){
            if(previleges[users[i]] == 1 || previleges[users[i]] == 2){
                res[count] = users[i];
                count++;
            }

            //aggiungo gli utenti temporanei aventi i permessi
            for(uint k = 0; k < tempUser[users[i]].length; k++){
                if(tempUser[users[i]][k].start >= block.number && tempUser[users[i]][k].end <= block.number){
                    res[count] = users[i];
                    count++;
                }
            }
        }
        return res;
    }
    
    /**
     * Controlla che gli utenti temporanei abbiano attualmente il tempo di accesso
     **/
    function isValidTemp(address _usr) external view returns(bool){
        for(uint i = 0; i < tempUser[_usr].length; i++){
            if( block.number >= tempUser[_usr][i].start &&  block.number <= tempUser[_usr][i].end){
                return true;
            }
        }
        return false;
    }
    
    function getLockId() external view returns(bytes32){
        return lockId;
    }

    /**
     * chiude il contratto
     **/
    function closeContract() isAggregator(msg.sender) external{
        selfdestruct(address(0));
    }
    
}

