echo "192.168.4.10 ikazak-vm1" | sudo tee -a /etc/hosts
echo "192.168.4.11 ikazak-vm2" | sudo tee -a /etc/hosts
sudo systemctl restart systemd-hostnamed

sudo apt-get update
sudo apt-get install -y git
git config --global user.name "ikazak"
git config --global user.email "igorok.201367@gmail.com"
git clone https://github.com/avolnation/vagrant-lab-2
cat vagrant-lab-2/module2.txt