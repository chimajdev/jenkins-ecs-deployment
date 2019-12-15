#!/bin/bash

#Colour Config
RED='\033[0;31m'
NC='\033[0m'
CYAN='\e[36m'
BLUE='\e[34m'

#Deploy Config
REPOSITORY_URI=$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
NETWORK_MODE="bridge"
CLUSTER_ARN=arn:aws:ecs:ap-south-1:$ACCOUNT_ID:cluster/$CLUSTER_NAME


export AWS_PROFILE=$AWS_PROFILE_SERVER
export AWS_DEFAULT_REGION=$AWS_REGION

export RUNNING_TASK_ID=$(aws ecs list-tasks --cluster $CLUSTER_NAME --desired-status RUNNING --family $TASK_FAMILY | jq -r ".taskArns[0]")

echo -e "Current Running Task ID is ${RED} $RUNNING_TASK_ID ${NC}"

export RUNNING_TASK=$(aws ecs describe-services  --cluster $CLUSTER_NAME --services $SERVICE_NAME | jq -r ".services[0].taskDefinition")


echo -e "Current Running Task revision is ${RED} $RUNNING_TASK ${NC}"


# Create the service with the new task definition,container port, cpu memory
export TASK_REVISION=$(aws ecs register-task-definition --family $TASK_FAMILY --task-role-arn $TASK_ROLE --network-mode $NETWORK_MODE --container-definitions "[{\"logConfiguration\":{\"logDriver\":\"awslogs\",\"options\":{\"awslogs-group\":\"$LOG_GROUP\",\"awslogs-region\":\"$AWS_DEFAULT_REGION\"}},\"name\":\"$CONTAINER_NAME\",\"environment\":[{\"name\":\"NODE_ENV\",\"value\":\"$NODE_ENV\"}],\"image\":\"$REPOSITORY_URI/$IMAGE_NAME:$BUILD_NUMBER\",\"memoryReservation\":$SOFT_LIMIT,\"portMappings\":[{\"hostPort\":0,\"protocol\":\"tcp\",\"containerPort\":$CONTAINER_PORT}],\"essential\":true}]" --cpu $TASK_CPU --memory $TASK_MEMORY --tags "[{\"key\":\"ClusterName\",\"value\":\"$CLUSTER_NAME\"},{\"key\":\"ServiceName\",\"value\":\"$SERVICE_NAME\"}]" | jq --raw-output '.taskDefinition.revision')

echo -e "New Task Revision of ${RED} $TASK_FAMILY ${NC} has been created with revision number: ${RED}$TASK_REVISION${NC}"

echo -e "Stopping the Current Task ${RED} $RUNNING_TASK ${NC} of ${RED} $SERVICE_NAME ${NC} in ${RED} $CLUSTER_NAME ${NC} Cluster "

#Stop the current running task
aws ecs stop-task --cluster $CLUSTER_NAME --task $RUNNING_TASK_ID

# Updating the Service with new task revision
export TASK_STATE=$(aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $TASK_FAMILY:$TASK_REVISION --desired-count $DESIRED_COUNT | jq --raw-output '.service.taskDefinition')

echo -e "New task revision ${RED} $TASK_STATE ${NC} has been updated "

#monitoring the deployment
export DEPLOYMENT_STATUS=$(ecs-deployment-monitor --cluster $CLUSTER_ARN --service-name $SERVICE_NAME --task-definition $TASK_STATE)


if [[ $DEPLOYMENT_STATUS == *"Failure"* ]]; then
    echo -e "Deployment has been failed"
    exit 1;
else 
    echo -e "Deployment was Successfully Completed"
fi
