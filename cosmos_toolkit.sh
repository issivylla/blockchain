#!/bin/bash

#####################################################################################################################################################################
#                                                                              INSTALL                                                                              #
#####################################################################################################################################################################


function functionPrepareEnvironment {

    echo -e '    '
    echo -e '    \e[31m'
    echo -e '    ██████   █████  ███    ██  ██████  ███████ ██████  ██'
    echo -e '    ██   ██ ██   ██ ████   ██ ██       ██      ██   ██ ██'
    echo -e '    ██   ██ ███████ ██ ██  ██ ██   ███ █████   ██████  ██'
    echo -e '    ██   ██ ██   ██ ██  ██ ██ ██    ██ ██      ██   ██   '
    echo -e '    ██████  ██   ██ ██   ████  ██████  ███████ ██   ██ ██'
    echo -e '    \e[0m'
    echo -e '    '
    
    while true; do
    echo -e $'[\e[31m!\e[0m] This operation will damage the installed cosmos node if you are going to install the same for current user'
    echo '    If you are going to install another cosmos node - no worries'
    echo '    Please note that all variables in the file $HOME/.bash_profile will be removed'
    read -e -p $'[\e[33m?\e[0m] Do you want to proceed? (y/n) ' yn
    case $yn in 
        [yY] )
            break
            ;;
        [nN] ) 
            exit -1
            ;;
        esac
    done
    
    echo -e $'[\e[36m*\e[0m] Cleaning environment' && sleep 1
    > $HOME/.bash_profile
}


