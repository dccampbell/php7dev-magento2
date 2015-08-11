#! /usr/bin/env bash

echo "=== $(date): Magento2 Setup Start! ==="

# Load Settings
source /vagrant/magento2-vars.sh
[ -z "$MAGE_ROOT" ] && echo "Error loading settings file." && exit 1
echo "Settings Loaded. Magento2 dir set to: $MAGE_ROOT"
MAGE_EXEC="$MAGE_ROOT/bin/magento"

# System Updates
sudo apt-get -q update
sudo composer self-update --no-progress
makephp 7

# Disable Apache & Prepare Nginx/PHP-FPM
sudo service apache2 stop > /dev/null 2>&1
sudo update-rc.d apache2 disable > /dev/null 2>&1
sudo service php-fpm stop > /dev/null 2>&1
sudo service nginx stop > /dev/null 2>&1

sudo rm /etc/nginx/conf.d/* 
sudo cp -f /vagrant/magento2.conf /etc/nginx/conf.d/
sudo sed -i "s:/var/www/magento2:$MAGE_ROOT:" /etc/nginx/conf.d/magento2.conf
sudo sed -i "s/www-data/vagrant/" /usr/local/etc/php-fpm.d/www.conf
sudo sed -i "s/www-data/vagrant/" /etc/nginx/nginx.conf

# Configure MySQL
mysql -uroot -e "DROP DATABASE IF EXISTS $DB_NAME"
mysql -uroot -e "CREATE DATABASE $DB_NAME"
mysql -uroot -e "GRANT all privileges ON *.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'"

# Configure PHP7
sudo sed -i "s/error_reporting.*/error_reporting=E_ALL/"       /etc/php7/php.ini
sudo sed -i "s/error_reporting.*/error_reporting=E_ALL/"       /etc/php7/php-cli.ini
sudo sed -i "s/max_execution_time.*/max_execution_time=600/"   /etc/php7/php.ini
sudo sed -i "s/max_execution_time.*/max_execution_time=18000/" /etc/php7/php-cli.ini
sudo sed -i -e "\$azlib.output_compression=On" -e "/zlib.output_compression.*/d" /etc/php7/php.ini

echo "=== $(date): Preparing Magento2 Files... ==="

# Download Magento2
shopt -s dotglob
mkdir -p $MAGE_ROOT
sudo rm -rf $MAGE_ROOT/* #$MAGE_ROOT/.[^.] $MAGE_ROOT/.??*
echo "Downloading Magento2 files..."
curl -sL "https://github.com/magento/magento2/archive/$GIT_BRANCH.zip" -o /tmp/magento2.zip
echo "Unpacking Magento2 files..."
unzip -q /tmp/magento2.zip -d /tmp/magento2 && rm -rf /tmp/magento2.zip
mv /tmp/magento2/magento2-$GIT_BRANCH/* $MAGE_ROOT/ && rm -rf /tmp/magento2
shopt -u dotglob

# Composer Actions
[ -z $GITHUB_TOKEN ] || sudo composer config -g github-oauth.github.com "$GITHUB_TOKEN"
composer --working-dir="$MAGE_ROOT" config repositories.magento composer http://packages.magento.com
composer --working-dir="$MAGE_ROOT" install

# Set Permisions
sudo chown -R vagrant:vagrant "$MAGE_ROOT"
sudo find "$MAGE_ROOT" -type d -exec chmod 755 {} \; 
sudo find "$MAGE_ROOT" -type f -exec chmod 644 {} \; 
sudo chmod -R ug+x "$MAGE_ROOT/bin"

echo "=== $(date): Starting Magento2 Install... ==="

# Start Server
sudo service nginx start
sudo service php-fpm start

# Install Magento
INSTALL_CMD="$MAGE_EXEC setup:install --base-url=$MAGE_URL --backend-frontname=$MAGE_BACK \
--db-host=localhost --db-name=$DB_NAME --db-user=$DB_USER --db-password=$DB_PASS \
--admin-firstname=$ADMIN_FNAME --admin-lastname=$ADMIN_LNAME --admin-email=$ADMIN_EMAIL \
--admin-user=$ADMIN_USER --admin-password=$ADMIN_PASS --language=$STORE_LNG \
--currency=$STORE_CCY --timezone=$STORE_TZ --session-save=$SESSION_SAVE --cleanup-database"
echo $INSTALL_CMD
${INSTALL_CMD}

# Install Sample Data
if [ "$INSTALL_SAMPLEDATA" == "1" ]; then
    composer --working-dir="$MAGE_ROOT" require "magento/sample-data:$SAMPLEDATA_VER"
    composer --working-dir="$MAGE_ROOT" update
    $MAGE_EXEC "setup:upgrade"
    $MAGE_EXEC "sampledata:install" "$ADMIN_USER"
fi

# Post-Install
sed -i -e "\$aalias magento='$MAGE_EXEC'" -e "/alias magento=.*/d" /home/vagrant/.bash_aliases
crontab -l 2>/dev/null | { grep -v "$MAGE_EXEC cron:run"; echo "*/1 * * * * php $MAGE_EXEC cron:run &"; } | crontab -
$MAGE_EXEC indexer:reindex

echo "=== $(date): Magento2 Setup Complete! ==="