#!/bin/bash

###############################################
# VARIABLES
###############################################

# Your private key used to SSH into EC2
PEM_FILE="masterkey.pem"

# Your public key that will be injected into remote servers
PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

# Dynamic inventory file
INVENTORY_FILE="inventory/aws_ec2.yaml"


###############################################
# GET HOSTS FROM DYNAMIC INVENTORY
###############################################
# This extracts all hostnames/IPs from Ansible inventory
HOSTS=$(ansible-inventory -i $INVENTORY_FILE --list | jq -r '._meta.hostvars | keys[]')


###############################################
# LOOP THROUGH EACH HOST AND INJECT KEY
###############################################
for HOST in $HOSTS; do
  echo "Injecting key into $HOST"

  ################################################
  # DETECT OS FAMILY USING ANSIBLE FACTS
  ################################################
  # This checks whether the machine is Ubuntu (Debian)
  # or Amazon Linux / RedHat
  OS_FAMILY=$(ansible -i $INVENTORY_FILE $HOST -m setup -a 'filter=ansible_os_family' \
               | grep ansible_os_family | awk -F'"' '{print $4}')

  ################################################
  # SELECT CORRECT SSH USER BASED ON OS
  ################################################
  if [[ "$OS_FAMILY" == "Debian" ]]; then
    USER="ubuntu"          # Ubuntu default user
  else
    USER="ec2-user"        # Amazon Linux / RedHat default user
  fi

  ################################################
  # INJECT PUBLIC KEY INTO REMOTE SERVER
  ################################################
  ssh -o StrictHostKeyChecking=no -i $PEM_FILE $USER@$HOST "
    mkdir -p ~/.ssh && \
    echo \"$PUB_KEY\" >> ~/.ssh/authorized_keys && \
    chmod 700 ~/.ssh && \
    chmod 600 ~/.ssh/authorized_keys
  "

done

