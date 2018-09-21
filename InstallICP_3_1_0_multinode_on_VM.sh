#PARMS:
# 1: WorkerRootPWD #
#
#
WORKERROOTPWD=$1
ARTIFACTORY_SERVER=$2
ARTIFACTORY_USER_ID=$3
ARTIFACTORY_API_KEY=$4
ICPIMAGENAME=icp-inception
ICPVERSION=3.1.0
MAXWORKERNUMBER=10
WORKERNODEIPTEMPFILE="/tmp/WorkerIPS"
SETSUDOERSSCRIPTPATH="/root/checkAndSetSudoers.sh"
INSTALLUSER=ibm
echo $(date) > /tmp/InstallTime
if [ -z $WORKERROOTPWD ];then
	INSTALLUSERPWD="IBMicpDem0s"
else
	INSTALLUSERPWD=$WORKERROOTPWD
fi
echo "INSTALLUSERPWD=$INSTALLUSERPWD"


## Prepare Nodes:
echo "#### Prepare Nodes ####"
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | tee -a /etc/sysctl.conf


## create user ibm
useradd -m -s /bin/bash $INSTALLUSER
echo $INSTALLUSER:$INSTALLUSERPWD | chpasswd
grep "$INSTALLUSER     ALL=(ALL)       ALL" /etc/sudoers 1>/dev/null
if [ $? -eq 1 ]; then
        echo "$INSTALLUSER     ALL=(ALL)       ALL" >> /etc/sudoers
fi

## Install Docker 
echo "#### Install Docker ####"
sudo apt-get update
sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get -y install docker-ce
systemctl start docker
systemctl enable docker


# install ICP
echo "#### Docker login and pull $ICPIMAGENAME:$ICPVERSION ####"
docker login -u $ARTIFACTORY_USER_ID -p $ARTIFACTORY_API_KEY $ARTIFACTORY_SERVER
docker pull $ARTIFACTORY_SERVER/ibmcom-amd64/$ICPIMAGENAME:$ICPVERSION

docker images | grep "$ICPIMAGENAME" | grep "$ICPVERSION"
if [ $? != 0  ];then
	echo "The ICp docker image is not present. Plese pull it via the following command: "
        echo "docker pull $ARTIFACTORY_SERVER/ibmcom-amd64/$ICPIMAGENAME:$ICPVERSION"
	echo "Download, depending on the internetspeed can take upto 3 Hours"
	exit 1
fi

echo "#### Docker run - extracting ConfigFiles ####"
mkdir /opt/ibm-cloud-private-$ICPVERSION
cd /opt/ibm-cloud-private-$ICPVERSION
sudo docker run --rm -v $(pwd):/data -e LICENSE=accept $ARTIFACTORY_SERVER/ibmcom-amd64/$ICPIMAGENAME:$ICPVERSION cp -r cluster /data

cd /opt/ibm-cloud-private-$ICPVERSION/cluster/

echo "Creating SSH Keys"
rm -f ~/.ssh/master.id_rsa
ssh-keygen -b 4096 -t rsa -f ~/.ssh/master.id_rsa -N ""
sudo mkdir -p /root/.ssh
cat ~/.ssh/master.id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys
/bin/cp -f ~/.ssh/master.id_rsa /opt/ibm-cloud-private-$ICPVERSION/cluster/ssh_key
echo "PermitRootLogin yes" | sudo tee -a /etc/ssh/sshd_config
SSHPRIAVEKEY=$(cat ~/.ssh/master.id_rsa.pub)

## Create SetSudoersScript
SETSUDOERSSCRIPTPATH="/root/checkAndSetSudoers.sh"
echo "grep '$INSTALLUSER     ALL=(ALL)       ALL' /etc/sudoers 1>/dev/null" > $SETSUDOERSSCRIPTPATH
echo 'if [ $? -eq 1 ]; then' >> $SETSUDOERSSCRIPTPATH
echo "        echo '$INSTALLUSER     ALL=(ALL)       ALL' >> /etc/sudoers" >>$SETSUDOERSSCRIPTPATH
echo "fi" >> $SETSUDOERSSCRIPTPATH

