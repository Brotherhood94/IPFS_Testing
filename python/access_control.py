from web3 import Web3, WebsocketProvider


class AccessControl:
    # Singleton
    __instance = None

    # PrivateVariable
    __contract = None
    __providerURL = None
    __address = None

    @staticmethod
    def Factory(providerURL, smart_contract_address, abi):
        if AccessControl.__instance == None:
            AccessControl(providerURL, smart_contract_address, abi)
        return AccessControl.__instance

    # Virtually private constructor
    # Since python do not permit private field, the only way to ensure that the constructor will never invoked is this.
    def __init__(self, providerURL, smart_contract_address, abi):
        if AccessControl.__instance != None:
            raise Exception("This class is a singleton.")
        else:
            AccessControl.__instance = self
            AccessControl.__providerURL = providerURL
            AccessControl.__address = smart_contract_address
            AccessControl.__settingUp(self, smart_contract_address, abi)

    # Private
    def __settingUp(self, smart_contract_address, abi):
        web3 = Web3(WebsocketProvider(AccessControl.__providerURL))
        res = web3.toChecksumAddress(smart_contract_address) #controlla che lo smart contract sia valido
        AccessControl.__contract = web3.eth.contract(address= res, abi= abi)

    def getContract(self):
        return AccessControl.__contract

    def getSmartContractAddress(self):
        return AccessControl.__address

    def getProvider(self):
        return AccessControl.__providerURL

    def getEventUserAdded(self):
        return AccessControl.__contract.events.userAdded.createFilter(fromBlock=0, toBlock='latest')

    def getEventUserUpgraded(self):
        return AccessControl.__contract.events.userUpgraded.createFilter(fromBlock=0, toBlock='latest')

    def getEventUserDeleted(self):
        return AccessControl.__contract.events.userDeleted.createFilter(fromBlock=0, toBlock='latest')
