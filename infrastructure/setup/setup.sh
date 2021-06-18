#!/bin/bash

while [ "$1" != "" ]; do
    case $1 in
        -s | --subscription)            shift
                                        clusterSubs=$1
                                        ;;
        -n | --name)                    shift
                                        moduleName=$1
                                        ;;
        -a | --use-acr)                 shift
                                        useACR=$1
                                        ;;
        -i | --install-dot-net)         shift
                                        installDotNet=$1
                                        ;;
             * )                        echo "Invalid param: $1"
                                        exit 1
    esac
    shift
done

if [ -z "$clusterSubs" ]; then
     echo "${newline}${errorStyle}ERROR: Subscription is mandatory. Use -s to set it.$clusterSubs.${defaultTextStyle}${newline}"
     listSubsCommand="az account list -o table"
     $listSubsCommand
     echo "${newline}Use one of the ${azCliCommandStyle}SubscriptionId${defaultTextStyle} above to run the command${newline}"
     return 1
fi

if [ -z "$moduleName" ]; then
     echo "${newline}${errorStyle}ERROR: Cluster name is mandatory. Use -n to set it.$clusterSubs.${defaultTextStyle}${newline}"
     return 1
fi

## Start
cd ~

# dotnet SDK version
declare -x dotnetSdkVersion="3.1.302"

# Module name
if [ -z "$moduleName" ]; then
    declare moduleName="aks-demo"
fi

# Any other declarations we need
declare gitUser="stewart-southwell"
declare -x gitBranch="main"
declare initScript=https://raw.githubusercontent.com/$gitUser/kubernetes-demos/$gitBranch/infrastructure/setup/init-env.sh
declare suppressAzureResources=false
declare rootLocation=~/clouddrive
declare editorHomeLocation=$rootLocation/aks-demo

if [ -d "$rootLocation/aks-demo" ]; then
    echo "$rootLocation/aks-demo/ already exists!"
    echo " "
    echo "Before running this script, please remove or rename the existing $rootLocation/aks-demo/ directory as follows:"
    echo "Remove: rm -r $rootLocation/aks-demo/"
    echo "Rename: mv $rootLocation/aks-demo/ ~/clouddrive/new-name-here/ "
    echo " "
    return 1
else
    # Backup .bashrc
    cp ~/.bashrc ~/.bashrc.bak.$moduleName

    if [ -z "$installDotNet" ]; then
        declare installDotNet="false"
    fi

    # Grab and run initenvironment.sh
    . <(wget -q -O - $initScript)

    # Download and build
    downloadAndBuild

    # Set location to ~/clouddrive
    cd $editorHomeLocation

    # Run kubernetes-demo quickstart to deploy to AKS
    $editorHomeLocation/infrastructure/deploy/k8s/quickstart.sh --subscription $clusterSubs --resource-group $resourceGroupName -n $moduleName --location westus

    # Create ACR resource
    if [ -z "$useACR" ]; then
        declare useACR="false"
    fi

    echo "useACR $useACR"

    if  ! [ -z "$useACR" ] && [ $useACR == true ]; then
        $editorHomeLocation/infrastructure/deploy/k8s/create-acr.sh --subscription $clusterSubs --resource-group $resourceGroupName --aks-name $moduleName --acr-name demo-aks-acr --location eastus
    fi

    # Display information to use
    echo "Azure Container Registry Information"
    echo "=================================================================================="
    cat ~/clouddrive/aks-demo/create-acr-exports.txt
    echo "=================================================================================="
    echo 
    echo
    echo "Azure Container Kubernetes Cluster Information"
    echo "=================================================================================="
    cat ~/clouddrive/aks-demo/create-aks-exports.txt
    echo "=================================================================================="
fi

#Reset variables
declare clusterSubs=""
declare moduleName=""
declare useACR="false"
declare installDotNet="false"