chmod +x $SETSUDOERSSCRIPTPATH

ln -s /usr/bin/python3 /usr/bin/python

#Get HostnameBase
WORKERIPS=''
echo "#### Get WorkerIPs via Hostname convention  ####"
rm -f $WORKERNODEIPTEMPFILE
HOSTNAMEBASE=$(hostname | awk -F . '{print $1}'); HOSTNAMEBASE=${HOSTNAMEBASE: : -1};echo "HostnameBase: "$HOSTNAMEBASE

if [[ $HOSTNAMEBASE = *"-master-"* ]]; then 
  HOSTNAMEBASE=$(echo $HOSTNAMEBASE | awk -F '-' '{print $1}') ;  
  declare -a NODETYPE=("master" "worker" "storage") 
  for n in "${NODETYPE[@]}"; do
    if [[ $n = "master" ]]; then
      for i in {2..10}; do
        WORKERIPSTMP=$(nslookup $HOSTNAMEBASE-$n-$i|grep Address | grep -v '#'| awk '{print $2}')
        if [ "$WORKERIPSTMP" != "" ]; then
                echo $WORKERIPSTMP >> $WORKERNODEIPTEMPFILE
				##Create ibm user on each Worker:
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "useradd -m -s /bin/bash $INSTALLUSER"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "chown $INSTALLUSER: /home/$INSTALLUSER"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "echo $INSTALLUSER:$INSTALLUSERPWD | chpasswd"
				#ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "echo '$INSTALLUSER     ALL=(ALL)       ALL' >> /etc/sudoers"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "mkdir -p /home/$INSTALLUSER/.ssh"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "touch /home/$INSTALLUSER/.ssh/authorized_keys; echo ${SSHPRIAVEKEY} >> /home/$INSTALLUSER/.ssh/authorized_keys"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP < $SETSUDOERSSCRIPTPATH
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "ln -s /usr/bin/python3 /usr/bin/python"
                                
				
        fi
      done
    else 
      for i in {1..10}; do
        WORKERIPSTMP=$(nslookup $HOSTNAMEBASE-$n-$i|grep Address | grep -v '#'| awk '{print $2}')
        if [ "$WORKERIPSTMP" != "" ]; then
                echo $WORKERIPSTMP >> $WORKERNODEIPTEMPFILE
				##Create ibm user on each Worker:
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "useradd -m -s /bin/bash $INSTALLUSER"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "chown $INSTALLUSER: /home/$INSTALLUSER"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "echo $INSTALLUSER:$INSTALLUSERPWD | chpasswd"
				#ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "echo '$INSTALLUSER     ALL=(ALL)       ALL' >> /etc/sudoers"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "mkdir -p /home/$INSTALLUSER/.ssh"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "touch /home/$INSTALLUSER/.ssh/authorized_keys; echo ${SSHPRIAVEKEY} >> /home/$INSTALLUSER/.ssh/authorized_keys"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP < $SETSUDOERSSCRIPTPATH
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "ln -s /usr/bin/python3 /usr/bin/python"
                                
				
        fi
      done
    fi
  done

