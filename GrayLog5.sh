#!/bin/bash

# GrayLog 5.0 Installer

# Input Variables
ADMIN_PASSWORD=$(whiptail --inputbox "Please enter your login password for admin user:" 10 40 --title "Input Prompt" 3>&1 1>&2 2>&3)


# Global variable to store the validated IP address
VALID_IP=""

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
        VALID_IP="$ip"
        whiptail --msgbox "The IP address $VALID_IP is valid!" 8 40 --title "Valid IP"
        return 0
    else
        whiptail --msgbox "Invalid IP format. Please enter in the format x.x.x.x" 8 40 --title "Invalid IP"
        return 1
    fi
}

# Call the function
if validate_ip; then
    echo "Validated IP Address: $VALID_IP"
else
    echo "IP Address validation failed."
fi



sudo apt update -y
sudo apt upgrade -y
sudo apt install apt-transport-https wget curl uuid-runtime ca-certificates gnupg2 -y

echo -e "\n\nInstalling Mongo DB"
curl -sSL https://www.mongodb.org/static/pgp/server-6.0.asc -o mongoserver.asc
gpg --no-default-keyring --keyring ./mongo_key_temp.gpg --import ./mongoserver.asc
gpg --no-default-keyring --keyring ./mongo_key_temp.gpg --export > ./mongoserver_key.gpg
sudo mv mongoserver_key.gpg /etc/apt/trusted.gpg.d/
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt install mongodb-org -y
sudo systemctl enable --now mongod
sudo systemctl restart mongod.service
sudo systemctl status mongod

echo -e "\n\nInstalling Elastic Search"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
sudo apt install elasticsearch -y

sudo tee -a /etc/elasticsearch/elasticsearch.yml > /dev/null <<EOT 
cluster.name: graylog 
action.auto_create_index: false 
EOT

sudo systemctl daemon-reload
sudo systemctl enable --now elasticsearch
sudo systemctl start elasticsearch
sudo systemctl status elasticsearch

echo -e "\n\nInstalling GrayLog 5.0"

wget https://packages.graylog2.org/repo/packages/graylog-5.0-repository_latest.deb
sudo dpkg -i graylog-5.0-repository_latest.deb
sudo apt update -y && sudo apt-get install graylog-server -y
# sed -i "s/^password_secret = /password_secret = $SECRET/g" /etc/graylog/server/server.conf
# vim /etc/graylog/server/server.conf
# PASSWORD=$(echo -n "Enter Password: " && head -1 </dev/stdin | tr -d '\n' | sha256sum | cut -d" " -f1)

SECRET=$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-96};echo;)
sed -i "/^password_secret/c\password_secret = ${SECRET}" /etc/graylog/server/server.conf

PASSWORD=$(echo -n "$ADMIN_PASSWORD" | sha256sum | cut -d" " -f1)
sed -i "/^root_password_sha2 = /root_password_sha2 = ${PASSWORD}" /etc/graylog/server/server.conf
sed -i "/^#http_bind_address = /http_bind_address = ${VALID_IP}" /etc/graylog/server/server.conf


sudo systemctl daemon-reload
sudo systemctl enable --now graylog-server
sudo systemctl restart graylog-server
sudo systemctl status graylog-server

exit 0
