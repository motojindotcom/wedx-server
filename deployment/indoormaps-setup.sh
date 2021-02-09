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
WEB_APP_NAME=$2
FUNC_APP_NAME=$3
MAPS_PRIMARY_KEY=$4
INDOOR_MAPS_FILE="DT101_IndoorMapData.zip"

# check if we need to log in
# if we are executing in the Azure Cloud Shell, we should already be logged in
az account show -o none
if [ $? -ne 0 ]; then
    echo -e "Running 'az login' for you."
    az login -o none
fi

parse_header() {
  local -n header=$1 # Nameref argument
  # Check that argument is the name of an associative array
  case ${header@a} in
    A | At) ;;
    *)
      printf \
      'Variable %s with attributes %s is not a suitable associative array\n' \
      "${!header}" "${header@a}" >&2
      return 1
      ;;
  esac
  header=() # Clear the associative array
  local -- line rest v
  local -l k # Automatically lowercased

  # Get the first line, assuming HTTP/1.0 or above. Note that these fields
  # have Capitalized names.
  IFS=$' \t\n\r' read -r header['Proto'] header['Status'] rest
  # Drop the CR from the message, if there was one.
  header['Message']="${rest%%*([[:space:]])}"
  # Now read the rest of the headers.
  while IFS=: read -r line rest && [ -n "$line$rest" ]; do
    rest=${rest%%*([[:space:]])}
    rest=${rest##*([[:space:]])}
    line=${line%%*([[:space:]])}
    [ -z "$line" ] && break # Blank line is end of headers stream
    if [ -n "$rest" ]; then
      k=$line
      v=$rest
    else
      # Handle folded header
      # See: https://tools.ietf.org/html/rfc2822#section-2.2.3
      v+=" ${line##*([[:space:]])}"
    fi
    header["$k"]="$v"
  done
}

# download indoor maps drawing file
echo -e "download indoor maps file"
indoor_maps_file_url="https://raw.githubusercontent.com/motojin/wedx-server/main/indoor-maps/${INDOOR_MAPS_FILE}"
wget $indoor_maps_file_url
if [ ! -e $INDOOR_MAPS_FILE ]; then
  echo -e "Error - download failed"
  exit 1
fi

# upload the drawing package to the azure maps service
declare -A HTTP_HEADERS
rest_api_url="https://us.atlas.microsoft.com/mapData/upload?api-version=1.0&dataFormat=zip&subscription-key=${MAPS_PRIMARY_KEY}"
parse_header HTTP_HEADERS < <(
  curl -is -X POST -H "Content-Type: application/octet-stream" --data-binary @"$INDOOR_MAPS_FILE" "$rest_api_url"
)
rest_api_status=${HTTP_HEADERS[Status]}
if [ $rest_api_status == "202" -o $rest_api_status == "201" ]; then
  echo -e "upload the drawing package - [${HTTP_HEADERS[Status]}]"
else
  echo -e "Error -  upload the drawing package ${HTTP_HEADERS[Status]}"
  typeset -p HTTP_HEADERS
  exit 1
fi
rest_api_location=`echo ${HTTP_HEADERS[location]} | sed 's+https://atlas.microsoft.com+https://us.atlas.microsoft.com+g'`
unset HTTP_HEADERS

