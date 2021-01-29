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

# script configuration 
RESOURCE_GROUP=$1
AMS_ACCOUNT=$2
WEB_APP_NAME=$3
SPN="WedxServerIotEdgeManagementAms"
ROLE_DEFINITION_NAME="WeDX LVAEdge User"

# check if we need to log in
# if we are executing in the Azure Cloud Shell, we should already be logged in
az account show -o none
if [ $? -ne 0 ]; then
    echo -e "Running 'az login' for you."
    az login -o none
fi

# query subscriptions
echo -e "\nYou have access to the following subscriptions:"
az account list --query '[].{name:name,"subscription Id":id}' --output table
echo -e "\nYour current subscription is:"
az account show --query '[name,id]'
echo -e "You will need to use a subscription with permissions for creating service principals (owner role provides this).
If you want to change to a different subscription, enter the name or id.
Or just press enter to continue with the current subscription."
read -p ">> " SUBSCRIPTION_ID
if ! test -z "$SUBSCRIPTION_ID"
then 
    az account set -s "$SUBSCRIPTION_ID"
    echo -e "Now using:"
    az account show --query '[name,id]'
fi

# creating the AMS account creates a service principal, so we'll just reset it to get the credentials
echo -e "setting up service principal..."
if test -z "$(az ad sp list --display-name $SPN --query="[].displayName" -o tsv)"; then
    AMS_CONNECTION=$(az ams account sp create -o yaml --resource-group $RESOURCE_GROUP --account-name $AMS_ACCOUNT --name $SPN)
else
    AMS_CONNECTION=$(az ams account sp reset-credentials -o yaml --resource-group $RESOURCE_GROUP --account-name $AMS_ACCOUNT --name $SPN)
fi

# capture config information
re="AadTenantId:\s([0-9a-z\-]*)"
AAD_TENANT_ID=$([[ "$AMS_CONNECTION" =~ $re ]] && echo ${BASH_REMATCH[1]})
re="AadClientId:\s([0-9a-z\-]*)"
AAD_SERVICE_PRINCIPAL_ID=$([[ "$AMS_CONNECTION" =~ $re ]] && echo ${BASH_REMATCH[1]})
re="AadSecret:\s([0-9a-z\-]*)"
AAD_SERVICE_PRINCIPAL_SECRET=$([[ "$AMS_CONNECTION" =~ $re ]] && echo ${BASH_REMATCH[1]})
re="SubscriptionId:\s([0-9a-z\-]*)"
SUBSCRIPTION_ID=$([[ "$AMS_CONNECTION" =~ $re ]] && echo ${BASH_REMATCH[1]})

# create new custom role definition in the subscription
if test -z "$(az role definition list -n "$ROLE_DEFINITION_NAME" | grep "roleName")"; then
    echo -e "Creating a custom role named $ROLE_DEFINITION_NAME."
    curl -sL $ROLE_DEFINITION_URL > $ROLE_DEFINITION_FILE
    az role definition create -o none --role-definition "{
        \"Name\": \"${ROLE_DEFINITION_NAME}\",
        \"IsCustom\": true,
        \"Description\": \"Can create assets, view list of containers and view Edge policies\",
        \"Actions\": [
            \"Microsoft.Media/mediaservices/assets/listContainerSas/action\",
            \"Microsoft.Media/mediaservices/assets/write\",
            \"Microsoft.Media/mediaservices/listEdgePolicies/action\"
        ],
        \"NotActions\": [],
        \"DataActions\": [],
        \"NotDataActions\": [],
        \"AssignableScopes\": [
            \"/subscriptions/${SUBSCRIPTION_ID}\"
        ]
    }"
fi

# capture object_id
OBJECT_ID=$(az ad sp show --id ${AAD_SERVICE_PRINCIPAL_ID} --query 'objectId' | tr -d \")

# create role assignment
az role assignment create --role "$ROLE_DEFINITION_NAME" --assignee-object-id $OBJECT_ID -o none
echo -e "The service principal with object id ${OBJECT_ID} is now linked with custom role ${ROLE_DEFINITION_NAME}."

# write env file for edge deployment
echo -e "SUBSCRIPTION_ID=\"$SUBSCRIPTION_ID\""
echo -e "RESOURCE_GROUP=\"$RESOURCE_GROUP\""
echo -e "AMS_ACCOUNT=\"$AMS_ACCOUNT\""
echo -e "AAD_TENANT_ID=$AAD_TENANT_ID"
echo -e "AAD_SERVICE_PRINCIPAL_ID=$AAD_SERVICE_PRINCIPAL_ID"
echo -e "AAD_SERVICE_PRINCIPAL_SECRET=$AAD_SERVICE_PRINCIPAL_SECRET"

# update WeDX Server web app
CMDRUN=$(az webapp config appsettings set --name ${WEB_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WedxAppConfig__MediaServices__SubscriptionId=${SUBSCRIPTION_ID} --query "[?name=='WedxAppConfig__MediaServices__SubscriptionId'].[value]" -o tsv)
CMDRUN=$(az webapp config appsettings set --name ${WEB_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WedxAppConfig__MediaServices__ResourceGroup=${RESOURCE_GROUP} --query "[?name=='WedxAppConfig__MediaServices__ResourceGroup'].[value]" -o tsv)
CMDRUN=$(az webapp config appsettings set --name ${WEB_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WedxAppConfig__MediaServices__AccountName=${AMS_ACCOUNT} --query "[?name=='WedxAppConfig__MediaServices__AccountName'].[value]" -o tsv)
CMDRUN=$(az webapp config appsettings set --name ${WEB_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WedxAppConfig__MediaServices__TenantId=${AAD_TENANT_ID} --query "[?name=='WedxAppConfig__MediaServices__TenantId'].[value]" -o tsv)
CMDRUN=$(az webapp config appsettings set --name ${WEB_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WedxAppConfig__MediaServices__ServicePrincipalId=${AAD_SERVICE_PRINCIPAL_ID} --query "[?name=='WedxAppConfig__MediaServices__ServicePrincipalId'].[value]" -o tsv)
CMDRUN=$(az webapp config appsettings set --name ${WEB_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WedxAppConfig__MediaServices__ServicePrincipalSecret=${AAD_SERVICE_PRINCIPAL_SECRET} --query "[?name=='WedxAppConfig__MediaServices__ServicePrincipalSecret'].[value]" -o tsv)

echo -e "Complete configuration"