function functionInstallGo {
    echo -e $'[\e[36m*\e[0m] Installing Go' && sleep 1
    ver="1.20.2"
    cd $HOME
    wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" > /dev/null 2>&1
    sudo rm -rf /usr/local/go > /dev/null 2>&1
    sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" > /dev/null 2>&1
    rm "go$ver.linux-amd64.tar.gz" > /dev/null 2>&1
    echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
    echo "export GOPATH=$HOME/go" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    ver=$(go version | { read _ _ v _; echo ${v#go}; })
    echo -e "[\e[1m\e[32m*\e[0m] Go ${ver} has been installed"
}

function functionInstallDependencies {
    echo -e $'[\e[36m*\e[0m] Installing dependencies' && sleep 1
    sudo apt update -y > /dev/null 2>&1
    sudo apt install -y curl git jq lz4 build-essential unzip snapd > /dev/null 2>&1
    sudo snap install lz4 > /dev/null 2>&1
    echo -e $'[\e[32m*\e[0m] Dependencies have been installed' && sleep 1
}

function functionBuildBinaries {
    while true; do
        read -e -p $'[\e[33m?\e[0m] Please provide the github project URL: ' GITHUB_URL
        if curl --head --silent --fail $GITHUB_URL > /dev/null 2>&1; then
            break
        else
            echo -e $'[\e[31m!\e[0m] The github project is not available, please provide correct URL'
        fi
    done
    
    GITHUB_FOLDER_NAME=$(basename ${GITHUB_URL} .git)
    GITHUB_FOLDER='$HOME/'"$GITHUB_FOLDER_NAME"
    cd ${HOME} || return
    
    if [ -d ${GITHUB_FOLDER} ]; then
        echo -e $'[\e[36m*\e[0m] Removing the old daemon github folder' && sleep 1
        rm -rf ${GITHUB_FOLDER}
    fi
    
    echo -e $'[\e[36m*\e[0m] Downloading the daemon github project' && sleep 1
    git clone ${GITHUB_URL}  > /dev/null 2>&1
    cd ${GITHUB_FOLDER_NAME} || return

    echo -e $'[\e[36m*\e[0m] Saving data about github project into environment variables' && sleep 1
    echo "export GITHUB_URL=${GITHUB_URL}" >> $HOME/.bash_profile
    echo "export GITHUB_FOLDER=${GITHUB_FOLDER}" >> $HOME/.bash_profile
    echo "    export GITHUB_URL=${GITHUB_URL}"
    echo "    export GITHUB_FOLDER=${GITHUB_FOLDER}"
    source $HOME/.bash_profile

    while true; do
        user_project=$(git config --get remote.origin.url | sed 's/.*\/\([^ ]*\/[^.]*\).*/\1/')
        VERSION=$(curl https://api.github.com/repos/${user_project}/releases/latest -s | jq .name -r)
        read -e -p $'[\e[33m?\e[0m] Please enter specific version or approve the latest release (or commit): ' -i "${VERSION}" version
        VERSION=${version:-${VERSION}}
        if git checkout ${VERSION}  > /dev/null 2>&1; then
            break
        else
            echo -e $'[\e[31m!\e[0m] The version is not avilabile in the project, please provide another'
        fi
    done
    
    echo -e $'[\e[36m*\e[0m] Bulding the daemon binaries fromm the source' && sleep 1
    make install  > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Saving the daemon name into environment variables' && sleep 1
    DAEMON_NAME=$(ls $HOME/go/bin -t | head -n 1)
    echo "export DAEMON_NAME=${DAEMON_NAME}" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    echo "    export DAEMON_NAME=${DAEMON_NAME}"
    
    VERSION=$($HOME/go/bin/${DAEMON_NAME} version 2>&1)
    echo -e "[\e[1m\e[32m*\e[0m] The daemon ${DAEMON_NAME} with version ${VERSION} has been built"
    cd ${HOME} || return
    
    read -e -p $'[\e[33m?\e[0m] Please provide the node name: ' -i "[NODERS]TEAM" NODENAME
    echo -e $'[\e[36m*\e[0m] Saving the node name into environment variables' && sleep 1
    echo "export NODENAME=${NODENAME}" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    echo "    export NODENAME=${NODENAME}"
    
    read -e -p $'[\e[33m?\e[0m] Please provide the chain ID: ' CHAIN_ID
    echo -e $'[\e[36m*\e[0m] Saving the chain ID into environment variables' && sleep 1
    echo "export CHAIN_ID=${CHAIN_ID}" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    echo "    export CHAIN_ID=${CHAIN_ID}"
    
    echo -e $"[\e[36m*\e[0m] Applying chain ID ${CHAIN_ID} for the client configuration" && sleep 1
    ${DAEMON_NAME} config chain-id ${CHAIN_ID}

    echo -e $"[\e[36m*\e[0m] Applying keyring backend OS for the client configuration" && sleep 1
    ${DAEMON_NAME} config keyring-backend os

    echo -e $"[\e[36m*\e[0m] Initializing the node with the name ${NODENAME} and chain ID ${CHAIN_ID}" && sleep 1
    ${DAEMON_NAME} init $NODENAME --chain-id $CHAIN_ID > /dev/null 2>&1
    
    DAEMON_HOME="$HOME/$(ls -tGA $HOME | grep ^\.${DAEMON_NAME:0:2}.* | head -1)"
    read -e -p $'[\e[33m?\e[0m] Please confirm or change the daemon home folder: ' -i "$DAEMON_HOME" DAEMON_HOME
    
    echo -e $'[\e[36m*\e[0m] Saving the daemon home folder into environment variables' && sleep 1
    echo "export DAEMON_HOME=${DAEMON_HOME}" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    echo "    export DAEMON_HOME=${DAEMON_HOME}"
    
    while true; do
        read -e -p $'[\e[33m?\e[0m] Please provide the node ports (10-65): ' -i "26" PORT
        if [ $PORT -ge 10 ] && [ $PORT -le 65 ]; then
            echo -e $"[\e[36m*\e[0m] Applying the node ports" && sleep 1
            if [ $PORT -ne 26 ] ; then
                sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${PORT}658\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${PORT}657\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${PORT}060\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${PORT}656\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${PORT}660\"%" ${DAEMON_HOME}/config/config.toml
                sed -i.bak -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:${PORT}317\"%; s%^address = \":8080\"%address = \":${PORT}080\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:${PORT}090\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:${PORT}091\"%" ${DAEMON_HOME}/config/app.toml
            fi
            break
        else
            echo -e $'[\e[31m!\e[0m] The URL for genesis is not available, please provide correct URL'
        fi
    done
    
    echo -e $'[\e[36m*\e[0m] Saving the node ports into environment variables' && sleep 1
    echo "export PORT=${PORT}" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    echo "    export PORT=${PORT}"
    
    echo -e $"[\e[36m*\e[0m] Applying the RPC port ${PORT}657 for the client configuration" && sleep 1
    ${DAEMON_NAME} config node tcp://localhost:${PORT}657
    
    echo -e $'[\e[36m*\e[0m] Installing cosmovisor' && sleep 1
    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0 > /dev/null 2>&1
    
    VERSION=$($HOME/go/bin/${DAEMON_NAME} version 2>&1)
    read -e -p $'[\e[33m?\e[0m] Please confirm or modify the binary cosmovisor folder name: ' -i "$VERSION" VERSION
    
    echo -e $'[\e[36m*\e[0m] Creating initial folders for cosmovisor' && sleep 1
    mkdir -p ${DAEMON_HOME}/cosmovisor/genesis/bin
    mkdir -p ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin
        echo "    ${DAEMON_HOME}/cosmovisor/genesis/bin"
        echo "    ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin"
    
    echo -e $'[\e[36m*\e[0m] Moving built daemon binaries to cosmovisor folder' && sleep 1
    mv $HOME/go/bin/${DAEMON_NAME} ${DAEMON_HOME}/cosmovisor/genesis/bin/.
    cp ${DAEMON_HOME}/cosmovisor/genesis/bin/${DAEMON_NAME} ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin/.
    
    echo -e $'[\e[36m*\e[0m] Creating current path link for cosmovisor' && sleep 1
    rm ${DAEMON_HOME}/cosmovisor/current > /dev/null 2>&1
    ln -s ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION} ${DAEMON_HOME}/cosmovisor/current
    
    echo -e $'[\e[36m*\e[0m] Creating binary link to binary in current path' && sleep 1
    mkdir -p ${HOME}/go/bin
    rm ${HOME}/go/bin/${DAEMON_NAME} > /dev/null 2>&1
    ln -s ${DAEMON_HOME}/cosmovisor/current/bin/${DAEMON_NAME} ${HOME}/go/bin/${DAEMON_NAME}
    
    read -e -p $'[\e[33m?\e[0m] Please the blockchain currency (denom, with the leading u or a letter): ' DENOM
    echo -e $"[\e[36m*\e[0m] Changing minimum gas prices to 0.0001${DENOM}" && sleep 1
    sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0001$DENOM\"/" ${DAEMON_HOME}/config/app.toml
    
    echo -e $'[\e[36m*\e[0m] Saving the daemon currency (denom) into environment variables' && sleep 1
    echo "export DENOM=${DENOM}" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    echo "    export DENOM=${DENOM}"
    
    echo -e $"[\e[36m*\e[0m] Applying pruning settings (100/0/10)" && sleep 1
    pruning="custom"
    pruning_keep_recent="100"
    pruning_keep_every="0"
    pruning_interval="10"
    sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" ${DAEMON_HOME}/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" ${DAEMON_HOME}/config/app.toml
    sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" ${DAEMON_HOME}/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" ${DAEMON_HOME}/config/app.toml
    
    echo -e $"[\e[36m*\e[0m] Adjusting peer settings (filter peers enabled, inbound peers set to 50, outbound peers set to 50)" && sleep 1
    sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" ${DAEMON_HOME}/config/config.toml
    sed -i 's/max_num_inbound_peers =.*/max_num_inbound_peers = 50/g' ${DAEMON_HOME}/config/config.toml
    sed -i 's/max_num_outbound_peers =.*/max_num_outbound_peers = 50/g' ${DAEMON_HOME}/config/config.toml
    
    echo -e $"[\e[36m*\e[0m] Disabling indexer" && sleep 1
    indexer="null"
    sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" ${DAEMON_HOME}/config/config.toml

    echo -e $"[\e[36m*\e[0m] Enabling prometheus" && sleep 1
    sed -i -e "s/prometheus = false/prometheus = true/" ${DAEMON_HOME}/config/config.toml

    while true; do
        read -e -p $'[\e[33m?\e[0m] Please provide the download URL for genesis: ' GENESIS_URL
        if curl --head --silent --fail $GENESIS_URL > /dev/null 2>&1; then
            echo -e $"[\e[36m*\e[0m] Downloading and applying genesis" && sleep 1
            curl -s ${GENESIS_URL} > ${DAEMON_HOME}/config/genesis.json
            break
        else
            echo -e $'[\e[31m!\e[0m] The URL for genesis is not available, please provide correct URL'
        fi
    done
    
    while true; do
        read -e -p $'[\e[33m?\e[0m] Please provide the download URL for address book: ' ADDRBOOK_URL
        if curl --head --silent --fail $ADDRBOOK_URL > /dev/null 2>&1; then
        echo -e $"[\e[36m*\e[0m] Downloading and applying address book" && sleep 1
        curl -s ${ADDRBOOK_URL} > ${DAEMON_HOME}/config/addrbook.json
            break
        else
            echo -e $'[\e[31m!\e[0m] The URL for address book is not available, please provide correct URL'
        fi
    done

    read -e -p $'[\e[33m?\e[0m] Please provide the seeds (comma separated): ' SEEDS
    read -e -p $'[\e[33m?\e[0m] Please provide the peers (comma separated): ' PEERS
    echo -e $"[\e[36m*\e[0m] Applying seeds and peers" && sleep 1
    sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' ${DAEMON_HOME}/config/config.toml

    echo -e $"[\e[36m*\e[0m] Creating service file" && sleep 1
# do not change this code, or else EOF will not work 
cat > $HOME/${DAEMON_NAME}.service << EOF
[Unit]
Description=${DAEMON_NAME} node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=${DAEMON_HOME}"
Environment="DAEMON_NAME=${DAEMON_NAME}"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="UNSAFE_SKIP_BACKUP=true"

[Install]
WantedBy=multi-user.target
EOF
# end
    sudo mv $HOME/${DAEMON_NAME}.service /etc/systemd/system/${DAEMON_NAME}.service

    echo -e $"[\e[36m*\e[0m] Launching the daemon" && sleep 1
    sudo systemctl daemon-reload > /dev/null 2>&1
    sudo systemctl enable ${DAEMON_NAME} > /dev/null 2>&1
    sudo systemctl restart ${DAEMON_NAME} > /dev/null 2>&1
    
    while true; do
    read -e -p $'[\e[33m?\e[0m] Would you like to setup statesync (y/n) ' yn
    case $yn in 
        [yY] )
            functionStatesync
            break
            ;;
        [nN] ) 
            break
            ;;
        esac
    done
    
    while true; do
    read -e -p $'[\e[33m?\e[0m] Would you like to connect wallet (y/n) ' yn
    case $yn in 
        [yY] )
            functionWallet
            break
            ;;
        [nN] ) 
            break
            ;;
        esac
    done
    
    while true; do
    read -e -p $'[\e[33m?\e[0m] Would you like to setup healthcheck (y/n) ' yn
    case $yn in 
        [yY] )
            functionHealthcheck
            break
            ;;
        [nN] ) 
            break
            ;;
        esac
    done
    
    echo -e $'[\e[32m*\e[0m] Install operation has been finished' && sleep 1
    
    echo -e $"[\e[36m*\e[0m] Running journalctl to see the daemon logs" && sleep 1
    sudo journalctl -fu ${DAEMON_NAME} --no-hostname -o cat | grep -E 'height|sync|snapshot'

}

