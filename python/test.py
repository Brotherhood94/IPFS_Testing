import json
import os


import datetime
from IPFS_http import IPFS_http

import pickle 

from access_control import AccessControl
import contract_abi
import threading

from dataclasses import dataclass

@dataclass
class UserInfo:
    rights : int
    blockNumber : int
    sender : str


class Layer:
    def __init__(self, ipfs_http, access_control, max_size_log, pin=False, log_path='./'):
        self.ipfs_http = ipfs_http
        self.access_control = access_control
        self.max_size_log = max_size_log
        self.log_path = log_path
        self.pin = pin
        self.acl_path = './acl_'+str(self.access_control.getSmartContractAddress())+'.pkl'
        self.lock = threading.Lock()
        self.file_log_path = self.__get_new_log_file() 
        self.acl_dict = self.__load_acl()
        print(self.file_log_path)

    def __get_new_log_file(self):
        timestamp = datetime.datetime.now().isoformat()
        name = 'IPFS_log_'+timestamp+'.log'
        path = self.log_path+name
        open(path,"w")
        return path


    def __write_logs(self, data):
        with open(self.file_log_path, 'a') as logs: #append only
            logs.write(data+'\n')
            size = os.stat(self.file_log_path)
        logs.close()
        return size

#Come eravamo rimasti? dovrebbe anche caricarle su bc?
# Basta una funzione che lancia solo un event avente come field il valore del multihash
    def ipfs_log(self, data): 
        size = os.stat(self.file_log_path).st_size
        if size > self.max_size_log:
            res_add = self.ipfs_http.add(self.file_log_path)
            print(res_add['Hash'])
            self.file_log_path = self.__get_new_log_file();
            res_pubsub_pub = self.ipfs_http.pubsub_pub('logs_by_'+self.ipfs_http.id, res_add['Hash']+'\n')
            if self.pin:
                print("--- Pinning")
                res_pin = self.ipfs_http.pin_add(res_add['Hash'])
                print(res_pin)
            print('--- New Log File: '+self.file_log_path)
            self.__write_logs(res_add['Hash']) #Multiaddress file log precedente
        else:
            self.__write_logs(data)


#lancia thread di listening, prende valore dell'event. Inserisce valore evento
#in una propria struttura dati


# --> Ci potrebbe essere problemi: più thread voglono scrivere sul file
    def ipfs_access_control_UserAdded(self):
        user_added_filter = self.access_control.getEventUserAdded()
        while True:
            for event in  user_added_filter.get_new_entries():
                print(event)
                block = int(event['args']['block'])
                fromUser = str(event['args']['fromUser'])
                to = str(event['args']['to'])
                self.acl_dict[to] = UserInfo(1, block, fromUser)
                self.__save_and_publish_acl()
        
    def ipfs_access_control_UserUpgraded(self): 
        user_upgraded_filter = self.access_control.getEventUserUpgraded()
        while True:
            for event in  user_upgraded_filter.get_new_entries():
                print(event)
                block = int(event['args']['block'])
                fromUser = str(event['args']['fromUser'])
                to = str(event['args']['to'])
                self.acl_dict[to] = UserInfo(2, block, fromUser)
                self.__save_and_publish_acl()

    def ipfs_access_control_UserDeleted(self): 
        user_deleted_filter = self.access_control.getEventUserDeleted()
        while True:
            for event in  user_deleted_filter.get_new_entries():
                print(event)
                block = int(event['args']['block'])
                fromUser = str(event['args']['fromUser'])
                to = str(event['args']['to'])
                self.acl_dict[to] = UserInfo(0, block, fromUser)
                self.__save_and_publish_acl()


    def __load_acl(self): 
        try: 
            self.lock.acquire()
            with open(self.acl_path, 'rb') as f:
                 loaded = pickle.load(f)
            self.lock.release()
            return loaded
        except FileNotFoundError:
            print("File Not Found")
            return {}

    def __save_and_publish_acl(self): #update publish
        self.lock.acquire()
        with open(self.acl_path, 'wb') as f:
            pickle.dump(self.acl_dict, f, pickle.HIGHEST_PROTOCOL)
        res_add = self.ipfs_http.add(self.acl_path)
        print('To be published' + str(res_add['Hash']))
        print("--- Pinning")
        res_pin = self.ipfs_http.pin_add(res_add['Hash'])
        print(res_pin)
        res_publish = self.ipfs_http.publish(res_add['Hash'])
        print(" Published: ") #Il dove viene pubblicato è importante per scaricare il file
        print(res_publish)
        self.lock.release()




# SmartContractINFOS
providerURL = "wss://rinkeby.infura.io/_ws"
smart_contract_address = "0xC1D3f319947bD3C79D8F63B3aE4cB3126181ED0c"

ipfs_http = IPFS_http('http://127.0.0.1:5001/api/v0/')
access_control = AccessControl.Factory(providerURL, smart_contract_address, contract_abi.abi)

layer = Layer(ipfs_http, access_control, 50, pin=True, log_path='./logs/')
#Abbiamo gli event, ed ok.
#La lista degli accessi invece, deve poter essere aggiornabile
#ipfs anche sul cellulare? Pinnano i loro che gli interessano

for i in range(1, 30):
    layer.ipfs_log('Ciao')




'''
res = requests.post("http://127.0.0.1:5001/api/v0/pubsub/sub?arg=foo", stream=True)
if res.encoding is None:
    res.encoding = 'utf-8'
print(res.status_code)
for line in res.iter_lines(decode_unicode=True):
    if line:
        print(json.loads(line))
'''
        



