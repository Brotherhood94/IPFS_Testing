import requests
import json
import os


import datetime


from access_control import AccessControl
import contract_abi
import threading

#--> --enable-namesys-pubsub 
class IPFS_http:
    def __init__(self, url_base):
        self.url_base = url_base #http://127.0.0.1:5001/api/v0/
        self.id = requests.post(url_base+'id').json()['ID']
        print('ID: '+self.id)

    def id(self):
        return requests.post(self.url_base+'id').json()

    def add(self, file_path):
        files={'files': open(file_path,'rb')}
        return requests.post(self.url_base+'add', files=files).json()

    def cat(self, ipfs_path):
        return requests.post(self.url_base+'cat?arg='+ipfs_path)

    def bootstrap_add(self, multiaddrPeerID):
        return requests.post(self.url_base+'bootstrap/add?arg='+multiaddrPeerID).json()

    def bootstrap_rm(self, multiaddrPeerID):
        return requests.post(self.url_base+'bootstrap/rm?arg='+multiaddrPeerID).json()

    def bootstrap_list(self):
        return requests.post(self.url_base+'bootstrap/list').json()

    def connect(self, address):
        return requests.post(self.url_base+'swarm/connect?arg'+address).json()
    
    def disconnect(self, address):
        return requests.post(self.url_base+'swarm/disconnect?arg'+address).json()
    
    def get(self, ipfs_path):
        return requests.post(self.url_base+'get?arg='+ipfs_path)

    def pubsub_subs_ls(self):
        return requests.post(self.url_base+'pubsub/ls').json()
    
    def pubsub_sub(self, topic):
        return requests.post(self.url_base+'pubsub/sub?arg='+topic, stream=True)

    def pubsub_pub(self, topic, message):
        return requests.post(self.url_base+'pubsub/pub?arg='+topic+'&arg='+message)

    def pin_add(self, ipfs_path):
        return requests.post(self.url_base+'pin/add?arg='+ipfs_path).json()

    def pin_update(self, old_ipfs_path, new_ipfs_path):
        return requests.post(self.url_base+'pin/update?arg='+old_ipfs_path+'arg='+new_ipfs_path).json()

    def key_gen(self, name):
        return requests.post(self.url_base+'key/gen?arg='+name).json()

    def key_list(self):
        return requests.post(self.url_base+'key/list').json()

    def publish(self, ipfs_path, key:'self'):
        return requests.post(self.url_base+'name/publish?arg='+ipfs_path+'&key='+key).json()


class Layer:
    def __init__(self, ipfs_http, max_size_log, pin=False, log_path='./'):
        self.ipfs_http = ipfs_http
        self.max_size_log = max_size_log
        self.log_path = log_path
        self.file_log_path = self.__get_new_log_file() 
        self.pin = pin
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



    def ipfs_access_control_UserAdded(self): 
        

    def ipfs_access_control_UserUpgraded(self): 


    def ipfs_access_control_UserDeleted(self): 



# SmartContractINFOS
providerURL = "wss://rinkeby.infura.io/_ws"
smart_contract_address = "0xC1D3f319947bD3C79D8F63B3aE4cB3126181ED0c"

ipfs_http = IPFS_http('http://127.0.0.1:5001/api/v0/')
access_control = AccessControl.Factory(providerURL, smart_contract_address, contract_abi.abi)

layer = Layer(ipfs_http, 50, pin=True)
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
        