#####################################################################################################################################################################
#                                                                               UPDATE                                                                              #
#####################################################################################################################################################################


function functionUpdate {

    source $HOME/.bash_profile > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Validating environment' && sleep 1
    if [ ! $DAEMON_HOME ] || [ ! $DAEMON_NAME ] || [ ! $GITHUB_FOLDER ]; then
        echo -e $'[\e[31m!\e[0m] Environment is not set correctly'
        echo -e $'    Ensure you have set the following environment variables or launch installation'
        echo '    export DAEMON_HOME=<daemon home folder path> >> $HOME/.bash_profile'
        echo '    export DAEMON_NAME=<daemon name> >> $HOME/.bash_profile'
        echo '    export GITHUB_FOLDER=<github project folder path> >> $HOME/.bash_profile'
        exit -1
    fi
    
    echo -e $'[\e[36m*\e[0m] Pulling updates for github repository' && sleep 1
    cd ${GITHUB_FOLDER} || return
    git pull  > /dev/null 2>&1
    
    while true; do
        user_project=$(git config --get remote.origin.url | sed 's/.*\/\([^ ]*\/[^.]*\).*/\1/')
        VERSION=$(curl https://api.github.com/repos/${user_project}/releases/latest -s | jq .name -r)
        read -e -p $'[\e[33m?\e[0m] Please enter specific version or approve the latest release (or commit): ' -i "${VERSION}" version
        VERSION=${version:-${VERSION}}
        if git checkout ${VERSION} > /dev/null 2>&1; then
            break
        else
            echo -e $'[\e[31m!\e[0m] The version is not avilabile in the project, please provide another'
        fi
    done
    
    echo -e $'[\e[36m*\e[0m] Bulding the daemon binaries fromm the source' && sleep 1
    rm ${HOME}/go/bin/${DAEMON_NAME} > /dev/null 2>&1
    make install > /dev/null 2>&1
    
    VERSION=$($HOME/go/bin/${DAEMON_NAME} version 2>&1)
    echo -e "[\e[1m\e[32m*\e[0m] The daemon ${DAEMON_NAME} with version ${VERSION} has been built"
    cd ${HOME} || return
    
    VERSION=$($HOME/go/bin/${DAEMON_NAME} version 2>&1)
    read -e -p $'[\e[33m?\e[0m] Please confirm or modify the binary cosmovisor folder name: ' -i "$VERSION" VERSION
    
    echo -e $'[\e[36m*\e[0m] Creating upgrade directory for cosmovisor' && sleep 1
    rm -rf ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin > /dev/null 2>&1
    mkdir -p ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin
        echo "    ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin"
        
    echo -e $'[\e[36m*\e[0m] Moving built daemon binaries to cosmovisor folder' && sleep 1
    mv $HOME/go/bin/${DAEMON_NAME} ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin/.
    
    echo -e $'[\e[36m*\e[0m] Creating binary link to binary in current path' && sleep 1
    mkdir -p ${HOME}/go/bin
    rm ${HOME}/go/bin/${DAEMON_NAME} > /dev/null 2>&1
    ln -s ${DAEMON_HOME}/cosmovisor/current/bin/${DAEMON_NAME} ${HOME}/go/bin/${DAEMON_NAME}
    
    echo -e $'[\e[36m*\e[0m] Restarting the daemon' && sleep 1
    sudo systemctl restart ${DAEMON_NAME} > /dev/null 2>&1
    
    echo -e '    '
    echo -e '    \e[31m'
    echo -e '    ██████   █████  ███    ██  ██████  ███████ ██████  ██'
    echo -e '    ██   ██ ██   ██ ████   ██ ██       ██      ██   ██ ██'
    echo -e '    ██   ██ ███████ ██ ██  ██ ██   ███ █████   ██████  ██'
    echo -e '    ██   ██ ██   ██ ██  ██ ██ ██    ██ ██      ██   ██   '
    echo -e '    ██████  ██   ██ ██   ████  ██████  ███████ ██   ██ ██'
    echo -e '    \e[0m'
    echo -e '    '
    
    while true; do
    read -e -p $'[\e[33m?\e[0m] Cosmovisor will update the version upon the proposal, would you update the version right now? (y/n) ' yn
    case $yn in 
        [yY] )
            echo -e $'[\e[36m*\e[0m] Creating current path link for cosmovisor' && sleep 1
            rm ${DAEMON_HOME}/cosmovisor/current > /dev/null 2>&1
            ln -s ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION} ${DAEMON_HOME}/cosmovisor/current
            
            echo -e $'[\e[36m*\e[0m] Restarting the daemon' && sleep 1
            sudo systemctl restart ${DAEMON_NAME} > /dev/null 2>&1
            break
            ;;
        [nN] ) 
            break
            ;;
        esac
    done
    
    echo -e $'[\e[32m*\e[0m] Update operation has been finished' && sleep 1

}


