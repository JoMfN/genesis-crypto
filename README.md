<h1 align="center">
  GenesisL1 Mainnet (Cronos fork)
</h1>

<p align="center">
  <ins>Release <b>v1.0.0</b> ~ Cronos <b>v1.0.15</b></ins>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/alpha-omega-labs/genesis-parameters/main/assets/l1-logo.png" alt="GenesisL1" width="150" height="150"/>
</p>

<p align="center">
  Chain ID <b>genesis_29-2</b>
</p>

<p align="center">
   A source code fork of <b>Cronos</b> and <b>Ethermint</b>
</p>

<p align="center">
  Cosmos SDK <b>v0.46.15</b>
</p>

---

> [!IMPORTANT]
> **For full-node syncing**
> 
> We were an Evmos-fork before we made the decision to hard fork to Cronos. Therefore if you do not want to **state sync**, but wish to sync a **full node**, follow the instructions in the [`genesis-ethermint`](https://github.com/alpha-omega-labs/genesis-ethermint) repository first before continuing.

> [!UPDATED]
> # Become a Genesis Validator — The *REALLY EASY* Way
> A bootstrapped updated full node to cronos-fork **mainnet**: `genesis_29-2` is available to overcome the long fast-sync times with the PDB mint going on. 

**Skip syncing from scratch. Jumpstart your Genesis node with a full backup and join the network in minutes.**
This method allows you to download a bootstrapped data folder of the chain to get up to sync in less then an hour. (~ 260GB compressed tar.lz4 folder 

## Prerequisites
- `lz4`, `tar`, `unzip` installed
- Git, Go, and build dependencies installed (see [Genesis Crypto GitHub](https://github.com/alpha-omega-labs/genesis-crypto))

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install curl tar wget build-essential git make gcc git liblz4-tool htop unzip -y
```

## Node requirements

- 1000GB+ good hard drive disk (Nvme M2 SSD recommended)
- 8GB+ RAM (16GB recommended)
- 4 CPU Threads
- Good Internet Connection ( > 1Gbit/s cable connection recommended)

> [!TIP]
> Create a linux swap are to make your node more robust against high network loads. (High RAM requirements)

if you have 8GB RAM available you can create a swap area of 8GB, if you have 16GB change the template below for 16GB

**Create swap area (~RAM size)**

```
sudo swapoff -a
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**Permanently add swap area**
To keep the swap area after a reboot, you can make it permanently by doing

```
sudo cp /etc/fstab /etc/fstab.bak
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Instructions

The instructions provided here is suitable for those who would like to join the **mainnet**: `genesis_29-2` by **setting up a new node** from the bootstrapped version provided by validator *LCserve*.

> [!NOTE]
> More details for every script mentioned in this README can be found in the folders where they are respectively stored: [/setup](/setup) or [/utils](/utils).

### 1. For time-efficiency start the download of the bootstrap folder 
This is about a ~260GB packed archive of a 303GB data folder. Open a separate terminal for this download (will take some time) 

```bash
cd ~
wget https://ftp.basementnodes.ca/genesis_backup_20250407082420.tar.lz4
lz4 -d genesis_backup_20250407082420.tar.lz4 | tar -xvf -
```

### 2. Cloning the repository & checkout to branch `v1.0.0` for mainnet: `genesis_29-2`

Open a new terminal

```bash
git clone https://github.com/alpha-omega-labs/genesis-crypto.git
cd genesis-crypto
git checkout v1.0.0
```

### 3. Node setup

Depending on your circumstances, you'll either have to **Setup a node _(using state sync)_** (recommended) or start a node from scratch by starting with the evmos-fork version of genesis-ethermint (not recommended) 

#### 3.1 Setup a node _(using state sync)_ and a bootstrap data 
The folder that is normally still downloading 

This helper script takes care of the needed steps to join the network via _state sync_.

> [!WARNING]
> Running this will **wipe the entire database** (the _/data_-folder **excluding** the priv_validator_state.json file). Therefore if you already have a node set up and you prefer not to have your GenesisL1 database lost, create a backup.
>
> You could use [utils/backup/create.sh](/utils/backup/create.sh) for this.

```bash
sh setup/state-sync.sh <moniker>
```

this should install dependencies (e.g. go), install the client `genesisd` with a single script. 

<details>
<summary>
  **Upgrade a node** 
  Do this ONLY if you are doing a node sync from scratch, can be ignored for the bootstrapped method
</summary>

This script assumes that you are currently operating on the Evmos fork of GenesisL1 (repo: [`genesis-ethermint`](https://github.com/alpha-omega-labs/genesis-ethermint)) and the node synced till height: `7400000` which caused it to panic.

> [!IMPORTANT]
> This should only be used if you run a **full-node** and have to perform the **"plan_crypto"**-upgrade.

```
sh setup/upgrade.sh
```

</details>

### 4. Daemon check

If you can't access the `genesisd` command at this point, then you may need to execute:

```
. ~/.bashrc
```
> Or the equivalent: `source ~/.bashrc`

Try if now if you can initiate the node

```bash
genesisd start --log_level warn
```

> Confirm everything initializes correctly, then stop it (Ctrl + C).

<details>
<summary>
  If you get errors related to GO 
</summary>

You might need to restart your device for some packages to work (REMEMBER TO FINISH YOUR DOWNLOAD)

please check the manual installation

> For Desktop/Server Architecture (AMD) 

```bash
ver="1.21.6"
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version
```

> For Raspberry Pi (5) Architecture (ARM) 

```bash
wget https://go.dev/dl/go1.22.1.linux-arm64.tar.gz 
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go1.22.1.linux-arm64.tar.gz"
rm "go1.22.1.linux-arm64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version
```


</details>

### 5. Create or import a key (optional for just a node, required for validator node)

A key is necessary to interact with the network/node. If you haven't already created one, either import one or generate a new one, using:

replace `<walletname>` with an arbitrary name for your wallet key

```bash
sh utils/key/create.sh <walletname>
```

OR

```bash
sh utils/key/create.sh <walletname> <private_eth_key>
```

> _<private_eth_key>_ is the private key for a (wallet) address you already own.

> [!TIP]
> Remove sensitive tokens from `bash_history` with:

```
history -c && exec bash
```

> [!Note]
> Transfer some L1 to the wallet you just created

to check your keys and adresses
```bash
genesisd keys list
```

to check your wallets ballance

```bash
genesisd query bank balances $(genesisd keys show <walletname> -a)
```


<details>
<summary>
**Pro method**
doing it via the daemon directly
</summary>

Creating a new wallet (write down you seed phrase with pen and paper!)

```bash
genesisd keys add <walletname>
```

OR

Recover a wallet

```bash
genesisd keys add <walletname> --recover
```
the terminal will request you to input the 24-words long seed phrase

</details>

### 6. Node initiation and syncing from the bootstrapped data folder

#### 6.1 Initiate node
Important for this method to work is that you can generate a `~/.genesis` folder, verify this by 

```
genesisd --help
```  

this should provide you with a help page now

If this is the case, very good you're almost there 

#### 6.2 Load the Fast-Sync Data and Copy in the `.genesis` folder

> [!WARNING]
> Make sure that you don't have genesisd running for this step
> Wait for the Download to complete (see step 1) and extract the full 303GB backup:

```
genesisd status 
```

should return a help page and no statistics of your node

> [!NOTE]
> Confirm every teminal with genesisd is close, if not then stop it (Ctrl + C).


Move it into your `~/.genesis` directory:

```bash
mv genesis_backup_20250407082420/* ~/.genesis/
```

**Make sure to overwrite if prompted** — this excludes previous `priv_validator_state.json`, node keys, etc. because it is only the data folder.

#### 6.3 Fire It Up!

```bash
genesisd start --log_level warn
```

**Watch the magic happen — your node will be nearly synced instantly.**

Wait until `genesisd status` command show output ```...,"catching_up":false},"ValidatorInfo":...``` you are now in sync


<details>
<summary>
**If genesisd is successfully installed as a service**
If you have genesisd configured as a service
</summary>

If everything went well, you should now be able to run your node using:

```
systemctl start genesisd
```

and see its status with:

```
journalctl -fu genesisd -ocat
```

> [!Manually configure genesisd as a service]
> Open a new terminal to configure the service

```
sudo nano /etc/systemd/system/genesisd.service
```

paste the following parameters

```
[Unit]
Description=genesisd
After=network-online.target

[Service]
User=$USER
ExecStart=$(which genesisd) start
Restart=on-failure
RestartSec=15
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

</details>

### 7. Become a validator (optional, also very welcoming)

Once your node is _up-and-running_, _fully synced_ and you have a _key_ created or imported, you could become a validator using:

```
sh setup/create-validator.sh <moniker> <walletname>
```

> This is a wizard and shall prompt the user only the required fields to create an on-chain validator.

> [!Warning]
> make sure you are in sync and `genesisd` is running

```
genesisd status
```

should show `"catching_up":false`

```plaintext
...,"catching_up":false},"ValidatorInfo":...
```


<details>
<summary>
**Pro method**
Use the template by expanding this window via `genesisd`
</summary>

Adjust gas-prices and gas if the transaction gives the error out-of-gas

```bash
genesisd tx staking create-validator \
  --amount=1000000el1 \
  --pubkey=$(genesisd tendermint show-validator) \
  --moniker="YOUR_NODE_NAME" \
  --identity="More_Info_You_Want_To_Add" \
  --website="" \
  --details="Example: Community Valoper node and Supporter of GenesisL1" \
  --security-contact="YourEmail@mail.com" \
  --chain-id="genesis_29-2" \
  --commission-rate="0.05" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --gas=355172 \
  --gas-prices=1127530424125el1 \
  --from=<walletname> \
```

</details>

### 8. Explore utilities (optional)

> [!TIP]
> The [/utils](/utils)-folder contains useful utilities one could use to manage their node (e.g. for fetching latest seeds and peers, fetching the genesis state, quickly shifting your config's ports, recalibrating your state sync etc.). To learn more about these, see the [README](utils/README.md) in the folder.

### 9. FAQ and usefull links

To finalise

> [!LINKS]
> [`starv-team node installation guide`](https://stavr-team.gitbook.io/nodes-guides/mainnets/genesisl1/node-installation)
> [`Checking status of your validator node at ping.pub`](https://ping.pub/genesisL1/uptime)
> [`Anode team node installation guide`](https://anode.team/GenesisL1)

