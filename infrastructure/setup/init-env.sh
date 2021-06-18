# This script expects the following environment variables:
# moduleName
# eg. declare moduleName="aks-deploy-helm"
#
# scriptPath
# projectRootDirectory

# Common Declarations
declare gitUser="stewart-southwell"
declare scriptPath=https://raw.githubusercontent.com/$gitUser/kubernetes-demos/$gitBranch/infrastructure/scripts
declare dotnetScriptsPath=$scriptPath/dotnet
declare instanceId=$(($RANDOM * $RANDOM))
declare gitDirectoriesToClone="infrastructure/deploy/ modules/$moduleName/src/"
declare gitPathToCloneScript=https://raw.githubusercontent.com/$gitUser/kubernetes-demos/$gitBranch/infrastructure/setup/sparsecheckout.sh

if ! [ $rootLocation ]; then
    declare rootLocation=~
fi

declare subscriptionId=$(az account show --query id --output tsv)
declare resourceGroupName=""
declare defaultLocation="eastus"

# Functions
setAzureCliDefaults() {
    echo "${headingStyle}Setting default Azure CLI values...${azCliCommandStyle}"
    (
        set -x
        az configure --defaults \
            group=$resourceGroupName \
            location=$defaultLocation
    )
}

resetAzureCliDefaults() {
    echo "${headingStyle}Resetting default Azure CLI values...${azCliCommandStyle}"
    (
        set -x
        az configure --defaults \
            group= \
            location=
    )
}

configureDotNetCli() {
    echo "${newline}${headingStyle}Configuring the .NET Core CLI...${defaultTextStyle}"
    declare installedDotNet=$(dotnet --version)

    if [ "$dotnetSdkVersion" != "$installedDotNet" ]; then
        # Install .NET Core SDK
        wget -q -O - https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --version $dotnetSdkVersion
    else 
        echo ".NET Core SDK version $dotnetSdkVersion already installed."
    fi

    setPathEnvironmentVariableForDotNet

    # By default, the .NET Core CLI prints Welcome and Telemetry messages on
    # the first run. Suppress those messages by creating an appropriately
    # named file on disk.
    touch ~/.dotnet/$dotnetSdkVersion.dotnetFirstUseSentinel

    # Suppress priming the NuGet package cache with assemblies and 
    # XML docs we won't need.
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
    echo "export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true" >> ~/.bashrc
    export NUGET_XMLDOC_MODE=skip
    echo "export NUGET_XMLDOC_MODE=skip" >> ~/.bashrc
    
    # Disable the sending of telemetry to the mothership.
    export DOTNET_CLI_TELEMETRY_OPTOUT=true
    echo "export DOTNET_CLI_TELEMETRY_OPTOUT=true" >> ~/.bashrc
    
    # Add tab completion for .NET Core CLI
    tabSlug="#dotnet-tab-completion"
    tabScript=$dotnetScriptsPath/tabcomplete.sh
    if ! [[ $(grep $tabSlug ~/.bashrc) ]]; then
        echo $tabSlug >> ~/.bashrc
        wget -q -O - $tabScript >> ~/.bashrc
        . <(wget -q -O - $tabScript)
    fi
    
    # Generate developer certificate so ASP.NET Core projects run without complaint
    dotnet dev-certs https --quiet
}

setPathEnvironmentVariableForDotNet() {
    # Add a note to .bashrc in case someone is running this in their own Cloud Shell
    echo "# The following was added by Kubernetes Demos $moduleName" >> ~/.bashrc

    # Add .NET Core SDK and .NET Core Global Tools default installation directory to PATH
    if ! [ $(echo $PATH | grep .dotnet) ]; then 
        export PATH=~/.dotnet:~/.dotnet/tools:$PATH; 
        echo "# Add custom .NET Core SDK to PATH" >> ~/.bashrc
        echo "export PATH=~/.dotnet:~/.dotnet/tools:\$PATH;" >> ~/.bashrc
    fi
}