#####################################################################################################################################################################
#                                                                             STATESYNC                                                                             #
#####################################################################################################################################################################


function functionStatesync {

    source $HOME/.bash_profile > /dev/null 2>&1
    
    if [ ! -f $(which curl) ]; then
        echo -e $'[\e[36m*\e[0m] Installing curl' && sleep 1
        sudo apt install curl -y > /dev/null 2>&1
    fi
      
    echo -e $'[\e[36m*\e[0m] Validating environment' && sleep 1
    if [ ! $DAEMON_HOME ] || [ ! $DAEMON_NAME ]; then
        echo -e $'[\e[31m!\e[0m] Environment is not set correctly'
        echo -e $'    Ensure you have set the following environment variables or launch installation'
        echo '    export DAEMON_HOME=<daemon home folder path> >> $HOME/.bash_profile'
        echo '    export DAEMON_NAME=<daemon name> >> $HOME/.bash_profile'
        exit -1
    fi
    
    read -e -p $'[\e[33m?\e[0m] Please provide the RPC node for statesync: ' SNAP_RPC
    if curl --head --silent --fail $SNAP_RPC > /dev/null 2>&1; then
        echo -e $'[\e[32m*\e[0m] The RPC node is available'
    else
        echo -e $'[\e[31m!\e[0m] The RPC node is not available'
        echo -e $'    Please, find available RPC node for statesync and launch the operation once again'
        exit -1
    fi

    SNAP_INTERVAL=2000
    echo -e $"[\e[36m*\e[0m] Applying snapshot interval 2000" && sleep 1
    sed -i.bak -e "s/^snapshot-interval *=.*/snapshot-interval = \"$SNAP_INTERVAL\"/" ${DAEMON_HOME}/config/app.toml
    
    echo -e $'[\e[36m*\e[0m] Calculating statesync parameters' && sleep 1
    LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height)
    BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000))
    TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
    echo -e "[\e[36m*\e[0m] Statesync parameters: latest height ${LATEST_HEIGHT}, block height ${BLOCK_HEIGHT}, trust hash ${TRUST_HASH}"
    
    echo -e '    '
    echo -e '    \e[31m'
    echo -e '    ██████   █████  ███    ██  ██████  ███████ ██████  ██'
    echo -e '    ██   ██ ██   ██ ████   ██ ██       ██      ██   ██ ██'
    echo -e '    ██   ██ ███████ ██ ██  ██ ██   ███ █████   ██████  ██'
    echo -e '    ██   ██ ██   ██ ██  ██ ██ ██    ██ ██      ██   ██   '
    echo -e '    ██████  ██   ██ ██   ████  ██████  ███████ ██   ██ ██'
    echo -e '    \e[0m'
    echo -e '    '
    
    while true; do
    read -e -p $'[\e[33m?\e[0m] The following operation will reset tandermint data, do you want to proceed? (y/n) ' yn
    case $yn in 
        [yY] ) 
            break;;
        [nN] ) 
            echo -e $'[\e[36m*\e[0m] The operation has been halted' && sleep 1
            exit -1
            ;;
        esac
    done
    
    echo -e $'[\e[36m*\e[0m] Halting the daemon' && sleep 1
    sudo systemctl stop ${DAEMON_NAME} > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Deleting tandermint data' && sleep 1
    ${DAEMON_NAME} tendermint unsafe-reset-all --home ${DAEMON_HOME} --keep-addr-book > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Saving validator current state' && sleep 1
    cp ${DAEMON_HOME}/data/priv_validator_state.json ${DAEMON_HOME}/priv_validator_state.json.backup
    
    echo -e $'[\e[36m*\e[0m] Appliyng statesync parameters' && sleep 1
    sed -i 's|^enable *=.*|enable = true|' ${DAEMON_HOME}/config/config.toml
    sed -i 's|^rpc_servers *=.*|rpc_servers = "'$SNAP_RPC,$SNAP_RPC'"|' ${DAEMON_HOME}/config/config.toml
    sed -i 's|^trust_height *=.*|trust_height = '$BLOCK_HEIGHT'|' ${DAEMON_HOME}/config/config.toml
    sed -i 's|^trust_hash *=.*|trust_hash = "'$TRUST_HASH'"|' ${DAEMON_HOME}/config/config.toml
    
    echo -e $'[\e[36m*\e[0m] Restoring validator previous state' && sleep 1
    mv ${DAEMON_HOME}/priv_validator_state.json.backup ${DAEMON_HOME}/data/priv_validator_state.json
    
    echo -e $'[\e[36m*\e[0m] Launching the daemon' && sleep 1
    sudo systemctl restart ${DAEMON_NAME} > /dev/null 2>&1
    
    echo -e $'[\e[32m*\e[0m] Statesync operation has been finished' && sleep 1

}


