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
ADT_NAME=$2
ADL_SPACE_FLOOR_NAME="Space-Floor-v1.json"
ADL_SPACE_FLOOR_MODEL="dtmi:com:motojin:Space:Floor;1"
ADL_SPACE_AREA_NAME="Space-Area-v1.json"
ADL_SPACE_AREA_MODEL="dtmi:com:motojin:Space:Area;1"
ADL_SENSOR_THERMOSTAT_NAME="Sensor-Thermostat-v1.json"
ADL_SENSOR_THERMOSTAT_MODEL="dtmi:com:motojin:Sensor:Thermostat;1"

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

# download digital twins models
echo -e "download digital twins model floor file."
wget https://raw.githubusercontent.com/motojin/wedx-server/main/dtdl-v2-pnp/${ADL_SPACE_FLOOR_NAME}
if [ ! -f "$ADL_SPACE_FLOOR_NAME" ]; then
    echo -e "Error - Digital Twins Model ${ADL_SPACE_FLOOR_NAME} file not exists."
    exit 1
fi
echo -e "download digital twins model area file."
wget https://raw.githubusercontent.com/motojin/wedx-server/main/dtdl-v2-pnp/${ADL_SPACE_AREA_NAME}
if [ ! -f "$ADL_SPACE_AREA_NAME" ]; then
    echo -e "Error - Digital Twins Model ${ADL_SPACE_AREA_NAME} file not exists."
    exit 1
fi
echo -e "download digital twins model thermostat file."
wget https://raw.githubusercontent.com/motojin/wedx-server/main/dtdl-v2-pnp/${ADL_SENSOR_THERMOSTAT_NAME}
if [ ! -f "$ADL_SENSOR_THERMOSTAT_NAME" ]; then
    echo -e "Error - Digital Twins Model ${ADL_SENSOR_THERMOSTAT_NAME} file not exists."
    exit 1
fi

# create ditital twins models
echo -e "create digital twins floor models."
if test -z "$(az dt model list --resource-group $RESOURCE_GROUP --dt-name $ADT_NAME --query="[?id=='${ADL_SPACE_FLOOR_MODEL}'].id" -o tsv)"; then
    az dt model create --resource-group $RESOURCE_GROUP --dt-name $ADT_NAME --models $ADL_SPACE_FLOOR_NAME -o none
else
    echo -e "skip creating floor model becouse it is existed."
fi
echo -e "create digital area floor models."
if test -z "$(az dt model list --resource-group $RESOURCE_GROUP --dt-name $ADT_NAME --query="[?id=='${ADL_SPACE_AREA_MODEL}'].id" -o tsv)"; then
    az dt model create --resource-group $RESOURCE_GROUP --dt-name $ADT_NAME --models $ADL_SPACE_AREA_NAME -o none
else
    echo -e "skip creating area model becouse it is existed."
fi
echo -e "create digital twins thermostat models."
if test -z "$(az dt model list --resource-group $RESOURCE_GROUP --dt-name $ADT_NAME --query="[?id=='${ADL_SENSOR_THERMOSTAT_MODEL}'].id" -o tsv)"; then
    az dt model create --resource-group $RESOURCE_GROUP --dt-name $ADT_NAME --models $ADL_SENSOR_THERMOSTAT_NAME -o none
else
    echo -e "skip creating thermostat model becouse it is existed."
fi

# list digital twins models
echo -e "list digital twins models"
az dt model list --resource-group $RESOURCE_GROUP --dt-name $ADT_NAME --query="[].{DTMI:id, UploadTime:uploadTime}" -o table

echo -e "Complete configuration"
