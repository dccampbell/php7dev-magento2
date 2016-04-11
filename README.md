# Vagrant Box for Magento2 on PHP7

A preconfigured [Vagrant box](https://atlas.hashicorp.com/rasmus/boxes/php7dev) 
for testing [Magento2](https://github.com/magento/magento2) 
on [PHP7](http://php7-tutorial.com/), via nginx/PHP-FPM server in Debian8.

Status: **Abandoned** (Recommended: [paliarush/magento2-vagrant-for-developers](https://github.com/paliarush/magento2-vagrant-for-developers))

## Prerequisites
* [Vagrant](https://www.vagrantup.com/)  
* [VirtualBox](https://www.virtualbox.org/)  
* [VirtualBox Extension Pack](https://www.virtualbox.org/wiki/Downloads)  

## Installation
1. `vagrant up`  
2. Add to [hosts file](http://www.howtogeek.com/howto/27350/beginner-geek-how-to-edit-your-hosts-file/): `192.168.7.2 magento2.local`  
3. Done! Visit [http://magento2.local/]() in your browser or run `vagrant ssh` to get started!

## Configuration
* `Vagrantfile` for VM settings
* `magento2.conf` for nginx configuration 
* `magento2-vars.sh` for Magento2 variables