#####################################################################################################################################################################
#                                                                               WALLET                                                                              #
#####################################################################################################################################################################


function functionWallet {

    source $HOME/.bash_profile > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Validating environment' && sleep 1
    if [ ! $DAEMON_HOME ] || [ ! $DAEMON_NAME ]; then
        echo -e $'[\e[31m!\e[0m] Environment is not set correctly'
        echo -e $'    Ensure you have set the following environment variables or launch installation'
        echo '    export DAEMON_HOME=<daemon home folder path> >> $HOME/.bash_profile'
        echo '    export DAEMON_NAME=<daemon name> >> $HOME/.bash_profile'
        exit -1
    fi

    read -e -p $'[\e[33m?\e[0m] Please provide the wallet name: ' -i "[NODERS]TEAM" WALLET
    
    if ls -al ${DAEMON_HOME} | grep -F "${WALLET}" > /dev/null 2>&1; then
        while true; do
        read -e -p $'[\e[33m?\e[0m] The wallet with this name had already connected? Would you like to delete it? (y/n) ' yn
        case $yn in 
            [yY] ) 
                echo -e $'[\e[36m*\e[0m] Removing the wallet' && sleep 1
                echo -e ''
                ${DAEMON_NAME} keys delete ${WALLET}
                echo -e ''
                break
                ;;
            [nN] ) 
                echo -e $'[\e[36m*\e[0m] The connect wallet operation has been halted' && sleep 1
                exit -1
                ;;
            esac
        done
    fi
    
    echo -e $'[\e[36m*\e[0m] Saving the wallet name into environment variables' && sleep 1
    sed -i '/export WALLET=/d' $HOME/.bash_profile > /dev/null 2>&1
    echo "export WALLET=${WALLET}" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    echo "    export WALLET=${WALLET}"
    
    while true; do
    read -e -p $'[\e[33m?\e[0m] Are you going to recover the wallet (Y) or create a new one (N)? (y/n) ' yn
    case $yn in 
        [yY] ) 
            echo -e $'[\e[36m*\e[0m] Recovering the wallet' && sleep 1
            echo -e ''
            ${DAEMON_NAME} keys add ${WALLET} --recover
            break
            ;;
        [nN] ) 
            echo -e $'[\e[36m*\e[0m] Creating a new wallet' && sleep 1
            echo -e ''
            ${DAEMON_NAME} keys add ${WALLET}
            
            echo -e '    '
            echo -e '    \e[31m'
            echo -e '    ███████  █████  ██    ██ ███████     ███    ███ ███    ██ ███████ ███    ███  ██████  ███    ██ ██  ██████ ██'
            echo -e '    ██      ██   ██ ██    ██ ██          ████  ████ ████   ██ ██      ████  ████ ██    ██ ████   ██ ██ ██      ██'
            echo -e '    ███████ ███████ ██    ██ █████       ██ ████ ██ ██ ██  ██ █████   ██ ████ ██ ██    ██ ██ ██  ██ ██ ██      ██'
            echo -e '         ██ ██   ██  ██  ██  ██          ██  ██  ██ ██  ██ ██ ██      ██  ██  ██ ██    ██ ██  ██ ██ ██ ██        '
            echo -e '    ███████ ██   ██   ████   ███████     ██      ██ ██   ████ ███████ ██      ██  ██████  ██   ████ ██  ██████ ██'
            echo -e '    \e[0m'
            echo -e '    '
    
            break
            ;;
        esac
    done
    
    if ls -al ${DAEMON_HOME} | grep -F "${WALLET}" > /dev/null 2>&1; then
        echo -e $'[\e[32m*\e[0m] The wallet has been successfully connected' && sleep 1
    else
        echo -e $'[\e[36m*\e[0m] An error occurred during the operation' && sleep 1
        exit -1
    fi

    echo -e $'[\e[36m*\e[0m] Please enter the keyring passphrase to save the wallet address into environment variables' && sleep 1
    WALLET_ADDRESS=$(${DAEMON_NAME} keys show $WALLET -a)
    echo -e $'[\e[36m*\e[0m] Please enter the keyring passphrase one more time to save the validator address into environment variables' && sleep 1
    VALOPER_ADDRESS=$(${DAEMON_NAME} keys show $WALLET --bech val -a)
    
    echo -e $'[\e[36m*\e[0m] Saving the wallet and validator addresses into environment variables' && sleep 1
    sed -i '/export WALLET_ADDRESS=/d' $HOME/.bash_profile > /dev/null 2>&1
    sed -i '/export VALOPER_ADDRESS=/d' $HOME/.bash_profile > /dev/null 2>&1
    echo 'export WALLET_ADDRESS='${WALLET_ADDRESS} >> $HOME/.bash_profile
    echo 'export VALOPER_ADDRESS='${VALOPER_ADDRESS} >> $HOME/.bash_profile
    source $HOME/.bash_profile
    echo "    export WALLET_ADDRESS=${WALLET_ADDRESS}"
    echo "    export VALOPER_ADDRESS=${VALOPER_ADDRESS}"
    
    echo -e $'[\e[32m*\e[0m] Connect wallet operation has been finished' && sleep 1

}


