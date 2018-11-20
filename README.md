# ICP-Automation
Automation script for ICp


## ICP Latest

~~~
1. Logon to boot node
2. Copy InstallICP_3_1_0_multinode_on_VM.sh to boot node
3. InstallICP_3_1_0_multinode_on_VM.sh <boot node password> <artifactory server> <artifactory server user id> <artifactory API>
~~~

## ICP 2.x

~~~
1. Logon to boot node
2. Copy InstallICP_Multinode_on_VM.sh to boot node
3. InstallICP_Multinode_on_VM.sh <boot node password>
~~~

## Create VM using script

### Set locale

~~~
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
sudo dpkg-reconfigure locales
~~~

### Install required python packages for Python 2

~~~
apt install python-pip
apt install libssl-dev
pip install paramiko
python create_fyre_cluster.py --user=<your fyre account> --key=<your fyre api key> --cluster=<your cluster name> --icp-base --os-name=Ubuntu --os-version=18.04 --9-nodes 
~~~
