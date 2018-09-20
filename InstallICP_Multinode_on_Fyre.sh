#PARMS:
# 1: WorkerRootPWD #
#
#
WORKERROOTPWD=$1
ICPVERSION=2.1.0.2
ICPTARFILENAME=ibm-cloud-private-x86_64-$ICPVERSION.tar.gz
TOTALIMAGECOUNT=83
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

ls -la ibm-cloud-private-x86_64-$ICPVERSION.tar.gz
if [ $? != 0  ];then
	echo "The Installsource TarGZ file is not present in the current directory $(pwd). Plese copy it there or download it via the following command: "
	echo "wget http://pokgsa.ibm.com/projects/i/icp-$ICPVERSION/ibm-cloud-private-x86_64-$ICPVERSION.tar.gz"
	echo "Download, depending on the internetspeed can take upto 3 Hours"
	exit 1
fi


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
apt-get update
apt-get install docker
apt install -y docker.io



systemctl start docker
systemctl enable docker


# install ICP
imagecount=$(docker images | wc -l)

if [ $imagecount != $TOTALIMAGECOUNT ];then
	echo "#### Docker load - importing Docker images ####"
	tar xf $ICPTARFILENAME -O | sudo docker load
else
	echo "Docker load will be skipped because there are already $TOTALIMAGECOUNT images imported"
fi

echo "#### Docker run - extracting ConfigFiles ####"
mkdir /opt/ibm-cloud-private-$ICPVERSION
cd /opt/ibm-cloud-private-$ICPVERSION
#sudo docker run -v $(pwd):/data -e LICENSE=accept ibmcom/icp-inception:2.1.0-ee cp -r cluster /data
sudo docker run -v $(pwd):/data -e LICENSE=accept ibmcom/icp-inception:$ICPVERSION-ee cp -r cluster /data

cd /opt/ibm-cloud-private-$ICPVERSION/cluster/

echo "Creating SSH Keys"
rm -f ~/.ssh/master.id_rsa
ssh-keygen -b 4096 -t rsa -f ~/.ssh/master.id_rsa -N ""
sudo mkdir -p /root/.ssh
cat ~/.ssh/master.id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys
/bin/cp -f ~/.ssh/master.id_rsa /opt/ibm-cloud-private-$ICPVERSION/cluster/ssh_key
cat ~/.ssh/master.id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys ;echo "PermitRootLogin yes" | sudo tee -a /etc/ssh/sshd_config
SSHPRIAVEKEY=$(cat ~/.ssh/master.id_rsa.pub)

## Create SetSudoersScript
SETSUDOERSSCRIPTPATH="/root/checkAndSetSudoers.sh"
echo "grep '$INSTALLUSER     ALL=(ALL)       ALL' /etc/sudoers 1>/dev/null" > $SETSUDOERSSCRIPTPATH
echo 'if [ $? -eq 1 ]; then' >> $SETSUDOERSSCRIPTPATH
echo "        echo '$INSTALLUSER     ALL=(ALL)       ALL' >> /etc/sudoers" >>$SETSUDOERSSCRIPTPATH
echo "fi" >> $SETSUDOERSSCRIPTPATH

chmod +x $SETSUDOERSSCRIPTPATH


#Get HostnameBase
WORKERIPS=''
echo "#### Get WorkerIPs via Hostname convention  ####"
rm -f /tmp/WorkerIPS
HOSTNAMEBASE=$(hostname | awk -F . '{print $1}'); HOSTNAMEBASE=${HOSTNAMEBASE: : -1};echo "HostnameBase: "$HOSTNAMEBASE
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
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP mkdir -p /home/$INSTALLUSER/.ssh
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP "touch /home/$INSTALLUSER/.ssh/authorized_keys; echo ${SSHPRIAVEKEY} >> /home/$INSTALLUSER/.ssh/authorized_keys"
				ssh -o StrictHostKeyChecking=no $WORKERIPSTMP < $SETSUDOERSSCRIPTPATH
				
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
echo -e calico_ipip_enabled: true >> config.yaml

echo "#### Copy Installsources ####"
mkdir -p /opt/ibm-cloud-private-$ICPVERSION/cluster/images
#ln -sf /root/ibm-cloud-private-x86_64-$ICPVERSION.tar.gz /opt/ibm-cloud-private-$ICPVERSION/cluster/images/ibm-cloud-private-x86_64-$ICPVERSION.tar.gz
cp -u /root/$ICPTARFILENAME /opt/ibm-cloud-private-$ICPVERSION/cluster/images/
#docker save ibmcom/kubernetes > kube.tar
#copy and import kube.tar into all worker

echo "#### Starting ICP installation: ####"
cd /opt/ibm-cloud-private-$ICPVERSION/cluster
#docker run --net=host -t -e LICENSE=accept -v $(pwd):/installer/cluster ibmcom/icp-inception:2.1.0-ee install
docker run --net=host -t -e LICENSE=accept -v $(pwd):/installer/cluster ibmcom/icp-inception:$ICPVERSION-ee install -vvv | tee install_$ICPVERSION.log 2>&1

echo "#### Download and install BX-CLI: ####"
wget https://clis.ng.bluemix.net/download/bluemix-cli/0.6.1/linux64
mv ./linux64 bx.tar.gz
tar -xvf bx.tar.gz
cd Blue*
./install_bluemix_cli

echo "#### Configure and install ICP-CLI: ####"
cd ..
wget https://$accessip:8443/api/cli/icp-linux-amd64 --no-check-certificate
rm -rf /root/.bluemix/plugins/icp
bx plugin install ./icp-linux-amd64

export PATH=$PATH:/usr/local/Bluemix/bin
echo -e "export PATH=$PATH:/usr/local/Bluemix/bin" >> /root/.bashrc


bx pr login -u admin -p admin -a https://$accessip:8443 --skip-ssl-validation << EOF
1
bx pr init
EOF

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
mv kubectl /usr/local/bin
chmod +x /usr/local/bin/kubectl

echo $(date) >> /tmp/InstallTime

