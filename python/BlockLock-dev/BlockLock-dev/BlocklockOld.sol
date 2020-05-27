pragma solidity ^0.5.4;

//solgraph
contract BlockLock {

    //struct contenente le informazioni relative alla porta
    struct infoLock{
      bool status;  //stato della porta, sarebbe meglio settato a true di default, false positive
      mapping (address => address) users; //set di users che hanno accesso alla porta
      mapping (address => address) roots; //set di root users che hanno accesso alla porta
    }

    mapping (uint256 => bytes32) idRasp2idDoor; //associa l'id del raspberry all'id della porta

    mapping (bytes32 => infoLock) idDoor2info; //associa id porta alla struct

    mapping (address => uint256[]) addressToDoors; //byte32 rimane nascosto —> top

    //getDoors

    //check che l'address non esista
    function addToDoors(uint256 idRasp, address addr) public{ //probabilmente non devo fare il check che non esista perchè è fatto implicitamente dalle funzioni che la chiamano
        addressToDoors[addr].push(idRasp);
    }

    function getDoors() public view returns (uint256[] memory doors){
      return addressToDoors[msg.sender]; //se non sono chi dico di essere, non posso accedere
    }

    //Elimina un utente da una certa porta
    function delFromDoors(uint256 idRasp, address addr) private{ //probabilmente non devo fare il check che non esista perchè è fatto implicitamente dalle funzioni che la chiamano
      uint[] storage doors = addressToDoors[addr];
      for(uint i = 0; i < doors.length; i++){   //Eventualmente senza swap
        if(doors[i] == idRasp){
          doors[i] = doors[doors.length-1];
          delete doors[doors.length-1];
          doors.length--;
          break;
        }
      }
    }


    //evento scatenato nel momento in cui avviene il cambio di stato della porta
    event changedDoor(
      uint256 indexed idRasp,  //indexed per poter identificare il log by idRasp
      bool status
    );

    //chiama l'event
    function setEventDoor(uint256 _idRasp, bool _status) private {
        emit changedDoor(_idRasp, _status);
    }

    //aggiunge una nuova serratura
    function addDoorLock(uint256 idRasp) external {    //block.timestamp non va bene -> sol oracle qualcosa (view)
      if(idRasp2idDoor[idRasp] != 0){   //caso in cui l'id del raspeberry è già stato assegnato
        infoLock storage info = getInfoLock(idRasp);
        require(info.roots[msg.sender] != address(0)); //chi ha inviato la transazione è root di quella porta
      }
      bytes32 idDoor = keccak256(abi.encode(msg.sender, block.timestamp, idRasp)); //genera l'id della porta
      idRasp2idDoor[idRasp] = idDoor;
      addToDoors(idRasp, msg.sender);
      addInfoLock(idDoor);
    }

    //popola la struct
    function addInfoLock(bytes32 idDoor) private {   //Root
      infoLock memory info = infoLock(false); //false di default
      idDoor2info[idDoor] = info;
      idDoor2info[idDoor].roots[msg.sender] = msg.sender;
    }

    //associa un nuovo utente
    function addUser(uint256 idRasp, address newUser) external{
      infoLock storage  info = getInfoLock(idRasp);
      require(info.roots[msg.sender] != address(0) && info.users[newUser] == address(0) && info.roots[newUser] == address(0)); //Sto dicendo che msg.sender è il root e che l'utente non esista già
      //Sono il root
      addToDoors(idRasp, newUser);
      info.users[newUser] = newUser;
    }

    //modifica i permessi dell'utente portandolo ad utente root
    function addUserToRoot(uint256 idRasp, address newUser) external{
      infoLock storage info = getInfoLock(idRasp);
      require(info.roots[msg.sender] != address(0));
      if(info.users[newUser] != address(0))    //sposto da users a roots, cancellando da users
        delete info.users[newUser];
      addToDoors(idRasp, newUser); //aggiunge l'utente alla porta
      info.roots[newUser] = newUser;
    }
//elimina un utente (non user) associato ad una porta
    function deleteUser(uint256 idRasp, address user) public{
      infoLock storage info = getInfoLock(idRasp);
      require(info.roots[msg.sender] != address(0) && info.users[user] != address(0));   //Check che il sender sia root e che esista così da garantire che delFromDoors non giri a vuoto
      delFromDoors(idRasp, user); //elimina contemporaneamente anche l'utente dalla lista degli utenti associati ad ogni porta
      delete info.users[user];
    }

    //view che restituisce lo stato della porta, essendo una view il gas non si paga
    function getInfoLock(uint256 idRasp) private view returns (infoLock storage info) {
      bytes32 idDoor = idRasp2idDoor[idRasp];
      info = idDoor2info[idDoor];
    }

    //cambia lo stato della porrta
    function changeDoorStatus(uint256 idRasp) external{
      infoLock storage info = getInfoLock(idRasp);
      require(info.roots[msg.sender] != address(0) || info.users[msg.sender] != address(0)); // controlla che l'utente che esegue la transazione sia contenuto tra gli users/root
      info.status = !info.status; //cambia lo stato
      setEventDoor(idRasp, info.status); //scatena l'evento che comunica al rpi il cambio di stato della porta
    }

    //restituisce stato porta, true se aperta false se chiusa
    function getDoorStatus(uint256 idRasp) public view returns (bool status) { //Raspberry Side
      infoLock storage info = getInfoLock(idRasp);
      status = info.status;
    }
    
    function closeContract() public{
        selfdestruct(address(0));
    }

}
