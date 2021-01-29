#!/bin/bash

# install the Azure IoT extension
echo -e "Checking azure-iot extension."
az extension show -n azure-iot -o none &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "azure-iot extension not found. Installing azure-iot."
    az extension add --name azure-iot &> /dev/null
    echo -e "azure-iot extension is now installed."
else
    az extension update --name azure-iot &> /dev/null
    echo -e "azure-iot extension is up to date."														  
fi

resourceGroup=$1
webAppName=$2
subdomain=$3
tokenId="${4:-WeDXServer}"

applicationId=$(az iot central app list --query "[].{applicationId:applicationId, subdomain:subdomain}[?contains(subdomain,'${subdomain}')].applicationId" -o tsv)
if [ -z $applicationId ]; then
  echo "Error - Azure IoT Central Application ID does not exist : ${subdomain}"
  exit 1
fi

searchTokenId=$(az iot central api-token list --app-id ${applicationId} --query "value[].{id:id}[?contains(id,'${tokenId}')].id" -o tsv)
if [ ! -z $searchTokenId ]; then
  searchTokenId=$(az iot central api-token delete --app-id ${applicationId} --tkid ${tokenId})
  sleep 1
  echo "The existing ID has been deleted."
fi

applicationJsonToken=$(az iot central api-token create --app-id ${applicationId} --role builder --tkid ${tokenId})
if [[ -z $applicationJsonToken ]]; then
  echo "Error - Creating Application Token is failed : ${tokenId}"
  exit 1
fi

applicationToken=$(echo $applicationJsonToken | jq -r '.token' 2> /dev/null)

centralSubdomain=$(az webapp config appsettings set --name ${webAppName} --resource-group ${resourceGroup} --settings WedxAppConfig__IotCentral__Subdomain=${subdomain} --query "[?name=='WedxAppConfig__IotCentral__Subdomain'].[value]" -o tsv)

centralAppToken=$(az webapp config appsettings set --name ${webAppName} --resource-group ${resourceGroup} --settings WedxAppConfig__IotCentral__ApiToken="${applicationToken}" --query "[?name=='WedxAppConfig__IotCentral__ApiToken'].[value]" -o tsv)

echo "Complete configuration"
