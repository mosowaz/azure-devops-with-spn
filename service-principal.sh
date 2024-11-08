#!/bin/bash

# variables
RG_NAME='ADO-project2'
SPN_NAME='ADO-SPN-project2'
LOCATION='canadacentral'
ROLE1='Contributor'
ROLE2='Storage Blob Data Contributor'
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# Azure CLI commands to create service principal and assign multiple roles
az group create --name $RG_NAME --location $LOCATION

az ad sp create-for-rbac --name $SPN_NAME \
--role $ROLE1 --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME

az role assignment create --assignee $SPN_NAME --role $ROLE2 --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME