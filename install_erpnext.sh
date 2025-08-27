#!/bin/bash

# ERPNext Automated Installation Script for Ubuntu
# Supports both test and production environments
# Author: ERPNext Deployment Script
# Date: 2025-08-27
# Version: 2.0

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging setup
LOG_FILE="erpnext_install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${GREEN}ERPNext Installation Script Started${NC}"
echo -e "Log file: $LOG_FILE"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Please do not run this script as root.${NC}"
  echo -e "The script will request sudo privileges when needed."
  exit 1
fi

# Function to print section headers
print_section() {
  echo -e "\n${BLUE}=========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}=========================================${NC}\n"
}

# Function to check last command status
check_status() {
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Success${NC}"
  else
    echo -e "${RED}✗ Failed${NC}"
    echo -e "Check the log file $LOG_FILE for details."
    exit 1
  fi
}

# Function to install packages with error handling
install_packages() {
  sudo apt-get install -y "$@" >> "$LOG_FILE" 2>&1
}

# Capture user input
print_section "ERPNext Deployment Configuration"

# Set default values
DEFAULT_DEPLOYMENT="test"
DEFAULT_SITE_NAME="localhost"
DEFAULT_MYSQL_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16 ; echo '')
DEFAULT_ADMIN_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16 ; echo '')

# Get user inputs
read -p "Enter your preferred Linux username [frappe]: " LINUX_USERNAME
LINUX_USERNAME=${LINUX_USERNAME:-frappe}

read -p "Enter your preferred MariaDB username [frappe]: " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-frappe}

read -p "Enter your preferred MariaDB password [random]: " MYSQL_PASSWORD
MYSQL_PASSWORD=${MYSQL_PASSWORD:-$DEFAULT_MYSQL_PASSWORD}

read -p "Enter deployment type (test/production) [$DEFAULT_DEPLOYMENT]: " DEPLOYMENT_TYPE
DEPLOYMENT_TYPE=${DEPLOYMENT_TYPE:-$DEFAULT_DEPLOYMENT}

if [ "$DEPLOYMENT_TYPE" = "production" ]; then
  read -p "Enter your domain name [example.com]: " SITE_NAME
  SITE_NAME=${SITE_NAME:-example.com}
else
  SITE_NAME=$DEFAULT_SITE_NAME
fi

read -p "Enter ERPNext admin password [random]: " ADMIN_PASSWORD
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$DEFAULT_ADMIN_PASSWORD}

# Display configuration summary
echo -e "\n${YELLOW}Configuration Summary:${NC}"
echo -e "Linux Username: $LINUX_USERNAME"
echo -e "MariaDB Username: $MYSQL_USER"
echo -e "MariaDB Password: $MYSQL_PASSWORD"
echo -e "Deployment Type: $DEPLOYMENT_TYPE"
echo -e "Site Name: $SITE_NAME"
echo -e "Admin Password: $ADMIN_PASSWORD"
echo -e "Log File: $LOG_FILE"

read -p "Proceed with installation? (y/n): " PROCEED
if [ "$PROCEED" != "y" ] && [ "$PROCEED" != "Y" ]; then
  echo -e "${RED}Installation aborted by user.${NC}"
  exit 0
fi

print_section "Setting Up System User"
# Create user if doesn't exist
if id "$LINUX_USERNAME" &>/dev/null; then
  echo -e "User $LINUX_USERNAME already exists."
else
  echo -e "Creating user $LINUX_USERNAME..."
  sudo adduser --disabled-password --gecos "" "$LINUX_USERNAME"
  check_status
fi

# Add user to sudoers
sudo usermod -aG sudo "$LINUX_USERNAME" >> "$LOG_FILE" 2>&1
check_status

print_section "Updating System Packages"
sudo apt-get update -y >> "$LOG_FILE" 2>&1
check_status

sudo apt-get upgrade -y >> "$LOG_FILE" 2>&1
check_status

print_section "Installing Dependencies"
# Install required packages
install_packages software-properties-common git python3-dev python3-setuptools python3-pip \
python3-venv python3-distutils mariadb-server mariadb-client libmysqlclient-dev \
redis-server xvfb libfontconfig wkhtmltopdf curl nodejs npm

# Additional dependency for production
if [ "$DEPLOYMENT_TYPE" = "production" ]; then
  install_packages nginx supervisor
fi

check_status

print_section "Configuring MariaDB"
# Secure MySQL installation
echo -e "Securing MySQL installation..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$LOG_FILE" 2>&1
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "DELETE FROM mysql.user WHERE User='';" >> "$LOG_FILE" 2>&1
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" >> "$LOG_FILE" 2>&1
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "DROP DATABASE IF EXISTS test;" >> "$LOG_FILE" 2>&1
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" >> "$LOG_FILE" 2>&1
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "FLUSH PRIVILEGES;" >> "$LOG_FILE" 2>&1

# Create MySQL user for Frappe
echo -e "Creating MySQL user for Frappe..."
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$LOG_FILE" 2>&1
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'localhost' WITH GRANT OPTION;" >> "$LOG_FILE" 2>&1
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "FLUSH PRIVILEGES;" >> "$LOG_FILE" 2>&1

# Configure MySQL
echo -e "Configuring MySQL character set..."
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "SET GLOBAL character_set_server = 'utf8mb4';" >> "$LOG_FILE" 2>&1
sudo mysql -uroot -p"$MYSQL_PASSWORD" -e "SET GLOBAL collation_server = 'utf8mb4_unicode_ci';" >> "$LOG_FILE" 2>&1

