Vagrant.configure(2) do |config|

  config.vm.box = "rasmus/php7dev"
  config.vm.hostname = "magento2.local"
  config.vm.network "private_network", ip: "192.168.7.2"

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
    vb.memory = 1024
    vb.name = "magento2"
  end

  config.vm.provision "shell", path: "magento2.sh", privileged: false

end
