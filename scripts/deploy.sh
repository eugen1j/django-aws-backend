#!/bin/bash

set -e

echo "Collecting data..."
ECS_GROUP_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=prod-ecs-backend --query "SecurityGroups[*][GroupId]" --output text)
PRIVATE_SUBNET_ID=$(aws ec2 describe-subnets  --filters "Name=tag:Name,Values=prod-private-1" --query "Subnets[*][SubnetId]"  --output text)

echo "Running migration task..."
NETWORK_CONFIGURATON="{\"awsvpcConfiguration\": {\"subnets\": [\"${PRIVATE_SUBNET_ID}\"], \"securityGroups\": [\"${ECS_GROUP_ID}\"],\"assignPublicIp\": \"DISABLED\"}}"
MIGRATION_TASK_ARN=$(aws ecs run-task --cluster prod --task-definition backend-migration --count 1 --launch-type FARGATE --network-configuration "${NETWORK_CONFIGURATON}" --query 'tasks[*][taskArn]' --output text)

if [ -z "$MIGRATION_TASK_ARN" ]
then
  echo "Fail to run migration ecs task"
  exit 1
fi

echo "Task ${MIGRATION_TASK_ARN} running..."
aws ecs wait tasks-stopped --cluster prod --tasks "${MIGRATION_TASK_ARN}"

echo "Updating web..."
aws ecs update-service --cluster prod --service prod-backend-web --force-new-deployment  --query "service.serviceName"  --output json

echo "Done!"