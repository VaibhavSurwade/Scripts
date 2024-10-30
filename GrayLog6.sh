#!/bin/bash

# GrayLog 6.0 Installer

# Input Variables
ADMIN_PASSWORD=$(whiptail --inputbox "Please enter your login password for admin user:" 10 40 --title "Input Prompt" 3>&1 1>&2 2>&3)


# Global variable to store the validated IP address
NODE_IP_ADDRESS=""

# Function to validate IP address
validate_ip() {
    local ip
    ip=$(whiptail --inputbox "Please enter an IP address:" 10 40 --title "IP Address Input" 3>&1 1>&2 2>&3)

    # Check if the IP address is valid
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Validate each octet is between 0 and 255
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                whiptail --msgbox "Invalid IP address. Each octet must be between 0 and 255." 8 40 --title "Invalid IP"
                return 1
            fi
        done
        # Save the valid IP to the global variable
        NODE_IP_ADDRESS="$ip"
        whiptail --msgbox "The IP address $NODE_IP_ADDRESS is valid!" 8 40 --title "Valid IP"
        return 0
    else
        whiptail --msgbox "Invalid IP format. Please enter in the format x.x.x.x" 8 40 --title "Invalid IP"
        return 1
    fi
}

# Call the function
if validate_ip; then
    echo "Validated IP Address: $NODE_IP_ADDRESS"
else
    echo "IP Address validation failed."
    exit 1
fi



sudo apt update -y
sudo apt upgrade -y
sudo apt install apt-transport-https wget curl uuid-runtime ca-certificates gnupg gnupg2 -y

echo -e "\n\nInstalling Mongo DB"

curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt-get update -y
sudo apt-get install -y mongodb-org

wget -qO- 'http://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf5679a222c647c87527c2f8cb00a0bd1e2c63c11' | sudo apt-key add -

sudo systemctl daemon-reload
sudo systemctl enable mongod.service
sudo systemctl restart mongod.service
sudo systemctl --type=service --state=active | grep mongod
sudo apt-mark hold mongodb-org

echo -e "\n\nInstalling Graylog Data Node"
wget https://packages.graylog2.org/repo/packages/graylog-6.1-repository_latest.deb
sudo dpkg -i graylog-6.1-repository_latest.deb
sudo apt-get update -y
sudo apt-get install graylog-datanode -y
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count = 262144" | sudo tee /etc/sysctl.d/99-graylog-datanode.conf
sudo sed -i "/^password_secret =/s/$/ $(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-96})/" /etc/graylog/datanode/datanode.conf
sudo systemctl enable graylog-datanode.service
sudo systemctl start graylog-datanode
sudo systemctl status graylog-datanode


sudo apt-get install graylog-server
PASSWORD=$(echo -n "$ADMIN_PASSWORD" | sha256sum | cut -d" " -f1)
sed -i "/^root_password_sha2 = /root_password_sha2 = ${PASSWORD}" /etc/graylog/server/server.conf
sed -i "/^#http_bind_address = /http_bind_address = ${VALID_IP}" /etc/graylog/server/server.conf

sudo systemctl daemon-reload
sudo systemctl enable graylog-server.service
sudo systemctl start graylog-server.service
sudo systemctl --type=service --state=active | grep graylog

