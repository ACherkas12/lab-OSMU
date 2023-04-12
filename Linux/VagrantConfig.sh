Vagrant.configure("2") do |config|
  
  config.vm.define "node1" do |node1|
    node1.vm.box = "ubuntu/bionic64"
    node1.vm.provider :virtualbox do |vb|
      vb.name = "node1-Docker"
      vb.cpus = 1
      vb.memory = "2048"
    end

    node1.vm.network "private_network",
        ip: "192.168.56.10",
        netmask: "24"

    ('c'..'f').each do |char|
      node1.vm.disk :disk, size: "2GB", name: "disk-#{char}"
    end

    node1.vm.provision "Shell", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
      apt-get update
      apt-get install -yq lvm2 
      apt-get install -yq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
      mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update
      apt-get install -yq docker-ce docker-ce-cli containerd.io docker-compose-plugin thin-provisioning-tools
      #docker run hello-world
      SHELL
      sh.inline = shell
      sh.privileged = true
    end
    
    node1.vm.provision "Disks partitioning", type: "shell", run: "always" do |sh|
      shell = ""
      ('c'..'f').each do |char|
        str = <<-STR
        # echo "== Setting up disk-#{char}"
        parted /dev/sd#{char} mktable gpt > /dev/null
        parted /dev/sd#{char} mkpart primary 0% 100% > /dev/null
        # sleep 2
        # mkfs.ext4 /dev/sd#{char}1 > /dev/null
        # mkdir -p /mt/sd#{char}1
        # mount -t auto /dev/sd#{char}1 /mt/sd#{char}1
        STR
        shell += str
      end
      sh.inline = shell
      sh.privileged = true
    end

    node1.vm.provision "Configuring LVM PVs", type: "shell", run: "always" do |sh|
      shell = <<-SHELL
      systemctl stop docker
      {{pvs_creation}}
      vgcreate docker {{pvs_enum}}
      lvcreate --wipesignatures y -n thinpool docker -l 95%VG
      lvcreate --wipesignatures y -n thinpoolmeta docker -l 1%VG
      lvconvert -y \
        --zero n \
        -c 512K \
        --thinpool docker/thinpool \
        --poolmetadata docker/thinpoolmeta
      
      cat #{$synced_files_path}/docker-thinpool.profile > /etc/lvm/profile/docker-thinpool.profile
      chown :docker /etc/docker/daemon.json
      lvchange --metadataprofile docker-thinpool docker/thinpool
      cat #{$synced_files_path}/daemon.json > /etc/docker/daemon.json
      chown :docker /etc/docker/daemon.json
      
      systemctl start docker
      SHELL
      
      pvs_creation = ""
      pvs_enum = ""
      
      ('c'..'e').each do |char|
        str = "pvcreate -y /dev/sd#{char}1\n"
        pvs_creation += str
        pvs_enum += "/dev/sd#{char}1 "
      end
      
      shell["{{pvs_creation}}"] = pvs_creation
      shell["{{pvs_enum}}"] = pvs_enum

      sh.inline = shell
      sh.privileged = true
    end

    node1.vm.provision "Replace one of the disks by another", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        pvcreate /dev/sdf1
        vgextend docker /dev/sdf1
        pvmove /dev/sdd1 /dev/sdf1
        vgreduce docker /dev/sdd1
        pvremove /dev/sdd1
      SHELL
      sh.inline = shell
      sh.privileged = true
    end

    node1.vm.provision "Install and configure NTP", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        apt-get install -yq chrony
        systemctl enable chrony.service
        cat #{$synced_files_path}/slave-chrony.conf > /etc/chrony/chrony.conf
        systemctl restart chrony
        timedatectl set-timezone Europe/Minsk
        timedatectl set-ntp true
        systemctl restart systemd-timedated.service
        systemctl restart chrony
        echo "== END =="
      SHELL
      sh.inline = shell
      sh.privileged = true
    end
  end


  config.vm.define "node2" do |node2|
    node2.vm.box = "debian/buster64"
    node2.vm.provider :virtualbox do |vb|
      vb.name = "node2-RAID-arrays"
      vb.cpus = 1
      vb.memory = "2048"
    end

    node2.vm.network "private_network",
      ip: "192.168.56.11",
      netmask: "24"

    ('b'..'f').each do |char|
      node2.vm.disk :disk, size: "2GB", name: "disk-#{char}"
    end

    node2.vm.provision "Install all necessary packets", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        apt-get update -q
        apt-get install -yq parted mdadm
      SHELL
      sh.inline = shell
      sh.privileged = true
    end

    node2.vm.provision "Configure RAID 0 array", type: "shell", run: "once" do |sh|
      shell = ""

      ('b'..'c').each do |char|
        str = <<-STR
        # echo "== Setting up disk-#{char}"
        parted /dev/sd#{char} mktable gpt > /dev/null
        parted /dev/sd#{char} mkpart primary 0% 100% > /dev/null
        parted /dev/sd#{char} set 1 raid on
        STR
        shell += str
      end

      shell += <<-SHELL
        sleep 2
        mdadm --create /dev/md0 --force --level=stripe --raid-devices=2 /dev/sd[b-c]1
        mkfs.ext4 /dev/md0 > /dev/null
        mkdir -p /mnt/md0
        mount -t auto /dev/md0 /mnt/md0
      SHELL

      sh.inline = shell
      sh.privileged = true
    end
    node2.vm.provision "Configure RAID 1 array", type: "shell", run: "once" do |sh|
      shell = ""

      ('d'..'f').each do |char|
        str = <<-STR
        # echo "== Setting up disk-#{char}"
        parted /dev/sd#{char} mktable gpt > /dev/null
        parted /dev/sd#{char} mkpart primary 0% 100% > /dev/null
        parted /dev/sd#{char} set 1 raid on
        STR
        shell += str
      end

      shell += <<-SHELL
        sleep 2
        mdadm --create /dev/md1 --force --metadata=1 --level=raid1 --raid-devices=2 /dev/sd[d-e]1 --spare-devices=1 /dev/sdf1
        mkfs.ext4 /dev/md1 > /dev/null
        mkdir -p /mnt/md1
        mount -t auto /dev/md1 /mnt/md1
      SHELL
      sh.inline = shell
      sh.privileged = true
    end
    node2.vm.provision "Save RAID arrays configuration", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        mdadm --detail --scan | tee -a /etc/mdadm/mdadm.conf
        update-initramfs -u
        echo "/dev/md0 /mnt/md0 ext4 defaults 0 0" >> /etc/fstab
        echo "/dev/md1 /mnt/md1 ext4 defaults 0 0" >> /etc/fstab
        mount -a
      SHELL
      sh.inline = shell
      sh.privileged = true
    end
    node2.vm.provision "Imitate disk failure in RAID1 array", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        # Check for disk arrays status
        cat /proc/mdstat
        # Imitate a disk failure
        echo "== sde1 disk failure imitation"
        mdadm --manage /dev/md1 --fail /dev/sde1
        
        # RAID 1 recovery monitoring
        cat /proc/mdstat
        sleep 2
        cat /proc/mdstat
        sleep 5
        cat /proc/mdstat
        sleep 5
        cat /proc/mdstat
      SHELL
      sh.inline = shell
      sh.privileged = true
    end
    
    node2.vm.provision "User and group management.", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        echo "vagrant ALL = NOPASSWD: /bin/systemctl" >> /etc/sudoers.d/vagrant
        groupadd daemon-tamers
        echo "%daemon-tamers ALL = NOPASSWD: /bin/systemctl * *, /usr/bin/service * *" >> /etc/sudoers.d/daemon-tamers
        groupadd testers
        useradd -m --shell /bin/bash user1
        usermod -aG daemon-tamers user1
        
        useradd -m --shell /bin/bash user2
        usermod -aG testers user2
        groupdel testers
        echo "user2 ALL = NOPASSWD: /bin/systemctl restart *" >> /etc/sudoers.d/user2
      SHELL
      sh.inline = shell
      sh.privileged = true
    end

    node2.vm.provision "Install and configure NTP", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        apt-get install -yq chrony
        systemctl enable chrony.service
        cat #{$synced_files_path}/master-chrony.conf > /etc/chrony/chrony.conf
        systemctl restart chrony
        timedatectl set-timezone Europe/Minsk
        timedatectl set-ntp true
        systemctl restart systemd-timedated.service
        systemctl restart chrony
      SHELL
      sh.inline = shell
      sh.privileged = true
    end

    node2.vm.provision "Install and configure ruby-application", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        sudo apt update
        sudo apt-get install -yq git curl libssl-dev libreadline-dev \
          zlib1g-dev autoconf bison build-essential libyaml-dev \
          libreadline-dev libncurses5-dev libffi-dev libgdbm-dev \
          libpq-dev gcc make nodejs libsqlite3-dev
        git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
        git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(rbenv init -)"' >> ~/.bashrc
        . ~/.bashrc
        sudo -H -u vagrant bash -i -c 'rbenv install 2.6.0'
        sudo -H -u vagrant bash -i -c 'rbenv global 2.6.0'
        sudo -H -u vagrant bash -i -c 'gem install bundle'
        git clone https://github.com/lwwwr/sample_app.git
        cd sample_app
        mkdir tmp/pids
        sudo -H -u vagrant bash -i -c 'bundle install'
        sudo -H -u vagrant bash -i -c 'rails db:migrate'
        sudo -H -u vagrant bash -i -c 'rails db:seed'
      SHELL
      sh.inline = shell
      sh.privileged = false
    end
    node2.vm.provision "Set a service-file for rubyapp", type: "shell", run: "once" do |sh|
      shell = <<-SHELL
        mkdir /var/log/rubyapp
        chmod 664 /var/log/rubyapp
        cat #{$synced_files_path}/rubyapp.service > /run/systemd/system/rubyapp.service
        systemctl start rubyapp.service
      SHELL
      sh.inline = shell
      sh.privileged = true
    end
  end
end