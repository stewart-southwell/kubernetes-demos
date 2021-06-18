#!/bin/bash

# Color theming
if [ -f ~/clouddrive/aks-demo/infrastructure/deploy/theme.sh ]
then
  . <(cat ~/clouddrive/aks-demo/infrastructure/deploy/theme.sh)
fi


if [ -f ~/clouddrive/aks-demo/create-aks-exports.txt ]
then
  eval $(cat ~/clouddrive/aks-demo/create-aks-exports.txt)
fi

demoAcrName=${LEARN_REGISTRY}
clusterAksName=${CLUSTER_NAME}
clusterSubs=${CLUSTER_SUBS}
clusterRg=${CLUSTER_RG}
clusterLocation=${CLUSTER_LOCATION}
acrIdTag=${CLUSTER_IDTAG}

while [ "$1" != "" ]; do
    case $1 in
        -s | --subscription)            shift
                                        clusterSubs=$1
                                        ;;
        -g | --resource-group)          shift
                                        clusterRg=$1
                                        ;;
        -l | --location)                shift
                                        clusterLocation=$1
                                        ;;
             --aks-name)                shift
                                        clusterAksName=$1
                                        ;;
             --acr-name)                shift
                                        learnAcrName=$1
                                        ;;
             * )                        echo "Invalid param: $1"
                                        exit 1
    esac
    shift
done

if [ -z "$clusterAksName" ]&&[ -z "$DEMO_QUICKSTART" ]
then
    echo "${newline}${errorStyle}ERROR: AKS cluster name is mandatory. Use --aks-name to set it.${defaultTextStyle}${newline}"
    exit 1
fi

if [ -z "$demoAcrName" ]&&[ -z "$DEMO_QUICKSTART" ]
then
    echo "${newline}${errorStyle}ERROR: ACR name is mandatory. Use --acr-name to set it.${defaultTextStyle}${newline}"
    exit 1
fi

if [ -z "$clusterRg" ]
then
    echo "${newline}${errorStyle}ERROR: Resource group is mandatory. Use -g to set it${defaultTextStyle}${newline}"
    exit 1
fi

if [ ! -z "$clusterSubs" ]
then
    echo "Switching to subscription $clusterSubs..."
    az account set -s $clusterSubs
fi

if [ ! $? -eq 0 ]
then
    echo "${newline}${errorStyle}ERROR: Can't switch to subscription $clusterSubs.${defaultTextStyle}${newline}"
    exit 1
fi

rg=`az group show -g $clusterRg -o json`

if [ -z "$rg" ]
then
    if [ -z "$clusterLocation" ]
    then
        echo "${newline}${errorStyle}ERROR: If resource group has to be created, location is mandatory. Use -l to set it.${defaultTextStyle}${newline}"
        exit 1
    fi
    echo "Creating RG $clusterRg in location $clusterLocation..."
    az group create -n $clusterRg -l $clusterLocation
    if [ ! $? -eq 0 ]
    then
        echo "${newline}${errorStyle}ERROR: Can't create resource group${defaultTextStyle}${newline}"
        exit 1
    fi

    echo "Created RG \"$clusterRg\" in location \"$clusterLocation\"."

else
    if [ -z "$clusterLocation" ]
    then
        clusterLocation=`az group show -g $clusterRg --query "location" -otsv`
    fi
fi

# ACR Creation

demoAcrName=${DEMO_ACRNAME}

if [ -z "$demoAcrName" ]
then

    if [ -z "$acrIdTag" ]
    then
        dateString=$(date "+%Y%m%d%H%M%S")
        random=`head /dev/urandom | tr -dc 0-9 | head -c 3 ; echo ''`

        acrIdTag="$dateString$random"
    fi

    echo
    echo "Creating Azure Container Registry aksacrdemo$acrIdTag in resource group $clusterRg..."
    acrCommand="az acr create --name aksacrdemo$acrIdTag -g $clusterRg -l $clusterLocation -o json --sku basic --admin-enabled --query \"name\" -otsv"
    echo "${newline} > ${azCliCommandStyle}$acrCommand${defaultTextStyle}${newline}"
    demoAcrName=`$acrCommand`

    if [ ! $? -eq 0 ]
    then
        echo "${newline}${errorStyle}ERROR creating ACR!${defaultTextStyle}${newline}"
        exit 1
    fi

    echo ACR created!
    echo
fi

demoRegistry=`az acr show -n $demoAcrName --query "loginServer" -otsv`

if [ -z "$demoRegistry" ]
then
    echo "${newline}${errorStyle}ERROR! ACR server $demoAcrName doesn't exist!${defaultTextStyle}${newline}"
    exit 1
fi

demoAcrCredentials=`az acr credential show -n $demoAcrName --query "[username,passwords[0].value]" -otsv`
demoAcrUser=`echo "$demoAcrCredentials" | head -1`
demoAcrPassword=`echo "$demoAcrCredentials" | tail -1`

# Grant permisions to AKS if created
demoAks=`az aks show -n $clusterAksName -g $clusterRg`

if [ ! -z "$demoAks" ]
then
    echo "Attaching ACR to AKS..."
    attachCmd="az aks update -n $clusterAksName -g $clusterRg --attach-acr $demoAcrName --output none" 
    echo "${newline} > ${azCliCommandStyle}$attachCmd${defaultTextStyle}${newline}"
    eval $attachCmd
fi

echo export CLUSTER_SUBS=$clusterSubs > create-acr-exports.txt
echo export CLUSTER_RG=$clusterRg >> create-acr-exports.txt
echo export CLUSTER_LOCATION=$clusterLocation >> create-acr-exports.txt
echo export demo_ACRNAME=$demoAcrName >> create-acr-exports.txt
echo export demo_REGISTRY=$demoRegistry >> create-acr-exports.txt
echo export demo_ACRUSER=$demoAcrUser >> create-acr-exports.txt
echo export demo_ACRPASSWORD=$demoAcrPassword >> create-acr-exports.txt
echo export CLUSTER_IDTAG=$acrIdTag >> create-acr-exports.txt

echo 
echo "Created Azure Container Registry \"$demoAcrName\" in resource group \"$clusterRg\" in location \"$clusterLocation\"." 