#####################################################################################################################################################################
#                                                                           HEALTHCHECK                                                                             #
#####################################################################################################################################################################


function functionHealthcheck {

    source $HOME/.bash_profile > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Validating environment' && sleep 1
    if [ ! $DAEMON_NAME ] || [ ! $DENOM ] || [ ! $VALOPER_ADDRESS ] || [ ! $PORT ]; then
        echo -e $'[\e[31m!\e[0m] Environment is not set correctly'
        echo -e $'    Ensure you have set the following environment variables or launch installation'
        echo '    export DAEMON_NAME=<daemon name> >> $HOME/.bash_profile'
        echo '    export DENOM=<blockchain currency (denom)> >> $HOME/.bash_profile'
        echo '    export VALOPER_ADDRESS=<validator address> >> $HOME/.bash_profile'
        echo '    export PORT=<default node port> >> $HOME/.bash_profile'
        exit -1
    fi
    
    echo -e $'[\e[36m*\e[0m] Installing server monitoring' && sleep 1
    wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz > /dev/null 2>&1
    tar xvfz node_exporter-*.*-amd64.tar.gz > /dev/null 2>&1
    sudo mv node_exporter-*.*-amd64/node_exporter /usr/local/bin/ > /dev/null 2>&1
    rm node_exporter-* -rf > /dev/null 2>&1
    sudo useradd -rs /bin/false node_exporter > /dev/null 2>&1
# do not change this code, or else EOF will not work 
sudo tee <<EOF >/dev/null /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
# end
    sudo systemctl daemon-reload > /dev/null 2>&1
    sudo systemctl enable node_exporter > /dev/null 2>&1
    sudo systemctl start node_exporter > /dev/null 2>&1

    echo -e $'[\e[36m*\e[0m] Installing cosmos node monitoring' && sleep 1
    wget https://github.com/solarlabsteam/cosmos-exporter/releases/download/v0.3.0/cosmos-exporter_0.3.0_Linux_x86_64.tar.gz > /dev/null 2>&1
    tar xvfz cosmos-exporter* > /dev/null 2>&1
    sudo cp ./cosmos-exporter /usr/local/bin > /dev/null 2>&1
    rm -rf cosmos-exporter* README.md > /dev/null 2>&1
    sudo useradd -rs /bin/false cosmos_exporter > /dev/null 2>&1
    
    VALOPER_PREFIX=${VALOPER_ADDRESS%valoper*}
    DENOM_COIFFICIENT=1000000
    
    PORT_NODE=9090
    if [ $PORT -ne 26 ] ; then
        PORT_NODE="${PORT}090"
    fi

sudo tee <<EOF >/dev/null /etc/systemd/system/cosmos-exporter-${DAEMON_NAME}.service
[Unit]
Description=Cosmos Exporter
After=network-online.target

[Service]
User=cosmos_exporter
Group=cosmos_exporter
TimeoutStartSec=0
CPUWeight=95
IOWeight=95
ExecStart=cosmos-exporter --denom ${DENOM} --denom-coefficient 1000000 --bech-prefix ${VALOPER_PREFIX} --listen-address 0.0.0.0:${PORT}300 --node localhost:${PORT_NODE} --tendermint-rpc http://localhost:${PORT}657
Restart=always
RestartSec=2
LimitNOFILE=800000
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload > /dev/null 2>&1
    sudo systemctl enable cosmos-exporter-${DAEMON_NAME} > /dev/null 2>&1
    sudo systemctl restart cosmos-exporter-${DAEMON_NAME} > /dev/null 2>&1
    
    echo -e $'[\e[32m*\e[0m] Healthcheck operation has been finished' && sleep 1

}


