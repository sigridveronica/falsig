```bash 
peer lifecycle chaincode package oemChaincode.tar.gz --path ./chaincode/oemContract/ --lang golang --label oemContract_1
```

```bash
./network.sh createChannel -c oemchannel
```
```bash
peer lifecycle chaincode package oemChaincode.tar.gz --path ./chaincode/oemContract/ --lang golang --label oemContract_1
./network.sh deployCC -ccn oemChaincode -ccp /chaincode/oemContract/ -ccl go
```

```bash
peer lifecycle chaincode queryinstalled
```

```bash
ls | grep oemChaincode.tar.gz 
```

```bash
tar -ztvf oemChaincode.tar.gz 
```
```bash
peer lifecycle chaincode install oemChaincode.tar.gz --path ./chaincode/oemContract/ --lang golang --label oemContract_1
./network.sh deployCC -ccn oemChaincode -ccp /chaincode/oemContract/ -ccl go
```
```bash
./network.sh createChannel -c oemchannel
```

```bash
Based on the provided Docker Compose configuration, here are the peer addresses for the new peers you've added:

QA1.1.oem.example.com
Address: QA1.1.oem.example.com:7051
QA1.2.oem.example.com
Address: QA1.2.oem.example.com:7051
SW1.1.oem.example.com
Address: SW1.1.oem.example.com:7051
SW1.2.oem.example.com
Address: SW1.2.oem.example.com:7051
SW1.3.oem.example.com
Address: SW1.3.oem.example.com:7051
QA2.1.supplier.example.com
Address: QA2.1.supplier.example.com:7051
QA3.1.airline.example.com
Address: QA3.1.airline.example.com:7051
```


#ADD NEW

```bash
cd /Users/sigridveronica/go/src/github.com/FAL/fabric-samples/test-network/compose/docker
```

```bash
docker-compose -f docker-compose-test-net.yaml down
docker-compose -f docker-compose-test-net.yaml up -d
```



##ADD
```bash
export FABRIC_CFG_PATH=$PWD/../config
```
```bash
export FABRIC_CFG_PATH=$PWD/configtx
```
```bash
export PATH=$PWD/../bin:$PATH
```
