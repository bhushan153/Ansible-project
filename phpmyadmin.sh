#!/bin/bash

# Update the package list
sudo apt update -y

# Install MySQL Server
sudo apt install mysql-server -y

# Secure MySQL Installation
sudo mysql_secure_installation <<EOF

n
Y
Y
Y
Y
EOF


# MySQL user credentials
mysql_user="test"
mysql_password="test1234"

sudo mysql -u root <<EOF
CREATE USER '$mysql_user'@'%' IDENTIFIED BY '$mysql_password';
GRANT CREATE ON *.* TO '$mysql_user'@'%';
FLUSH PRIVILEGES;
EOF

echo "MySQL user '$mysql_user' created with password '$mysql_password' and granted all privileges."


# Install PHP and required modules
sudo apt install -y php php-fpm php-mbstring php-bcmath php-xml php-mysql php-common php-gd php-cli php-curl php-zip

# Enable PHP FPM
sudo systemctl enable php8.1-fpm --now

# Install PHPMyAdmin
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
tar xvf phpMyAdmin-*-all-languages.tar.gz
sudo mv phpMyAdmin-*/ /var/www/html/phpmyadmin
sudo mkdir -p /var/www/html/phpmyadmin/tmp
sudo cp /var/www/html/phpmyadmin/config.sample.inc.php /var/www/html/phpmyadmin/config.inc.php

# Generate blowfish_secret key
blowfish_secret=$(openssl rand -base64 32)
sudo sed -i "s|.*\$cfg\['blowfish_secret'\].*|\$cfg['blowfish_secret'] = '$blowfish_secret';|g" /var/www/html/phpmyadmin/config.inc.php

# Set TempDir in config file
echo "\$cfg['TempDir'] = '/var/www/html/phpmyadmin/tmp';" | sudo tee -a /var/www/html/phpmyadmin/config.inc.php

# Set permissions for PHPMyAdmin
sudo chown -R www-data:www-data /var/www/html/phpmyadmin
sudo find /var/www/html/phpmyadmin/ -type d -exec chmod 755 {} \;
sudo find /var/www/html/phpmyadmin/ -type f -exec chmod 644 {} \;

# Configure Apache for PHPMyAdmin
sudo tee /etc/apache2/conf-available/phpmyadmin.conf <<EOF
Alias /phpmyadmin /var/www/html/phpmyadmin

<Directory /var/www/html/phpmyadmin>
  Options Indexes FollowSymLinks
  DirectoryIndex index.php

  <IfModule mod_php8.c>
    AddType application/x-httpd-php .php

    php_flag magic_quotes_gpc Off
    php_flag track_vars On
    php_flag register_globals Off
    php_value include_path .
  </IfModule>
</Directory>

# Authorize for setup
<Directory /var/www/html/phpmyadmin/setup>
  <IfModule mod_authn_file.c>
    AuthType Basic
    AuthName "phpMyAdmin Setup"
    AuthUserFile /etc/phpmyadmin/htpasswd.setup
  </IfModule>
  Require valid-user
</Directory>

# Disallow web access to directories that don't need it
<Directory /var/www/html/phpmyadmin/libraries>
  Order Deny,Allow
  Deny from All
</Directory>
<Directory /var/www/html/phpmyadmin/setup/lib>
  Order Deny,Allow
  Deny from All
</Directory>
EOF

# Enable PHPMyAdmin configuration
sudo a2enconf phpmyadmin.conf

# Restart Apache
sudo systemctl restart apache2

echo "PHPMyAdmin and MySQL installation completed!"
