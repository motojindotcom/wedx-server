# Setup Time Series Insights for WeDX Server

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
wget https://raw.githubusercontent.com/motojin/wedx-server/main/deployment/tsi-setup.sh && chmod +x ./tsi-setup.sh
./tsi-setup.sh 'RESOURCE-GROUP-NAME' 'TSI-NAME' 'WEB-APP-NAME'
rm ./tsi-setup.sh
```

![tsi-setup-parameters.png](https://raw.githubusercontent.com/motojin/wedx-server/main/images/tsi-setup-parameters.png)

## Exit session

```bash
exit
```
