echo "Setup repository..." >> startup.log
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
echo "Repository Setup." >> startup.log
echo "--------------------------------------"
echo "Installing docker..." >> startup.log
sudo chmod a+r /etc/apt/keyrings/docker.gpg
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
echo "Docker installed." >> startup.log
echo "--------------------------------------"
echo "Starting postgres container..." >> startup.log
sudo docker run -p 5432:5432 --name postgres -e POSTGRES_PASSWORD=pg2Test! -d postgres
echo "Started postgres container in the background." >> startup.log
echo "Done..." >> startup.log