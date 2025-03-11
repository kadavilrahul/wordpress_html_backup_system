#!/bin/bash

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Update package lists
apt-get update -y

# Install Apache2
apt-get install -y apache2

# Install MySQL Server with a pre-set root password
debconf-set-selections <<< 'mysql-server mysql-server/root_password password Karimpadam2@'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password Karimpadam2@'
apt-get install -y mysql-server

# Install PHP and common extensions
apt-get install -y php libapache2-mod-php php-mysql php-cli php-common php-mbstring php-gd php-intl php-xml php-curl php-zip

# Configure Apache to prioritize PHP files
sed -i 's/index.html/index.php/' /etc/apache2/mods-enabled/dir.conf

# Enable Apache modules
a2enmod rewrite

# Start MySQL service to ensure it's running
systemctl start mysql

# Secure MySQL installation with explicit password setting
mysqladmin -u root password 'Karimpadam2@'

# Additional MySQL secure installation steps
mysql -u root -pKarimpadam2@ <<MYSQL_SCRIPT
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Create a test PHP info file
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# Restart services
systemctl restart apache2
systemctl restart mysql

# Print completion message
echo "LAMP stack installed successfully!"
echo "MySQL root password is set to: Karimpadam2@"
echo "PHP info page is available at: http://IPaddress/info.php"
echo "test commands sudo systemctl status apache2, mysql --version, php --version"
