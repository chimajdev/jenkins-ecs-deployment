#!/bin/bash


REPOSITORY_URI=$ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
NETWORK_MODE="bridge"
CLUSTER_ARN=arn:aws:ecs:ap-south-1:$ACCOUNT_ID:cluster/$CLUSTER_NAME


# Using Amazon Dev IAM Credentials
export AWS_PROFILE=$AWS_PROFILE_SERVER
export AWS_DEFAULT_REGION=$AWS_REGION

# Creating new revision
export TASK_REVISION=$(aws ecs register-task-definition --family $TASK_FAMILY --task-role-arn $TASK_ROLE --network-mode $NETWORK_MODE --container-definitions "[{\"logConfiguration\":{\"logDriver\":\"awslogs\",\"options\":{\"awslogs-group\":\"$LOG_GROUP\",\"awslogs-region\":\"$AWS_DEFAULT_REGION\"}},\"name\":\"$CONTAINER_NAME\",\"environment\":[{\"name\":\"NODE_ENV\",\"value\":\"$NODE_ENV\"}],\"image\":\"$REPOSITORY_URI/$IMAGE_NAME:prod_v1.0.$BUILD_NUMBER\",\"memoryReservation\":$SOFT_LIMIT,\"portMappings\":[{\"hostPort\":0,\"protocol\":\"tcp\",\"containerPort\":$CONTAINER_PORT}],\"essential\":true}]" --cpu $TASK_CPU --memory $TASK_MEMORY --tags "[{\"key\":\"ClusterName\",\"value\":\"$CLUSTER_NAME\"},{\"key\":\"ServiceName\",\"value\":\"$SERVICE_NAME\"}]" | jq --raw-output '.taskDefinition.taskDefinitionArn')

echo "================================================================================================================="
echo "New task revision has been created $TASK_REVISION"
echo "================================================================================================================="

echo "================================================================================================================="
echo "                                  Blue Green Deployment is starting now                                          "
echo "================================================================================================================="

# Blue Green Deployment
export DEPLOYMENT_ID=$(aws deploy create-deployment \
  --application-name $DEPLOY_APP_NAME \
  --deployment-group-name $DEPLOY_GROUP_NAME \
  --revision '{"revisionType":"AppSpecContent","appSpecContent":{"content":"{\"version\":1,\"Resources\":[{\"TargetService\":{\"Type\":\"AWS::ECS::Service\",\"Properties\":{\"TaskDefinition\":\"'$TASK_REVISION'\",\"LoadBalancerInfo\":{\"ContainerName\":\"'$CONTAINER_NAME'\",\"ContainerPort\":'$CONTAINER_PORT'},\"PlatformVersion\":null}}}]}"}}' | jq --raw-output '.deploymentId' )

echo "================================================================================================================="
echo "                          New Deployment id has been generated now $DEPLOYMENT_ID                                "
echo "================================================================================================================="

echo "Please wait for some time. Traffic is routing to new task ........"

### monitors the service deployment on ecs

while [ "DEPLOYMENT_STATUS" != "Succeeded" ]

do
  sleep 2
  export DEPLOYMENT_STATUS=$(aws deploy get-deployment-target --deployment-id $DEPLOYMENT_ID --target-id $CLUSTER_NAME:$SERVICE_NAME --region $AWS_DEFAULT_REGION | jq --raw-output '.deploymentTarget.ecsTarget.status')
  
  echo "Traffic is routing....."
  if [[ "$DEPLOYMENT_STATUS" = "Failed" ]]; then
      echo "Deployment has been failed"
      exit 1;
  elif [[ "$DEPLOYMENT_STATUS" = "Skipped" ]]; then
      echo "Deployment has been Skipped/Failed"
      exit 1;
  elif [[ "$DEPLOYMENT_STATUS" = "Unknown" ]]; then
      echo "Deployment lifecycle event is unkown"
      exit 1;
  elif [[ "$DEPLOYMENT_STATUS" = "Succeeded" ]]; then
      echo "================================================================================================================="
      echo "========================>Successfully traffic has been routed to new task<======================================="
      echo "The old task will run for 1 hour. Please trigger the Rollback Job if you want to rollback to old feature"
      echo "================================================================================================================="
      break
  fi
done
