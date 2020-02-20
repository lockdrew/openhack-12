# Create the Azure AD application
serverApplicationId=$(az ad app create \
    --display-name "$aksProdServer" \
    --identifier-uris "https://$aksProdServer" \
    --query appId -o tsv)

# Update the application group memebership claims
az ad app update --id $serverApplicationId --set groupMembershipClaims=All

# Create a service principal for the Azure AD application
az ad sp create --id $serverApplicationId

# Get the service principal secret
serverApplicationSecret=$(az ad sp credential reset \
    --name $serverApplicationId \
    --credential-description "AKSPassword" \
    --query password -o tsv)

#Add permissions to the active directory server application (Guids are hard coded to different permissions levels)
az ad app permission add \
    --id $serverApplicationId \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role

clientApplicationId=$(az ad app create \
    --display-name "${aksname}Client" \
    --native-app \
    --reply-urls "https://${aksname}Client" \
    --query appId -o tsv)

az ad sp create --id $clientApplicationId

oAuthPermissionId=$(az ad app show --id $serverApplicationId --query "oauth2Permissions[0].id" -o tsv)

az ad app permission add --id $clientApplicationId --api $serverApplicationId --api-permissions $oAuthPermissionId=Scope
az ad app permission grant --id $clientApplicationId --api $serverApplicationId

az group create --name aksProd --location southcentralus

SUBNET_ID=$(az network vnet subnet show \  --resource-group aksworkshop \  --vnet-name aks-vnet \  --name aks-subnet \  --query id -o tsv)

tenantId=$(az account show --query tenantId -o tsv)

az aks create --resource-group aksprod --name $aksname --node-count 3 --generate-ssh-keys --aad-server-app-id $serverApplicationId --aad-server-app-secret $serverApplicationSecret --aad-client-app-id $clientApplicationId --aad-tenant-id $tenantId --vnet-subnet-id $SUBNET_ID --network-plugin azure --kubernetes-version 1.17.0

az aks get-credentials --resource-group myResourceGroup --name $aksname --overwrite-existing