# Add configuration to my.cnf
sudo tee -a /etc/mysql/my.cnf > /dev/null <<EOF
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
innodb-file-format=barracuda
innodb-file-per-table=1
innodb-large-prefix=1

[mysql]
default-character-set = utf8mb4
EOF

sudo service mysql restart >> "$LOG_FILE" 2>&1
check_status

print_section "Installing Node.js and NVM"
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash >> "$LOG_FILE" 2>&1

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Install and use latest Node.js LTS
nvm install --lts >> "$LOG_FILE" 2>&1
nvm use --lts >> "$LOG_FILE" 2>&1
nvm alias default 'lts/*' >> "$LOG_FILE" 2>&1

# Update npm and install yarn
npm install -g npm >> "$LOG_FILE" 2>&1
npm install -g yarn >> "$LOG_FILE" 2>&1
check_status

print_section "Installing Python Dependencies"
# Install pipx for Frappe Bench
sudo apt install pipx -y >> "$LOG_FILE" 2>&1
pipx ensurepath >> "$LOG_FILE" 2>&1

# Install Frappe Bench
pipx install frappe-bench >> "$LOG_FILE" 2>&1

# Add pipx to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
check_status

print_section "Setting Up Frappe Bench"
# Initialize Frappe Bench
bench init frappe-bench --frappe-branch version-15 >> "$LOG_FILE" 2>&1
check_status

cd frappe-bench || exit

print_section "Creating New Site"
# Create new site
bench new-site "$SITE_NAME" \
--db-host localhost \
--db-root-username root \
--db-root-password "$MYSQL_PASSWORD" \
--admin-password "$ADMIN_PASSWORD" \
--install-app erpnext >> "$LOG_FILE" 2>&1
check_status

print_section "Installing ERPNext"
# Get ERPNext application
bench get-app erpnext --branch version-15 >> "$LOG_FILE" 2>&1

# Install ERPNext to site
bench install-app erpnext >> "$LOG_FILE" 2>&1
check_status

# Production specific setup
if [ "$DEPLOYMENT_TYPE" = "production" ]; then
  print_section "Setting Up Production Environment"
  
  # Enable scheduler
  bench --site "$SITE_NAME" enable-scheduler >> "$LOG_FILE" 2>&1
  
  # Disable maintenance mode
  bench --site "$SITE_NAME" set-maintenance-mode off >> "$LOG_FILE" 2>&1
  
  # Setup production config
  sudo bench setup production "$LINUX_USERNAME" >> "$LOG_FILE" 2>&1
  
  # Setup NGINX
  bench setup nginx >> "$LOG_FILE" 2>&1
  
  # Restart services
  sudo supervisorctl restart all >> "$LOG_FILE" 2>&1
  sudo bench setup production "$LINUX_USERNAME" >> "$LOG_FILE" 2>&1
  
  # Open firewall ports
  sudo ufw allow 22,25,143,80,443,3306,3022,8000/tcp >> "$LOG_FILE" 2>&1
  sudo ufw enable >> "$LOG_FILE" 2>&1
  
  check_status
else
  print_section "Setting Up Development Environment"
  echo -e "To start the development server, run:"
  echo -e "cd frappe-bench && bench start"
fi

print_section "Installation Complete"
echo -e "${GREEN}ERPNext has been successfully installed!${NC}"
echo -e ""
echo -e "${YELLOW}Installation Details:${NC}"
echo -e "Site URL: http://$SITE_NAME"
echo -e "Administrator Username: Administrator"
echo -e "Administrator Password: $ADMIN_PASSWORD"
echo -e "MySQL Username: $MYSQL_USER"
echo -e "MySQL Password: $MYSQL_PASSWORD"
echo -e "Deployment Type: $DEPLOYMENT_TYPE"
echo -e "Installation Log: $LOG_FILE"
echo -e ""
echo -e "${YELLOW}Next Steps:${NC}"
if [ "$DEPLOYMENT_TYPE" = "production" ]; then
  echo -e "1. Set up your DNS to point your domain to this server"
  echo -e "2. Set up SSL using: bench setup add-domain [your-domain] && bench setup ssl-certificate"
  echo -e "3. Configure your firewall settings if needed"
else
  echo -e "1. Navigate to the frappe-bench directory: cd frappe-bench"
  echo -e "2. Start the development server: bench start"
  echo -e "3. Access your site at http://$SITE_NAME:8000"
fi
echo -e ""
echo -e "${YELLOW}For troubleshooting, refer to:${NC}"
echo -e "Official documentation: https://docs.frappe.io/erpnext"
echo -e "Community forum: https://discuss.frappe.io"
echo -e "GitHub repository: https://github.com/frappe/erpnext"

# Save credentials to file
CREDENTIALS_FILE="erpnext_credentials_$SITE_NAME.txt"
tee "$CREDENTIALS_FILE" > /dev/null <<EOF
ERPNext Installation Credentials
Generated on: $(date)

Site URL: http://$SITE_NAME
Administrator Username: Administrator
Administrator Password: $ADMIN_PASSWORD
MySQL Root Password: $MYSQL_PASSWORD
MySQL User: $MYSQL_USER
MySQL Password: $MYSQL_PASSWORD
Deployment Type: $DEPLOYMENT_TYPE

EOF

echo -e "${YELLOW}Credentials have been saved to: $CREDENTIALS_FILE${NC}"
echo -e "${RED}Please store this file in a secure location!${NC}"