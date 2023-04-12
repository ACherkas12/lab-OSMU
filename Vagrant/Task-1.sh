Vagrant.configure("2") do |config|

  config.vm.box = "centos/7"

  config.vm.network "forwarded_port", guest: 80, host: 8080

  config.vm.network "private_network", ip: "192.168.33.10"

   config.vm.provider "virtualbox" do |vb|
     vb.gui = false
     
     vb.name = "VagrantVM"
  
     vb.memory = "1024"
     
     vb.cpus = 1
   end
   
   config.vm.hostname = "centos"

    config.vm.provision "shell", inline: <<-SHELL
        sudo yum install -y epel-release
        sudo yum install -y nginx
        sudo systemctl start nginx
        sudo systemctl status nginx
        
        echo Visit http://localhost:8080/test and get 404 code error. Well done!
    SHELL
end