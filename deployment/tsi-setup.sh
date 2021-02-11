#!/bin/bash

# install the Time Series Insights extension
echo -e "Checking timeseriesinsights extension."
az extension show -n timeseriesinsights -o none &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "timeseriesinsights extension not found. Installing timeseriesinsights."
    az extension add --name timeseriesinsights &> /dev/null
    echo -e "timeseriesinsights extension is now installed."
else
    az extension update --name timeseriesinsights &> /dev/null
    echo -e "timeseriesinsights extension is up to date."
fi

resourceGroup=$1
tsiName=$2
webAppName=$3
webAppUrl="${4:-https://${webAppName}.azurewebsites.net/}"

subscriptionId=$(az account show --query id -o tsv)
servicePrincipalAppName='WedxServerIotEdgeManagementTsi'

servicePrincipalAppId=$(az ad app list --all --query '[].{AppId:appId}' --display-name $servicePrincipalAppName -o tsv)
if [ -z $servicePrincipalAppId ]; then
    servicePrincipalAppId=$(az ad app create --display-name ${servicePrincipalAppName} --identifier-uris "https://${servicePrincipalAppName}" --oauth2-allow-implicit-flow true --required-resource-accesses '[{"resourceAppId":"120d688d-1518-4cf7-bd38-182f158850b6","resourceAccess":[{"id":"a3a77dfe-67a4-4373-b02a-dfe8485e2248","type":"Scope"}]}]' --query appId -o tsv)
fi

servicePrincipalObjectId=$(az ad sp list --query '[].objectId' --display-name "${servicePrincipalAppName}" -o tsv)
if [ -z $servicePrincipalObjectId ]; then
    servicePrincipalObjectId=$(az ad sp create --id ${servicePrincipalAppId} --query objectId -o tsv)
fi

servicePrincipalSecret=$(az ad app credential reset --append --id ${servicePrincipalAppId} --credential-description "TsiSecret" --query password --only-show-errors -o tsv)
servicePrincipalTenantId=$(az ad sp show --id ${servicePrincipalAppId} --query appOwnerTenantId -o tsv)

az ad app update --id ${servicePrincipalAppId} --reply-urls ${webAppUrl}

tsiTenantId=$(az webapp config appsettings set --name ${webAppName} --resource-group ${resourceGroup} --settings WedxAppConfig__Tsi__TenantId=${servicePrincipalTenantId} --query "[?name=='WedxAppConfig__Tsi__TenantId'].[value]" -o tsv)

tsiClientId=$(az webapp config appsettings set --name ${webAppName} --resource-group ${resourceGroup} --settings WedxAppConfig__Tsi__ClientId=${servicePrincipalAppId} --query "[?name=='WedxAppConfig__Tsi__ClientId'].[value]" -o tsv)

tsiClientSecret=$(az webapp config appsettings set --name ${webAppName} --resource-group ${resourceGroup} --settings WedxAppConfig__Tsi__ClientSecret=${servicePrincipalSecret} --query "[?name=='WedxAppConfig__Tsi__ClientSecret'].[value]" -o tsv)

accessPolicyServicePrincipalObjectId=$(az tsi access-policy list -g ${resourceGroup} --environment-name ${tsiName} --query "value[].{Id:principalObjectId}[?contains(Id,'${servicePrincipalObjectId}')].Id" -o tsv --only-show-errors)
if [ -z $accessPolicyServicePrincipalObjectId ]; then
    accessPolicyResponse=$(az tsi access-policy create -g ${resourceGroup} --environment-name ${tsiName} -n ${servicePrincipalAppName} --principal-object-id ${servicePrincipalObjectId} --roles Reader Contributor --only-show-errors)
fi

echo "Complete configuration"
