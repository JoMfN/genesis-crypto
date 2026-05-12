# Setup

## dependencies.sh

This script installs all the dependencies (and system configurations) that are necessary for the binary to run. Since this file already gets called from within the other scripts, it is not required to call this yourself.

## upgrade.sh

> [!WARNING]
> This script is release-dependent. See [README.md](/README.md) to see which version you have to use.
>

This version of the script takes care of the following to upgrade your node:

- It stops the node (the service)
- Installs or upgrades all the necessary dependencies
- Creates a backup of existing _config.toml_ or _app.toml_ files (as _.toml.bak_)
- Calls [migrate-configs.sh](/setup/migrate-configs.sh) to migrate your app.toml and config.toml files
- Builds the binaries

### Usage

```
sh setup/upgrade.sh
```
> After a successful upgrade, start the node again using `systemctl start genesisd` and monitor its status with `journalctl -fu genesisd -ocat`.


### migrate-configs.sh

> [!WARNING]
> This script gets called automatically if you use the upgrade.sh script and is also release-dependent.
>

This version of the script takes care of the following:
- Applies the config changes as detailed in https://github.com/crypto-org-chain/cronos/releases/tag/v1.1.0 (v1.0.0 => v1.1.1 for genesis).

### Usage

```
sh setup/migrate-configs.sh <config_toml_path> <app_toml_path>
```

## quick-sync.sh

> [!CAUTION]
> Running this will **wipe the entire database** (the _/data_-folder **excluding** the priv_validator_state.json file).
>
> Make a backup if needed: [utils/backup/create.sh](/utils/backup/create.sh).

As the name suggests, this script should be used to quick-sync a node:

- It stops the service (if it exists)
- Installs all the necessary dependencies
- Builds the binaries
- Resets config files
- Fetches state, seeds and peers
- Initializes the node

### Usage

```
sh setup/quick-sync.sh <moniker>
```
> If you can't access the `genesisd` command afterwards, execute the `. ~/.bashrc` _or_ `source ~/.bashrc` command in your terminal.
>
> **IMPORTANT:** currently, snapshots must be bootstrapped manually. Please refer to the main [README](/README.md) for further instructions.

## state-sync.sh

> [!CAUTION]
> Running this will **wipe the entire database** (the _/data_-folder **excluding** the priv_validator_state.json file).
> 
> Make a backup if needed: [utils/backup/create.sh](/utils/backup/create.sh).

This script takes care of the needed steps to join the network via State Sync:

- It stops the service (if it exists)
- Installs all the necessary dependencies
- Builds the binaries
- Initializes the node
- Resets config files
- Fetches latest seeds and peers
- Fetches `genesis.json`-file
- Fetches RPC servers
- Recalibrates **[statesync]** settings to a recent height (**default:** `<latest_height>` - `2000`)

### Usage

```
sh setup/state-sync.sh <moniker>
```
> If you wish to change the default _[height_interval]_ of `2000`, run [utils/tools/restate-sync.sh](/utils/tools/restate-sync.sh) _[height_interval]_ yourself _after_ having run _setup/state-sync.sh_; see [utils/README.md](/utils) for more information.
>
> If you can't access the `genesisd` command afterwards, execute the `. ~/.bashrc` _or_ `source ~/.bashrc` command in your terminal.

## create-validator.sh

> [!IMPORTANT]
> _create-validator.sh_ requires a key.
>
> If you haven't already created or imported one, use: [utils/key/create.sh](/utils/key/create.sh) _or_ [utils/key/import.sh](/utils/key/import.sh).

This script should only be run once you're **fully synced**. It's a wizard; prompting the user only the required fields for creating a validator.

### Usage

```
sh setup/create-validator.sh <moniker> <key_alias>
```
