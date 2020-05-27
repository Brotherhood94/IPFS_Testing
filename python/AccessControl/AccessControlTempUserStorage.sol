pragma solidity >=0.4.22 <0.7.0;

import "./AccessControlTemp.sol";

contract AccessControlTempUserStorage is AccessControlTemp{ 

    address[] users; //lista di utenti, serve solo per far restituire gli utenti della porta senza scorrere la map

    constructor(address _usr) AccessControl(_usr) public{
        users.push(_usr);
        //previleges[_usr] = 2; //setta il creator a utente root
        //users.push(_usr);//aggiunge il creator alla lista di utenti
        //emit blocklockCreated(block.number, _usr);
    }

    /**
     * Garantisce i permessi di accesso base ad un nuovo utente
     **/
    function addUser(address _newUSer) onlyRoot(msg.sender) external{
        super.addUser(_newUSer);
        users.push(_newUSer);
        //previleges[_newUSer] = 1; //permessi base al nuovo utente
        //users.push(_newUSer); //aggiungo l'utente alla lista
        //aggregator.addUser(_newUSer); //questo è da gestire, perchè quando è scaduto il tempo andrebbe eliminato dall'aggregator
        //emit userAdded(block.number, msg.sender, _newUSer);
    }

    /**
     * aggiorna i permessi di un utente da base a root
     * richiede i permessi di root per effettuare l'upgrade
     **/
    function upgradeUser(address _stdUser) onlyRoot(msg.sender) isUser(_stdUser) external{
        super.upgradeUser(_stdUser);
        //previleges[_stdUser] = 2; //setto l'utente a root
        //emit userUpgraded(block.number, msg.sender, _stdUser);
    }

    /**
     * toglie i permessi di accesso ad un utente base o root
     * richiede i permessi di root
     **/
    function deleteUser(address _usr) onlyRoot(msg.sender) isUser(_usr) external{
        super.deleteUser(_usr);
        for(uint i = 0; i < users.length - 1; i++){
            if(users[i] == _usr){
                delete users[i];
                users[i] = users[users.length - 1];
            }
        }
        //previleges[_usr] = 0; //tolgo ogni tipo di permesso all'utente
        //aggregator.deleteUser(_usr); //lo elimino anche dall'aggregator in modo che non gli compaia più la porta
        //emit userDeleted(block.number, msg.sender, _usr);
    }

    function getUserRole(address _usr) external view onlyRoot(msg.sender) isUser(_usr) returns(uint8){
        return super.getUserRole();
    }

    function getMyRole() external view isUser(msg.sender) returns(uint8){
        return super.getMyRole();
    }

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

}

