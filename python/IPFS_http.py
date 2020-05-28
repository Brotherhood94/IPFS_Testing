import requests

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