else
  for i in {2..10}; do
        #nslookup $HOSTNAMEBASE$i|grep Address | grep -v '#'| awk '{print $2}' > /tmp/WorkerIPS
        WORKERIPSTMP=$(nslookup $HOSTNAMEBASE$i|grep Address | grep -v '#'| awk '{print $2}')
        if [ "$WORKERIPSTMP" != "" ]; then
                echo $WORKERIPSTMP >> $WORKERNODEIPTEMPFILE
				##Create ibm user on each Worker:
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "useradd -m -s /bin/bash $INSTALLUSER"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "chown $INSTALLUSER: /home/$INSTALLUSER"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "echo $INSTALLUSER:$INSTALLUSERPWD | chpasswd"
				#ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "echo '$INSTALLUSER     ALL=(ALL)       ALL' >> /etc/sudoers"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "mkdir -p /home/$INSTALLUSER/.ssh"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "touch /home/$INSTALLUSER/.ssh/authorized_keys; echo ${SSHPRIAVEKEY} >> /home/$INSTALLUSER/.ssh/authorized_keys"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP < $SETSUDOERSSCRIPTPATH
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "ln -s /usr/bin/python3 /usr/bin/python"
                                
				
        fi
done
echo "#### cat WorkerIPS: ####"
cat $WORKERNODEIPTEMPFILE
WORKERIPS=$(cat $WORKERNODEIPTEMPFILE)


##
##	Distribute SSH key to WorkerNodes
##
##echo "#### Distributing SSH Keys ####"
##for WORKERIP in (cat $WORKERNODEIPTEMPFILE);do
	### do ssh-copy-id
	##ssh-copy-id << EOF
##yes
##$WORKERROOTPWD
##EOF
	### Not needed in Fyre Environment because ssh key already created and distributed
##done


echo "#### Creating ICP Hosts file ####"
export ip=`/sbin/ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`
if [ -z $ip ]; then
	export ip=`/sbin/ip addr show ens3 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`
fi

echo [master] > hosts
echo -e $ip ansible_ssh_port=22 >> hosts
echo -e >> hosts
echo [worker] >> hosts
if [ "$WORKERIPS" != "" ]; then
	while read line
	do
		echo $line ansible_ssh_port=22 >> hosts
	done < $WORKERNODEIPTEMPFILE 
fi
echo -e >> hosts
echo [proxy] >> hosts
echo -e $ip ansible_ssh_port=22 >> hosts
#if [ "$WORKERIPS" != "" ]; then
#	echo -e $WORKERIPS ansible_ssh_port=22 >> hosts
#fi

echo "#### Content of ICP hosts file: ####"
cat hosts

export accessip=`/sbin/ip addr show eth1 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`
if [ -z $accessip ];then
	echo "getting accessip for if ens3"
	export accessip=`/sbin/ip addr show ens7 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'`
	echo "accessip: $accessip"
fi

echo -e >> config.yaml
echo -e cluster_access_ip: $accessip >> config.yaml
echo -e >> config.yaml
echo -e ansible_user: $INSTALLUSER >> config.yaml
echo -e ansible_become: true >> config.yaml
echo -e ansible_become_password: $INSTALLUSERPWD >> config.yaml
echo -e ansible_ssh_pass: $INSTALLUSERPWD >> config.yaml
# echo -e calico_ipip_enabled: true >> config.yaml
echo -e version: 3.1.0 >> config.yaml
echo -e image_repo: $ARTIFACTORY_SERVER/ibmcom-amd64 >> config.yaml
echo -e private_registry_enabled: true >> config.yaml
echo -e private_registry_server: $ARTIFACTORY_SERVER >> config.yaml
echo -e docker_username: $ARTIFACTORY_USER_ID >> config.yaml
echo -e docker_password: $ARTIFACTORY_API_KEY >> config.yaml

echo "#### Starting ICP installation: ####"
cd /opt/ibm-cloud-private-$ICPVERSION/cluster
docker run --net=host -t -e LICENSE=accept -v $(pwd):/installer/cluster $ARTIFACTORY_SERVER/ibmcom-amd64/$ICPIMAGENAME:$ICPVERSION install -vvv | tee install_$ICPVERSION.log 2>&1

echo "#### cloudctl login to ICp : ####"
cloudctl login -u admin -p admin -a https://$accessip:8443 --skip-ssl-validation << EOF
1
2
EOF

echo $(date) >> /tmp/InstallTime

