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

# Stop/Disable Existing Web Services
sudo crontab -u vagrant -r          > /dev/null 2>&1
sudo service apache2 stop           > /dev/null 2>&1
sudo update-rc.d apache2 disable    > /dev/null 2>&1
sudo service php-fpm stop           > /dev/null 2>&1
sudo service nginx stop             > /dev/null 2>&1

# Prepare Nginx & PHP-FPM
sudo rm /etc/nginx/conf.d/* 
sudo sed -i "s|www-data|vagrant|" /etc/nginx/nginx.conf
sudo sed -i "s|www-data|vagrant|" /usr/local/etc/php-fpm.d/www.conf
sudo sed "s|/var/www/magento2|$MAGE_ROOT|" /vagrant/magento2.conf | sudo tee /etc/nginx/conf.d/magento2.conf

# Configure MySQL
mysql -uroot -e "DROP DATABASE IF EXISTS $DB_NAME"
mysql -uroot -e "CREATE DATABASE $DB_NAME"
mysql -uroot -e "GRANT all privileges ON *.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'"

# Configure PHP7
sudo sed -i "s/memory_limit.*/memory_limit=1024M/"              /etc/php7/php.ini
sudo sed -i "s/memory_limit.*/memory_limit=1024M/"              /etc/php7/php-cli.ini
sudo sed -i "s/error_reporting.*/error_reporting=E_ALL/"        /etc/php7/php.ini
sudo sed -i "s/error_reporting.*/error_reporting=E_ALL/"        /etc/php7/php-cli.ini
sudo sed -i "s/max_execution_time.*/max_execution_time=600/"    /etc/php7/php.ini
sudo sed -i "s/max_execution_time.*/max_execution_time=18000/"  /etc/php7/php-cli.ini
sudo sed -i "s/opcache.enable_cli.*/opcache.enable_cli=0/"      /etc/php7/php-cli.ini
sudo sed -i -e "\$azlib.output_compression=On" -e "/zlib.output_compression.*/d" /etc/php7/php.ini

# Configure Composer
[ -z $GITHUB_TOKEN ] || sudo composer config -g github-oauth.github.com "$GITHUB_TOKEN"

echo "=== $(date): Preparing Magento2 Files... ==="

# Download Magento2
sudo rm -rf "$MAGE_ROOT"
mkdir -p "$MAGE_ROOT"
git clone -b develop https://github.com/magento/magento2.git "$MAGE_ROOT"
composer --working-dir="$MAGE_ROOT" install

# Set Permisions
fixPermissions() {
    sudo chown -R vagrant: "${1:=${MAGE_ROOT}}"
    sudo find "$1" -type d -exec chmod 770 {} \; 
    sudo find "$1" -type f -exec chmod 660 {} \; 
    sudo chmod -R u+x "$MAGE_ROOT/bin"
}
fixPermissions "$MAGE_ROOT"

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
$MAGE_EXEC cache:disable

# Install Sample Data
if [ "$INSTALL_SAMPLEDATA" == "1" ]; then
    git clone -b develop https://github.com/magento/magento2-sample-data.git "$SAMPLE_ROOT"
    fixPermissions "$SAMPLE_ROOT"
    php -f "$SAMPLE_ROOT/dev/tools/build-sample-data.php" -- --ce-source="$MAGE_ROOT"
    $MAGE_EXEC setup:upgrade
fi

# Post-Install
sed -i -e "\$aalias magento='$MAGE_EXEC'" -e "/alias magento=.*/d" /home/vagrant/.bash_aliases
$MAGE_EXEC deploy:mode:set developer
$MAGE_EXEC indexer:reindex
$MAGE_EXEC cache:enable
fixPermissions "$MAGE_ROOT"

# Start Cron
echo "*/1 * * * * php $MAGE_EXEC cron:run &" | crontab -u vagrant -

echo "=== $(date): Magento2 Setup Complete! ==="
