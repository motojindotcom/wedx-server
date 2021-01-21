# Setup IoT Central for WeDX Server

## Start Cloud Shell

Select the Cloud Shell icon on the [Azure portal](https://portal.azure.com/)

![portal-launch-icon.png](https://raw.githubusercontent.com/motojin/wedx-server/main/images/portal-launch-icon.png)

## Select the Bash environment

Select Bash

![select-shell-drop-down.png](https://raw.githubusercontent.com/motojin/wedx-server/main/images/select-shell-drop-down.png)

## Sign in interactively

```bash
az login --tenant 'MY-TENANT-NAME'
```

## Set your subscription

```bash
az account list --output table
az account set --subscription 'MY-SUBSCRIPTIN-NAME'
```

## Execute Post-script

```bash
wget https://raw.githubusercontent.com/motojin/wedx-server/main/deployment/central-setup.sh && chmod +x ./central-setup.sh
./central-setup.sh 'RESOURCE-GROUP-NAME' 'WEB-APP-NAME' 'IOT-CENTRAL-SUBDOMAIN'
rm ./central-setup.sh
```

![central-setup-parameters-1.png](https://raw.githubusercontent.com/motojin/wedx-server/main/images/central-setup-parameters-1.png)

![central-setup-parameters-2.png](https://raw.githubusercontent.com/motojin/wedx-server/main/images/central-setup-parameters-2.png)

- Since some CLI commands are still PREVIEW, the following WARNING message is output.

    ```bash
    WARNING: Command group 'iot central api-token' is in preview and under development. Reference and support levels: https://aka.ms/CLI_refstatus
    ```

## Exit session

```bash
exit
```
