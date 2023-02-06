echo "Starting..." >> startup.log
echo "Updating yum..." >> startup.log
sudo yum update -y
echo "Updated yum." >> startup.log
echo "Installing docker..." >> startup.log
sudo yum install docker -y
echo "Docker installed." >> startup.log
echo "--------------------------------------"
echo "Starting postgres container..." >> startup.log
sudo docker run -p 5432:5432 --name postgres -e POSTGRES_PASSWORD=pg2Test! -d docker.io/library/postgres:latest
echo "Started postgres container in the background." >> startup.log
echo "Done..." >> startup.log