#####################################################################################################################################################################
#                                                                               DELETE                                                                              #
#####################################################################################################################################################################


function functionDelete {

    source $HOME/.bash_profile > /dev/null 2>&1

    echo -e $'[\e[36m*\e[0m] Validating environment' && sleep 1
    if [ ! $DAEMON_HOME ] || [ ! $DAEMON_NAME ] || [ ! $GITHUB_FOLDER ]; then
        echo -e $'[\e[31m!\e[0m] Environment is not set correctly'
        echo -e $'    Ensure you have set the following environment variables or launch installation'
        echo '    export DAEMON_HOME=<daemon home folder path> >> $HOME/.bash_profile'
        echo '   export DAEMON_NAME=<daemon name> >> $HOME/.bash_profile'
        echo '   export GITHUB_FOLDER=<github project folder path> >> $HOME/.bash_profile'
        exit -1
    fi

    echo -e '    '
    echo -e '    \e[31m'
    echo -e '    ██████   █████  ███    ██  ██████  ███████ ██████  ██'
    echo -e '    ██   ██ ██   ██ ████   ██ ██       ██      ██   ██ ██'
    echo -e '    ██   ██ ███████ ██ ██  ██ ██   ███ █████   ██████  ██'
    echo -e '    ██   ██ ██   ██ ██  ██ ██ ██    ██ ██      ██   ██   '
    echo -e '    ██████  ██   ██ ██   ████  ██████  ███████ ██   ██ ██'
    echo -e '    \e[0m'
    echo -e '    '
    
    while true; do
    read -e -p $'[\e[33m?\e[0m] The following operation will completely delete the node from the server, do you want to proceed? (y/n) ' yn
    case $yn in 
        [yY] ) 
            break;;
        [nN] ) 
            echo -e $'[\e[36m*\e[0m] The delete operation has been halted' && sleep 1
            exit -1
            ;;
        esac
    done
    
    echo -e $'[\e[36m*\e[0m] Halting the daemon' && sleep 1
    sudo systemctl stop ${DAEMON_NAME} > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Disabling the daemon' && sleep 1
    sudo systemctl disable ${DAEMON_NAME} > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Removing the daemon service' && sleep 1
    sudo rm -rf /etc/systemd/system/${DAEMON_NAME}* > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Removing the daemon binaries' && sleep 1
    rm -rf $(which ${DAEMON_NAME}) > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Removing the daemon home folder path' && sleep 1
    rm -rf ${DAEMON_HOME} > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Removing the daemon github folder' && sleep 1
    rm -rf ${GITHUB_FOLDER} > /dev/null 2>&1
    
    echo -e $'[\e[36m*\e[0m] Cleaning the environment' && sleep 1
    rm $HOME/.bash_profile > /dev/null 2>&1
    
    echo -e $'[\e[32m*\e[0m] Delete operation has been finished' && sleep 1

}


