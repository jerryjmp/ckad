#!/bin/bash

# -----------------------------
# VARIABLES
# -----------------------------
export AWS_PAGER=""

REGION="ap-south-1"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"

VPC_NAME="kubeadm-vpc"
SUBNET_NAME="kubeadm-subnet"
SG_NAME="kubeadm-sg"

KEY_NAME="aws-new"   # must already exist
AMI_ID="ami-0f58b397bc5c1f2e8"  # Ubuntu 24.04 (Mumbai)
# AMI_ID="ami-0b6c6ebed2801a5cb" # us-east-1

CP_NAME="controlplane"
WK_NAME="node01"

CP_TYPE="t3.small"   # 2 vCPU, 2GB
WK_TYPE="t3.micro"   # 1 vCPU, 1GB

# -----------------------------
# CREATE VPC
# -----------------------------
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 create-tags \
  --resources $VPC_ID \
  --tags Key=Name,Value=$VPC_NAME

# -----------------------------
# CREATE SUBNET
# -----------------------------
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --query 'Subnet.SubnetId' \
  --output text)

aws ec2 create-tags \
  --resources $SUBNET_ID \
  --tags Key=Name,Value=$SUBNET_NAME

# -----------------------------
# INTERNET GATEWAY
# -----------------------------
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID

# -----------------------------
# ROUTE TABLE
# -----------------------------
RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table \
  --route-table-id $RT_ID \
  --subnet-id $SUBNET_ID

# -----------------------------
# SECURITY GROUP (ALLOW ALL)
# ⚠️ LAB ONLY
# -----------------------------
SG_ID=$(aws ec2 create-security-group \
  --group-name $SG_NAME \
  --description "Allow all inbound traffic - lab only" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow ALL inbound (TCP, UDP, ICMP, etc)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol -1 \
  --cidr 0.0.0.0/0


# -----------------------------
# CREATE CONTROL PLANE EC2
# -----------------------------
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $CP_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$CP_NAME}]" \
  --associate-public-ip-address \
  --count 1

# -----------------------------
# CREATE WORKER NODE EC2
# -----------------------------
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $WK_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$WK_NAME}]" \
  --associate-public-ip-address \
  --count 1

# -----------------------------
# WAIT FOR INSTANCES TO BE RUNNING
# -----------------------------
echo "⏳ Waiting for instances to be running..."
aws ec2 wait instance-running \
  --filters "Name=tag:Name,Values=$CP_NAME,$WK_NAME"

# -----------------------------
# GET PUBLIC IPs
# -----------------------------
CP_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$CP_NAME" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

WK_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$WK_NAME" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "✅ AWS kubeadm infrastructure created"

echo ""
echo "======================================"
echo "KUBEADM NODES"
echo "======================================"
echo "Control Plane : $CP_NAME  →  $CP_IP"
echo "Worker Node   : $WK_NAME  →  $WK_IP"
echo ""
echo "SSH access:"
echo "ssh -i $KEY_NAME.pem ubuntu@$CP_IP"
echo "ssh -i $KEY_NAME.pem ubuntu@$WK_IP"
echo "======================================"

