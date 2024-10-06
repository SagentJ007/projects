#!/bin/bash
echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/SagentJ007/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

# ������� ��� ������� ��������� � ������������
request_param() {
    read -p "$1: " param
    echo $param
}

# ����������� ��������� � ������������
echo "����������, ������� ��������� ��������� ��� ��������� ����:"
RPC_URL=$(request_param "������� RPC URL")
PRIVATE_KEY=$(request_param "������� ��� ��������� ���� (������������ � 0x)")

if [[ "$PRIVATE_KEY" == 0x* ]]; then
    echo "�� ����� ��������� ���� �����!"
else
    echo "��������� ���� ������ �� �����. ��������� ���� ������ ���������� � 0x"
    exit 1
fi

REGISTRY_ADDRESS=0x3B1554f346DFe5c482Bb4BA31b880c1C18412170
IMAGE="ritualnetwork/infernet-node:1.2.0"

echo "-----------------------------------------------------------------------------"
echo "������������� ����"
echo "-----------------------------------------------------------------------------"
sudo apt update -y
bash <(curl -s https://raw.githubusercontent.com/SagentJ007/tools/main/main.sh) &>/dev/null
bash <(curl -s https://raw.githubusercontent.com/SagentJ007/tools/main/ufw.sh) &>/dev/null
bash <(curl -s https://raw.githubusercontent.com/SagentJ007/tools/main/docker.sh) &>/dev/null

echo "-----------------------------------------------------------------------------"
echo "���� ����������� ���� ����������"
echo "-----------------------------------------------------------------------------"

# ������������ �����������
cd $HOME
git clone https://github.com/ritual-net/infernet-container-starter && cd infernet-container-starter
cp $HOME/infernet-container-starter/projects/hello-world/container/config.json $HOME/infernet-container-starter/deploy/config.json


# ������������ deploy/config.json
DEPLOY_JSON=$HOME/infernet-container-starter/deploy/config.json
sed -i 's|"rpc_url": "[^"]*"|"rpc_url": "'"$RPC_URL"'"|' "$DEPLOY_JSON"
sed -i 's|"private_key": "[^"]*"|"private_key": "'"$PRIVATE_KEY"'"|' "$DEPLOY_JSON"
sed -i 's|"registry_address": "[^"]*"|"registry_address": "'"$REGISTRY_ADDRESS"'"|' "$DEPLOY_JSON"
sed -i 's|"sleep": 3|"sleep": 5|' "$DEPLOY_JSON"
sed -i 's|"batch_size": 100|"batch_size": 1800, "starting_sub_id": 100000|' "$DEPLOY_JSON"

# ������������ container/config.json
CONTAINER_JSON=$HOME/infernet-container-starter/projects/hello-world/container/config.json

sed -i 's|"rpc_url": "[^"]*"|"rpc_url": "'"$RPC_URL"'"|' "$CONTAINER_JSON"
sed -i 's|"private_key": "[^"]*"|"private_key": "'"$PRIVATE_KEY"'"|' "$CONTAINER_JSON"
sed -i 's|"registry_address": "[^"]*"|"registry_address": "'"$REGISTRY_ADDRESS"'"|' "$CONTAINER_JSON"
sed -i 's|"sleep": 3|"sleep": 5|' "$CONTAINER_JSON"
sed -i 's|"batch_size": 100|"batch_size": 1800, "starting_sub_id": 100000|' "$CONTAINER_JSON"

# ������������ script/Deploy.s.sol
sed -i 's|address registry = .*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|' "$HOME/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol"

# ������������ contracts/Makefile
MAKEFILE=$HOME/infernet-container-starter/projects/hello-world/contracts/Makefile
sed -i 's|sender := .*|sender := '"$PRIVATE_KEY"'|' "$MAKEFILE"
sed -i 's|RPC_URL := .*|RPC_URL := '"$RPC_URL"'|' "$MAKEFILE"

# C���� ����������� ��� ������������� ����� ������������
sed -i 's|ritualnetwork/infernet-node:1.0.0|ritualnetwork/infernet-node:1.2.0|' $HOME/infernet-container-starter/deploy/docker-compose.yaml
sed -i 's|0.0.0.0:4000:4000|0.0.0.0:4321:4000|' $HOME/infernet-container-starter/deploy/docker-compose.yaml
sed -i 's|8545:3000|8845:3000|' $HOME/infernet-container-starter/deploy/docker-compose.yaml
sed -i 's|container_name: infernet-anvil|container_name: infernet-anvil\n    restart: on-failure|' $HOME/infernet-container-starter/deploy/docker-compose.yaml

docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml up -d

# ��������� Foundry
cd $HOME
mkdir -p foundry
cd foundry
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
echo 'export PATH="$PATH:/root/.foundry/bin"' >> .profile
source .profile

foundryup

# ��������� ������������ ��� ����������
cd $HOME/infernet-container-starter/projects/hello-world/contracts/lib/
rm -r forge-std
rm -r infernet-sdk
forge install --no-commit foundry-rs/forge-std
forge install --no-commit ritual-net/infernet-sdk

# Deploy Consumer Contract
cd $HOME/infernet-container-starter
project=hello-world make deploy-contracts >> logs.txt
CONTRACT_ADDRESS=$(grep "Deployed SaysHello" logs.txt | awk '{print $NF}')
rm -rf logs.txt

if [ -z "$CONTRACT_ADDRESS" ]; then
  echo -e "${err}��������� ������: �� ������� ��������� contractAddress �� $CONTRACT_DATA_FILE${end}"
  exit 1
fi

echo -e "${fmt}����� ������ ���������: $CONTRACT_ADDRESS${end}"
sed -i 's|0x13D69Cf7d6CE4218F646B759Dcf334D82c023d8e|'$CONTRACT_ADDRESS'|' "$HOME/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol"

# Call Consumer Contract
cd $HOME/infernet-container-starter
project=hello-world make call-contract

cd $HOME/infernet-container-starter/deploy

docker compose down
sleep 3
sudo rm -rf docker-compose.yaml
wget https://raw.githubusercontent.com/SagentJ007/guides/main/ritual/docker-compose.yaml
docker compose up -d

# docker rm -fv infernet-anvil  &>/dev/null

echo "-----------------------------------------------------------------------------"
echo "Installation finished"
echo "-----------------------------------------------------------------------------"