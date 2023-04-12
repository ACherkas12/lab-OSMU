# -*- mode: ruby -*-
# vi: set ft=ruby :

VIRTUAL_MACHINE1_PRIVATE_NETWORK_IP = "192.168.4.10"
VIRTUAL_MACHINE2_PRIVATE_NETWORK_IP = "192.168.4.11"


Vagrant.configure("2") do |config|
  config.vm.define "vm1" do |vm1|
    vm1.vm.box = "bento/ubuntu-20.04"
    vm1.vm.network "private_network", ip: "#{VIRTUAL_MACHINE1_PRIVATE_NETWORK_IP}"
	vm1.vm.hostname = "ikazak-vm1"
	vm1.vm.network :public_network, :dev => "eth1"
	vm1.vm.provision "shell", path: "script.sh"
  end

  config.vm.define "vm2" do |vm2|
    vm2.vm.box = "bento/ubuntu-20.04"
    vm2.vm.network "private_network", ip: "#{VIRTUAL_MACHINE2_PRIVATE_NETWORK_IP}"
	vm2.vm.hostname = "ikazak-vm2"
	vm2.vm.network :public_network, :dev => "eth1"
	vm2.vm.provision "shell", path: "script.sh"
  end
end

