# Setup Azure Indoor Maps for WeDX Server

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
wget https://raw.githubusercontent.com/motojin/wedx-server/main/deployment/indoormaps-setup.sh && chmod +x ./indoormaps-setup.sh
./indoormaps-setup.sh 'RESOURCE-GROUP-NAME' 'WEB-APP-NAME' 'FUNCTION-APP-NAME' 'MAPS-PRIMARY-KEY'
rm ./indoormaps-setup.sh
```

![tsi-setup-parameters.png](https://raw.githubusercontent.com/motojin/wedx-server/main/images/tsi-setup-parameters.png)

## Exit session

```bash
exit
```