downloadAndBuild() {
    # Set location
    cd $rootLocation

    # Set global Git config variables
    git config --global user.name "Kubernetes Traveler"
    git config --global user.email kubernetes-demo@improving.com.com
    
    # Download the sample project, restore NuGet packages, and build
    echo "${newline}${headingStyle}Downloading code...${defaultTextStyle}"
    (
        set -x
        wget -q -O - $gitPathToCloneScript | bash -s $gitDirectoriesToClone
    )
    echo "${defaultTextStyle}"
}

# Provision Azure Resource Group
# Should only ever run if we're running in the Cloud Shell
provisionResourceGroup() {
    if [ "$resourceGroupName" = "$moduleName" ]; then
        (
            echo "${newline}${headingStyle}Provisioning Azure Resource Group...${azCliCommandStyle}"
            set -x
            az group create \
                --name $resourceGroupName \
                --output none
        )
    fi
}

addVariablesToStartup() {
    if ! [[ $(grep $variableScript ~/.bashrc) ]]; then
        echo "${newline}# Next line added at $(date) by Kubernetes Demo $moduleName" >> ~/.bashrc
        echo ". ~/$variableScript" >> ~/.bashrc
    fi 
}

displayGreeting() {
    # Set location
    cd ~

    # Display installed .NET Core SDK version
    if ! [ "$installDotNet" ]; then
        echo "${defaultTextStyle}Using .NET Core SDK version ${headingStyle}$dotnetSdkVersion${defaultTextStyle}"
    fi
    
    # Install .NET Core global tool to display connection info
    dotnet tool install dotnetsay --global --version 2.1.7 --verbosity quiet

    # Greetings!
    if [ "$dotnetBotGreeting" ]; then
        greeting="${newline}${defaultTextStyle}$dotnetBotGreeting${dotnetSayStyle}"
    else
        greeting="${newline}${defaultTextStyle}Hi there!${newline}"
        greeting+="I'm going to provision some ${azCliCommandStyle}Azure${defaultTextStyle} resources${newline}"
        greeting+="and get the code you'll need for this module.${dotnetSayStyle}"
    fi

    dotnetsay "$greeting"
}

summarize() {
    summary="${newline}${successStyle}Your environment is ready!${defaultTextStyle}${newline}"
    summary+="I set up some ${azCliCommandStyle}Azure${defaultTextStyle} resources and downloaded the code you'll need.${newline}"
    summary+="You can resume this session and display this message again by re-running the script.${dotnetSayStyle}"
    dotnetsay "$summary"
}

determineResourceGroup() {
    resourceGroupName="$moduleName-rg"
    echo "Using Azure resource group ${azCliCommandStyle}$resourceGroupName${defaultTextStyle}."
}

checkForCloudShell() {
    # Check to make sure we're in Azure Cloud Shell
    if [ "${AZURE_HTTP_USER_AGENT:0:11}" != "cloud-shell" ]; then
        echo "${warningStyle}WARNING!!!" \
            "It appears you aren't running this script in an instance of Azure Cloud Shell." \
            "This script was designed for the environment in Azure Cloud Shell, and I can make no promises that it'll function as intended anywhere else." \
            "Please only proceed if you know what you're doing.${newline}${newline}" \
            "Do you know what you're doing?${defaultTextStyle}"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) break;;
                No )  return 0;;
            esac
        done
    fi
}

# Load the theme
declare themeScript=$scriptPath/theme.sh
. <(wget -q -O - $themeScript)

# Execute functions
checkForCloudShell

# Check if resource group is needed 
if [ $suppressAzureResources != true ]; then
    determineResourceGroup
fi

if  ! [ -z "$installDotNet" ] && [ $installDotNet == true ]; then
    configureDotNetCli
else
    setPathEnvironmentVariableForDotNet
fi

displayGreeting

# Additional setup in setup.sh occurs next.