# check the status of the api call
rest_api_url="${rest_api_location}&subscription-key=${MAPS_PRIMARY_KEY}"
while true; do
  rest_api_response=`curl -s -X GET "$rest_api_url"`
  rest_api_status=`echo $rest_api_response | jq -r .status`
  if [[ "$rest_api_status" == "NotStarted" ]]; then
    printf "."
    sleep 1
    continue
  elif [[ "$rest_api_status" == "Running" ]]; then
    printf "."
    sleep 1
    continue
  elif [ "$rest_api_status" = "Succeeded" ]; then
    OPERATION_ID=`echo $rest_api_response | jq -r .operationId`
    RESOURCE_LOCATION=`echo $rest_api_response | jq -r .resourceLocation`
    arrayUrl=(${RESOURCE_LOCATION//\// })
    arrayUrl=(${arrayUrl[@]//[=?]/ })
    UDID=${arrayUrl[4]}
    echo -e "Success Operation=$OPERATION_ID UDID=$UDID @ $RESOURCE_LOCATION"
    break
  elif [ "$rest_api_status" = "Failed" ]; then
    echo -e "Error - failed : ${rest_api_response}"
    exit 1
  else
    echo -e "Warning - Unrecognized status $rest_api_status"
  fi
done

# retrieve content metadata
RESOURCE_LOCATION=`echo ${RESOURCE_LOCATION} | sed 's+https://atlas.microsoft.com+https://us.atlas.microsoft.com+g'`
rest_api_url=$"${RESOURCE_LOCATION}&subscription-key=${MAPS_PRIMARY_KEY}"
rest_api_response=`curl -s -X GET "$rest_api_url"`
rest_api_status=`echo $rest_api_response | jq -r .uploadStatus`
if [ "$rest_api_status" != "Completed" ]; then
  echo -e "Error retrieve content metadata $rest_api_status"
  exit 1
fi

# convert uploaded drawing package into map data
rest_api_url="https://us.atlas.microsoft.com/conversion/convert?subscription-key=${MAPS_PRIMARY_KEY}&api-version=1.0&udid=${UDID}&inputType=DWG"
declare -A HTTP_HEADERS
parse_header HTTP_HEADERS < <(
  curl -is -X POST -H "Content-Length: 0" "${rest_api_url}"
)
rest_api_status=${HTTP_HEADERS[Status]}
if [ $rest_api_status == "202" -o $rest_api_status == "201" ]; then
  echo -e "convert uploaded drawing package into map data Success [${HTTP_HEADERS[Status]}]"
else
  echo -e "Error - ${HTTP_HEADERS[Status]}"
  typeset -p HTTP_HEADERS
  exit 1
fi
rest_api_location=`echo ${HTTP_HEADERS[location]} | sed 's+https://atlas.microsoft.com+https://us.atlas.microsoft.com+g'`
unset HTTP_HEADERS

# check the status of the api call
rest_api_url="${rest_api_location}&subscription-key=${MAPS_PRIMARY_KEY}"
while true; do
  rest_api_response=`curl -s -X GET "$rest_api_url"`
  rest_api_status=`echo $rest_api_response | jq -r .status`
  if [[ "$rest_api_status" == "NotStarted" ]]; then
    printf "."
    sleep 1
    continue
  elif [[ "$rest_api_status" == "Running" ]]; then
    printf "."
    sleep 1
    continue
  elif [ "$rest_api_status" = "Succeeded" ]; then
    OPERATION_ID=`echo $rest_api_response | jq -r .operationId`
    RESOURCE_LOCATION=`echo $rest_api_response | jq -r .resourceLocation`
    arrayUrl=(${RESOURCE_LOCATION//\// })
    arrayUrl=(${arrayUrl[@]//[=?]/ })
    CONVERSION_ID=${arrayUrl[3]}
    echo -e "Success Operation=$OPERATION_ID ConversionID=$CONVERSION_ID @ $RESOURCE_LOCATION"
    break
  elif [ "$rest_api_status" = "Failed" ]; then
    echo -e "Error - failed : ${rest_api_response}"
    exit 1
  else
    echo -e "Warning - Unrecognized status $rest_api_status"
  fi
done

# create a new dataset
rest_api_url="https://us.atlas.microsoft.com/dataset/create?api-version=1.0&conversionID=${CONVERSION_ID}&type=facility&subscription-key=${MAPS_PRIMARY_KEY}"
declare -A HTTP_HEADERS
parse_header HTTP_HEADERS < <(
  curl -is -X POST -H "Content-Length: 0" "${rest_api_url}"
)
rest_api_status=${HTTP_HEADERS[Status]}
if [ $rest_api_status == "202" -o $rest_api_status == "201" ]; then
  echo -e "create a new dataset success [${HTTP_HEADERS[Status]}]"
else
  echo -e "Error - ${HTTP_HEADERS[Status]}"
  typeset -p HTTP_HEADERS
  exit 1
fi
rest_api_location=`echo ${HTTP_HEADERS[location]} | sed 's+https://atlas.microsoft.com+https://us.atlas.microsoft.com+g'`
unset HTTP_HEADERS

# check the status of the api call
rest_api_url="${rest_api_location}&subscription-key=${MAPS_PRIMARY_KEY}"
while true; do
  rest_api_response=`curl -s -X GET "$rest_api_url"`
  rest_api_status=`echo $rest_api_response | jq -r .status`
  if [[ "$rest_api_status" == "NotStarted" ]]; then
    printf "."
    sleep 1
    continue
  elif [[ "$rest_api_status" == "Running" ]]; then
    printf "."
    sleep 1
    continue
  elif [ "$rest_api_status" = "Succeeded" ]; then
    OPERATION_ID=`echo $rest_api_response | jq -r .operationId`
    RESOURCE_LOCATION=`echo $rest_api_response | jq -r .resourceLocation`
    arrayUrl=(${RESOURCE_LOCATION//\// })
    arrayUrl=(${arrayUrl[@]//[=?]/ })
    DATASET_ID=${arrayUrl[3]}
    echo -e "Success Operation=$OPERATION_ID Dataset ID=$DATASET_ID @ $RESOURCE_LOCATION"
    break
  elif [ "$rest_api_status" = "Failed" ]; then
    echo -e "Error - failed : ${rest_api_response}"
    exit 1
  else
    echo -e "Warning - Unrecognized status $rest_api_status"
  fi
done

# create a tileset
rest_api_url="https://us.atlas.microsoft.com/tileset/create/vector?api-version=1.0&datasetID=${DATASET_ID}&subscription-key=${MAPS_PRIMARY_KEY}"
declare -A HTTP_HEADERS
parse_header HTTP_HEADERS < <(
  curl -is -X POST -H "Content-Length: 0" "${rest_api_url}"
)
rest_api_status=${HTTP_HEADERS[Status]}
if [ $rest_api_status == "202" -o $rest_api_status == "201" ]; then
  echo -e "create a tileset Success [${HTTP_HEADERS[Status]}]"
else
  echo -e "Error - ${HTTP_HEADERS[Status]}"
  typeset -p HTTP_HEADERS
  exit 1
fi
rest_api_location=`echo ${HTTP_HEADERS[location]} | sed 's+https://atlas.microsoft.com+https://us.atlas.microsoft.com+g'`
unset HTTP_HEADERS

# check the status of the api call
rest_api_url=$"${rest_api_location}&subscription-key=${MAPS_PRIMARY_KEY}"
while true; do
  rest_api_response=`curl -s -X GET "$rest_api_url"`
  rest_api_status=`echo $rest_api_response | jq -r .status`
  if [[ "$rest_api_status" == "NotStarted" ]]; then
    printf "."
    sleep 1
    continue
  elif [[ "$rest_api_status" == "Running" ]]; then
    printf "."
    sleep 1
    continue
  elif [ "$rest_api_status" = "Succeeded" ]; then
    OPERATION_ID=`echo $rest_api_response | jq -r .operationId`
    RESOURCE_LOCATION=`echo $rest_api_response | jq -r .resourceLocation`
    arrayUrl=(${RESOURCE_LOCATION//\// })
    arrayUrl=(${arrayUrl[@]//[=?]/ })
    TILESET_ID=${arrayUrl[3]}
    echo -e "Success Operation=$OPERATION_ID Tileset ID=$TILESET_ID @ $RESOURCE_LOCATION"
    break
  elif [ "$rest_api_status" = "Failed" ]; then
    echo -e "Error - failed : ${rest_api_response}"
    exit 1
  else
    echo -e "Warning - Unrecognized status $rest_api_status"
  fi
done

# create a feature stateset
rest_api_url="https://us.atlas.microsoft.com/featureState/stateset?api-version=1.0&datasetId=${DATASET_ID}&subscription-key=${MAPS_PRIMARY_KEY}"
declare -A HTTP_HEADERS
STATE_SET='{"styles":[{"keyname":"occupied","type":"boolean","rules":[{"true":"#FF0000","false":"#00FF00"}]},{"keyname":"temperature","type":"number","rules":[{"range":{"exclusiveMaximum":66},"color":"#00204e"},{"range":{"minimum":66,"exclusiveMaximum":70},"color":"#0278da"},{"range":{"minimum":70,"exclusiveMaximum":74},"color":"#187d1d"},{"range":{"minimum":74,"exclusiveMaximum":78},"color":"#fef200"},{"range":{"minimum":78,"exclusiveMaximum":82},"color":"#fe8c01"},{"range":{"minimum":82},"color":"#e71123"}]}]}'
#echo -e "${STATE_SET}" | jq '.styles[]'
rest_api_response=`curl -s -X POST -H "Content-type: application/json" -d ${STATE_SET} "${rest_api_url}"`
STATESET_ID=`echo $rest_api_response | jq -r .statesetId`
echo -e "Stateset ID ${STATESET_ID}"
unset HTTP_HEADERS

# delete maps data
rest_api_url="https://us.atlas.microsoft.com/mapData?subscription-key=${MAPS_PRIMARY_KEY}&api-version=1.0"
rest_api_response=`curl -s -X GET "${rest_api_url}"`
for row in $(echo -e "${rest_api_response}" | jq -r '.mapDataList[] | @base64'); do
  _jq() {
      echo ${row} | base64 --decode | jq -r ${1}
  }
  rest_api_url="$(_jq '.location')&subscription-key=${MAPS_PRIMARY_KEY}"
  echo -e "delete maps data UDID=${UDID}"
  curl -s -X DELETE  "${rest_api_url}"
done

# update WeDX Server web app
CMDRUN=$(az webapp config appsettings set --name ${WEB_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WedxAppConfig__Maps__TileSetId=${TILESET_ID} --query "[?name=='WedxAppConfig__Maps__TileSetId'].[value]" -o tsv)
CMDRUN=$(az webapp config appsettings set --name ${WEB_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WedxAppConfig__Maps__StateSetId=${STATESET_ID} --query "[?name=='WedxAppConfig__Maps__StateSetId'].[value]" -o tsv)
CMDRUN=$(az webapp config appsettings set --name ${FUNC_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WEDX_MAPS_INDOOR_DATASET_ID=${DATASET_ID} --query "[?name=='WEDX_MAPS_INDOOR_DATASET_ID'].[value]" -o tsv)
CMDRUN=$(az webapp config appsettings set --name ${FUNC_APP_NAME} --resource-group ${RESOURCE_GROUP} --settings WEDX_MAPS_INDOOR_STATESET_ID=${STATESET_ID} --query "[?name=='WEDX_MAPS_INDOOR_STATESET_ID'].[value]" -o tsv)
echo -e "Tileset=${TILESET_ID}"
echo -e "Stateset=${STATESET_ID}"
echo -e "Dataset=${DATASET_ID}"
echo -e ""
echo -e "Complete configuration"
