#!/bin/bash

echo "Verifying whether any deployment is going on or not!!!!"

export DEPLOYMENT_ID=$(aws deploy list-deployments --application-name $DEPLOY_APP_NAME --deployment-group-name $DEPLOY_GROUP_NAME --query "deployments" | jq --raw-output '.[0]')

echo "Current Deployment id is $DEPLOYMENT_ID running"

echo "checking whether $DEPLOYMENT_ID is in blue/green deploy mode or not"

export DEPLOYMENT_STATUS=$(aws deploy get-deployment --deployment-id $DEPLOYMENT_ID | jq --raw-output '.deploymentInfo.status')

if [[ "$DEPLOYMENT_STATUS" = "InProgress" ]]; then

	echo "======================================================================="
    echo "=          Currently, Blue/Green Deployment is going on               ="  
	echo "=                Rolling back to the old feature                      ="
	echo "======================================================================="

	export ROLLBACK_STATUS=$(aws deploy stop-deployment --deployment-id $DEPLOYMENT_ID --auto-rollback-enabled)
	echo "$ROLLBACK_STATUS"
	echo "======================================================================="
    echo "=                 Rolled back to the old feature                      ="  
	echo "=              Now, We Can goahead for new deployment                 ="
	echo "======================================================================="

elif [[ "$DEPLOYMENT_STATUS" = "Succeeded" ]]; then
	echo "======================================================================"
    echo "=            No Blue/Green Deployment is running                     ="
    echo "=              Lets goahead for new deployment                       ="
	echo "======================================================================"
fi