#####################################################################################################################################################################
#                                                                               LAUNCH                                                                              #
#####################################################################################################################################################################


clear
PS3=$'[\e[33m?\e[0m] Please input your option number and press Enter: '
options=("Install" "Update" "Statesync" "Connect wallet" "Healthcheck" "Delete" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Install")
            clear
            echo -e $'[\e[36m*\e[0m] You choosed install operation. Launching...' && sleep 1
			functionPrepareEnvironment
            functionInstallGo
            functionInstallDependencies
            functionBuildBinaries
			break
            ;;
        "Update")
            clear
            echo -e $'[\e[36m*\e[0m] You choosed update operation. Launching...' && sleep 1
            functionUpdate
			break
            ;;
        "Statesync")
            clear
            echo -e $'[\e[36m*\e[0m] You choosed statesync operation. Launching...' && sleep 1
            functionStatesync
			break
            ;;
        "Connect wallet")
            clear
            echo -e $'[\e[36m*\e[0m] You choosed connect wallet operation. Launching...' && sleep 1
            functionWallet
			break
            ;;
        "Healthcheck")
            clear
            echo -e $'[\e[36m*\e[0m] You choosed healthcheck operation. Launching...' && sleep 1
            functionHealthcheck
			break
            ;;
		"Delete")
            clear
            echo -e $'[\e[36m*\e[0m] You choosed delete operation. Launching...' && sleep 1
			functionDelete
			break
            ;;
        "Quit")
            clear
            break
            ;;
        *) echo -e "\e[91minvalid option $REPLY\e[0m";;
    esac
done