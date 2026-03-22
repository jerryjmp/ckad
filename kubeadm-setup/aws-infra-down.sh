#!/bin/bash

# -----------------------------
# VARIABLES
# -----------------------------
export AWS_PAGER=""

REGION="ap-south-1"

VPC_NAME="kubeadm-vpc"
SUBNET_NAME="kubeadm-subnet"
SG_NAME="kubeadm-sg"

CP_NAME="controlplane"
WK_NAME="node01"

aws configure set region $REGION

# -----------------------------
# GET INSTANCE IDS
# -----------------------------
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$CP_NAME,$WK_NAME" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [ -n "$INSTANCE_IDS" ]; then
  echo "🛑 Terminating instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
else
  echo "ℹ️ No instances found"
fi

# -----------------------------
# GET VPC ID
# -----------------------------
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [ "$VPC_ID" == "None" ]; then
  echo "❌ VPC not found, exiting"
  exit 0
fi

# -----------------------------
# DELETE SECURITY GROUP
# -----------------------------
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" \
  --output text)

if [ "$SG_ID" != "None" ]; then
  echo "🛑 Deleting security group: $SG_ID"
  aws ec2 delete-security-group --group-id $SG_ID
fi

# -----------------------------
# DELETE ROUTE TABLE (NON-MAIN)
# -----------------------------
RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[?Associations[0].Main==\`false\`].RouteTableId" \
  --output text)

for RT in $RT_ID; do
  ASSOC_ID=$(aws ec2 describe-route-tables \
    --route-table-ids $RT \
    --query "RouteTables[0].Associations[0].RouteTableAssociationId" \
    --output text)

  aws ec2 disassociate-route-table --association-id $ASSOC_ID
  aws ec2 delete-route-table --route-table-id $RT
done

# -----------------------------
# DELETE INTERNET GATEWAY
# -----------------------------
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query "InternetGateways[0].InternetGatewayId" \
  --output text)

if [ "$IGW_ID" != "None" ]; then
  echo "🛑 Detaching & deleting IGW: $IGW_ID"
  aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
  aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
fi

# -----------------------------
# DELETE SUBNET
# -----------------------------
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=$SUBNET_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[0].SubnetId" \
  --output text)

if [ "$SUBNET_ID" != "None" ]; then
  echo "🛑 Deleting subnet: $SUBNET_ID"
  aws ec2 delete-subnet --subnet-id $SUBNET_ID
fi

# -----------------------------
# DELETE VPC
# -----------------------------
echo "🛑 Deleting VPC: $VPC_ID"
aws ec2 delete-vpc --vpc-id $VPC_ID

echo "✅ AWS kubeadm infrastructure destroyed successfully"
