#!/usr/bin/python
#
#
import os
import sys
from os.path import expanduser
import paramiko
import time
import json
from threading import Thread

import warnings
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning

# Global variables...
main_mode = "new"
debug_mode = False
num_master = 3
num_compute = 3
num_storage = 0
num_deploy = 0
num_boot = 0
num_proxy = 0
num_virtual = 0
num_management = 0
num_worker = 0
num_lb = 0
three_node = False
mergeStorage = True
deploy_data = {}

nodeTypes = ["master", "proxy", "management", "boot", "worker", "storage", "deploy", "compute", "virtual", "lb"]

#openshift
oc = False

proxy_ip = ""
proxy_ip_from_database = False
balancer_ip = {}
deploy_os_name = "Redhat"
deploy_os_ver = "7.4"
platform = "x"
cluster_information_ip_pass = []
node_hostName = []
parted_ip_list = []
icp_base = False
one_partition = False
load_balance = False
external_access = False
conf_file = "xdp.conf"
max_cluster = False


# Docker disk
docker_partition = False
docker_partition_size = 500
add_docker_raw_disk = False

# Dictionaries for disk name depends on the platform, key x means x86_64, p means power, reference from api
IBX_DISK = {'x': '/dev/vdb', 'p': '/dev/vda'}
DATA_DISK = {'x': '/dev/vdc', 'p': '/dev/vdb'}

RAW_DISK_MASTER = {'x': '/dev/vdd', 'p': '/dev/vdc'}
RAW_DISK_WORKER_2 = {'x': '/dev/vdd', 'p': '/dev/vdc'}
RAW_DISK_WORKER = {'x': '/dev/vdc', 'p': '/dev/vdb'}

# Constants
STACK_URL = "https://api.stack.io.com/rest/v1/"
PROXY_REQUEST_URL = "http://mavin1.stack.io.com/requestStaticIP"
PROXY_GET_IP_URL = "http://mavin1.stack.io.com/requestProxyIPbyName"

DEV_CONF_FILE = "xdp_dev.conf"
SSH_KEY_FILE = expanduser("~") + "/.ssh/id_rsa.pub"
SSH_OPTS = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Disk partition script
part_disk_script_name = "dsx_part_script"
part_disk_script = """#!/bin/bash
if [[ $# -ne 2 ]]; then
    echo "Requires a disk name and mounted path name"
    echo "$(basename $0) <disk> <path>"
    exit 1
fi
set -e
parted ${1} --script mklabel gpt
parted ${1} --script mkpart primary '0%' '100%'
sleep 1
mkfs.xfs -f -n ftype=1 ${1}1
mkdir -p ${2}
echo "${1}1       ${2}              xfs     defaults,noatime    1 2" >> /etc/fstab
mount ${2}
exit 0
"""


def write_part_script(name):
    global part_disk_script_name
    part_disk_script_name = part_disk_script_name + "_" + name
    file = open(part_disk_script_name, "w")
    file.writelines(part_disk_script)
    file.close()


# Print this script usage and exit 1
def usage(msg):
    print("""
{}
Usage: {} --user=<stack_user> --key=<stack_api_key> --cluster=<cluster_name> [options]
Options:
    --num-master=n      Number of master nodes will be create, default is 3
    --num-storage=n     Number of storage nodes will be create, default is 3
    --num-compute=n     Number of compute nodes will be create, default is 3
    --num-deploy=n      Number of deploy nodes will be create, default is 0
    --9-nodes           Separate the storage and master nodes
    --os-name=os_name   Os name has to be in the list provided from https://stack.com/help#stack-api (default is RHEL)
    --os-version=x.x    Os version, this and --os-name has to come together (default is 7.4 for RHEL) 
    --3-nodes           Only create three master nodes with additional disk 1000, --num options will not take effective
    --icp-base          Creates a cluster for icp installation
    --add-raw-disk      Does the same thing as docker-raw-disk but add the raw disk to the config file   
    --one-partition     Using the same partition for data storage as the install
    --external-access   Creates xdp_dev.conf file containing master-1 public ip for installer to provide external web access
    --platform=<plat>   The platform architecture; either x for x86_64 or p for ppc64le (default is x86_64)
    --debug             Show more debug information
    --docker-raw-disk   add another disk for Device Mapper
    --oc                create a openshift cluster setup
    --load-balancer     Add load balancer node with nginx setup
""".format(msg, sys.argv[0]))
    sys.exit(1)


# Print information if debug enabled
def log(msg):
    if debug_mode:
        print(msg)


def get_proxy_ip(url, account_info):
    data_post = {
        'username': account_info[0],
        'api_key': account_info[1],
        'cluster_name': account_info[2]
    }
    try:
        r = requests.post(url, data=json.dumps(data_post))
        if r.status_code == 200:
            data = r.json()
            log("Proxy Ip found")
            return data['message']
        else:
            data = r.json()
            print (data['message'])
            log("Proxy Ip request fail")
            return None
    except:
        log("Proxy Ip request fail")
        return None


# Send request to stack and get json response
def sendRequest(query, account_info, data=None):
    auth = (account_info[0], account_info[1])
    url = STACK_URL + query
    log("Sending url: " + url)
    if (data is None):
        resp = requests.post(url, auth=auth, verify=False)
    else:
        resp = requests.post(url, data=data, auth=auth, verify=False)
    if resp.status_code != 200:
        print("Request getting non-ok code ({}): {}".format(resp.status_code, url))
        sys.exit(1)
    return resp.json()


# Validate the user arguments
def validate_args():
    account_info = ["", "", ""]
    has_set_os = 0

    if not os.path.isfile(SSH_KEY_FILE):
        print("The ssh public key file {} does not exist".format(SSH_KEY_FILE))
        sys.exit(1)

    if "--debug" in sys.argv[1:]:
        print("enabled")
        global debug_mode
        debug_mode = True

    global num_storage, mergeStorage, num_master, three_node, max_cluster,\
        one_partition, external_access, load_balance, docker_partition, \
        platform, load_balance, num_compute, num_boot, num_deploy, num_management, num_proxy, num_worker, icp_base, num_virtual, add_docker_raw_disk, num_lb, oc
    for cur_arg in sys.argv[1:]:
        if cur_arg.startswith("--user="):
            if cur_arg == "--user=":
                usage("User name cannot be empty")
            account_info[0] = cur_arg[(cur_arg.index("=") + 1):]
            log("User name is " + account_info[0])
        elif cur_arg.startswith("--key="):
            if cur_arg == "--key=":
                usage("API key cannot be empty")
            account_info[1] = cur_arg[(cur_arg.index("=") + 1):]
            log("API key is " + account_info[1])
        elif cur_arg.startswith("--max-cluster"):
            max_cluster = True
        elif cur_arg.startswith("--cluster="):
            if cur_arg == "--cluster=":
                usage("Cluster name cannot be empty")
            account_info[2] = cur_arg[(cur_arg.index("=") + 1):]
            log("Cluster name is " + account_info[2])
        elif cur_arg.startswith("--num-master="):
            num_master = validate_node_num("--num-master=", cur_arg)
            log("There will be %d master nodes" % (num_master))
        elif cur_arg.startswith("--num-storage="):
            num_storage = validate_node_num("--num-storage=", cur_arg)
            log("There will be %d storage nodes" % (num_storage))
        elif cur_arg.startswith("--num-compute="):
            num_compute = validate_node_num("--num-compute=", cur_arg)
            log("There will be %d compute nodes" % (num_compute))
        elif cur_arg.startswith("--num-deploy="):
            global num_deploy
            num_deploy = validate_node_num("--num-deploy=", cur_arg)
            log("There will be %d deploy nodes" % (num_deploy))
        elif cur_arg == "--9-nodes":
            num_storage = 3
            mergeStorage = False
            log("There will be 3 master/storage, 3 compute")
        elif cur_arg == "--icp-base":
            icp_base = True
            num_master = 3
            num_virtual = 1
            num_compute = 0
            if three_node:
                num_worker = 0
            else:
                num_worker = 3
            #docker_partition = True
            log("The cluster will be created for icp installation")
        elif cur_arg.startswith("--os-name="):
            global deploy_os_name
            deploy_os_name = cur_arg[(cur_arg.index("=") + 1):]
            log("OS will be {}".format(deploy_os_name))
            has_set_os += 1
        elif cur_arg.startswith("--os-version="):
            global deploy_os_ver
            deploy_os_ver = cur_arg[(cur_arg.index("=") + 1):]
            log("OS version will be {}".format(deploy_os_ver))
            has_set_os += 1
        elif cur_arg == "--3-nodes":
            three_node = True
            num_compute = 0
        elif cur_arg == "--external-access":
            external_access = True
        elif cur_arg == "--one-partition":
            one_partition = True
        elif cur_arg == '--docker-raw-disk':
            docker_partition = True
        elif cur_arg == '--add-raw-disk':
            docker_partition = True
            add_docker_raw_disk = True
        elif cur_arg == "--oc":
            num_compute = 0
            num_master = 3
            num_lb = 1
            num_worker = 5
            oc = True
        elif cur_arg == "--load-balancer":
            load_balance = True
        elif cur_arg.startswith("--platform="):
            platform = cur_arg[(cur_arg.index("=") + 1):]
        elif cur_arg.startswith("--debug"):
            pass
        elif cur_arg == "--reload":
            main_mode = "reload"
        else:
            usage("Unrecongized parameter '%s'" % (cur_arg))

    if has_set_os == 1:
        usage("--os-name= and --os-version= has to be appear both or none")

    for i in account_info:
        if i is None or i == "":
            usage("Missing required parameter")

    return account_info


# When user specify a number for nodes, make sure it is valid
def validate_node_num(param, user_input):
    if param == user_input:
        usage("Parameter {} needs to come with a number".format(param))
    num_str = user_input[(user_input.index("=") + 1):]
    paramStr = user_input[:(user_input.index("=") + 1)]
    try:
        my_num = int(num_str)
        if (my_num < 3 and paramStr != "--num-deploy="):
            if three_node and paramStr == "--num-compute=":
                return my_num
            usage("Parameter {} must have a value greather than or equal to 3".format(param))
        return my_num
    except ValueError:
        usage("Parameter {} has the non-interger value".format(param))


# Generate a json for reload cluster 
def get_create_json_reload(cluster_name):
    data = {
        "cluster_name" : cluster_name,
    }
    string = json.dumps(data, indent=4, separators=(',', ': '))
    log("============= Create request ==================")
    log(string)
    log("===============================================")
    return string


# Generate a json for create cluster 
def get_create_json(account_info):
    global proxy_ip_from_database, proxy_ip, icp_base, num_boot, \
        num_deploy, num_management, num_proxy, num_worker, num_master, num_storage, num_compute, num_virtual
    f = open(SSH_KEY_FILE, 'r')
    key = f.readline()
    key = key.rstrip('\n')
    f.close()

    deploy_os = "{} {}".format(deploy_os_name, deploy_os_ver)
    data = {
        "fyre": {
            "creds": {
                "username": account_info[0],
                "api_key": account_info[1],
                "public_key": key
            }
        },
        "clusterconfig": {
            "instance_type": "virtual_server",
            "platform": platform
        },
        "cluster_prefix": account_info[2],
        account_info[2]: []
    }
    nodes = []

    proxy_node = stackNodeJson(name="virtual", count=1, cpu=1, memory=1, os=deploy_os, publicvlan="n", privatevlan="y", additional_disks=[])
    proxy_ip_temp = get_proxy_ip(PROXY_REQUEST_URL, account_info)
    proxy_temp2 = ""
    if icp_base:
        proxy_temp2 = get_proxy_ip(PROXY_REQUEST_URL, account_info)
    if not proxy_ip_temp is None:
        proxy_ip_from_database = True
        proxy_ip = proxy_ip_temp
        proxy_node = None

    if not proxy_node is None:
        nodes.append(proxy_node)

    disks = {
        "master": [{"size": 600}],
        "storage": [{"size": 400}, {"size": 400}],
        "compute": [{"size": 250}],
        "deploy": [{"size": 250}],
        "boot": [{"size": 100}],
        "proxy": [{"size": 40}],
        "management": [{"size": 100}],
        "worker": [{"size": 600}],
        "virtual": [],
        "lb": [{"size": 400}, {"size": 400}]
    }
    cpu = {
        "master": 4,
        "boot": 1,
        "proxy": 1,
        "worker": 1,
        "management": 1,
        "storage": 8,
        "deploy": 8,
        "compute": 8,
        "virtual": 1,
        "lb": 16
    }
    ram = {
        "master": 24,
        "boot": 4,
        "proxy": 1,
        "worker": 4,
        "management": 8,
        "storage": 32,
        "deploy": 32,
        "compute": 32,
        "virtual": 1,
        "lb": 32

    }
    if icp_base or max_cluster:
        cpu['master'] = 16
        cpu['worker'] = 16
        cpu['compute'] = 16

        ram['master'] = 32
        ram['worker'] = 32
        ram['compute'] = 32
        if not max_cluster:
            cpu['proxy'] = 4
            ram['proxy'] = 4


    if mergeStorage:
        disks["master"] = [{"size": 500}, {"size": 400}]
    if docker_partition:
        for type, disk in disks.iteritems():
            disk.append({"size": docker_partition_size})

    for name in nodeTypes:
        if eval("num_" + name) > 0:
            for x in range(1, eval("num_" + name) + 1):
                if (oc and name == "lb") or (not oc and name == "master" and x == 1):
                    nodes.append(stackNodeJson(name=name.title() + "-1", count=1, cpu=cpu[name], memory=ram[name], os=deploy_os, publicvlan="y", privatevlan="y", additional_disks=disks[name]))
                elif name == "worker" and not three_node and icp_base and x <= 3:
                    nodes.append(
                        stackNodeJson(name=name.title() + "-" + str(x), count=1,
                                     cpu=cpu[name], memory=ram[name], os=deploy_os,
                                     publicvlan="n", privatevlan="y", additional_disks=disks[name] + [{"size": 400}]))
                else:
                    nodes.append(
                        stackNodeJson(name=name.title() + "-" + str(x), count=1, cpu=cpu[name], memory=ram[name], os=deploy_os, publicvlan="n", privatevlan="y", additional_disks=disks[name]))
    global load_balance
    if load_balance:
        nodes.append(stackNodeJson(name="balancer", count=1, cpu=2, memory=4, os=deploy_os, publicvlan="y", privatevlan="y"))
    data[account_info[2]] = nodes
    string = json.dumps(data, indent=4, separators=(',', ': '))
    log("============= Create request ==================")
    log(string)
    log("===============================================")
    return string


def stackNodeJson(name, count, cpu, memory, os, publicvlan, privatevlan, additional_disks=[]):
    m = {
        "name": name,
        "count": count,
        "cpu": cpu,
        "memory": memory,
        "os": os,
        "publicvlan": publicvlan,
        "privatevlan": privatevlan,
        "additional_disks": additional_disks
    }
    return m


# Reload
def reload_cluster(account_info):
    # Check if the cluster name is exist already
    res = sendRequest("?operation=query&request=showclusters", account_info)
    cluster_list = res.get("clusters")
    if res.has_key("status"):
        print("Unexpected result for request showclusters")
        print("=====================================================")
        print("{}: {}".format(res.get("status"), res.get("details")))
        print("=====================================================")
        sys.exit(1)
    for c_info in cluster_list:
        if (c_info.get("name") == account_info[2]):
            # if cluster in user's list, reload Cluster
            print("Find the cluster, now begin to reload")
            res = sendRequest("?operation=reload", account_info, data=get_create_json_reload(account_info[2]))
            req_id = res.get("request_id")
            print("Reload request id is {}".format(req_id))

            # Loop to check the building is done
            while True:
                res = sendRequest("?operation=query&request=showrequests&request_id=" + req_id, account_info)
                req_list = res.get("request")
                req_info = req_list[0]
                req_status = req_info.get("status")
                if req_status == "error":
                    print("Failed to create cluster due to: {}".format(req_info.get("error_details")))
                    sys.exit(1)
                elif req_status == "completed":
                    log("Completed state right now!")
                    if req_info.get("error_details") != "0":
                        print("Create completed with error: {}".format(req_info.get("error_details")))
                        sys.exit(1)
                    break
                time.sleep(5)
            res = sendRequest("?operation=query&request=showclusterdetails&cluster_name=" + account_info[2], account_info)
            if not res.has_key(account_info[2]):
                print("Invalid response when getting information for cluster {}".format(account_info[2]))
                print("=====================================================")
                print(str(res))
                print("=====================================================")
                sys.exit(1)
            print("Cluster is reloaded successfully, will reconfigure the cluster")
            return res
    print("Cluster is not in your list, abort")
    sys.exit(1)


# Create the cluster
def create_cluster(account_info):
    # Check if the cluster name is exist already
    res = sendRequest("?operation=query&request=showclusters", account_info)
    cluster_list = res.get("clusters")
    if res.has_key("status"):
        print("Unexpected result for request showclusters")
        print("=====================================================")
        print("{}: {}".format(res.get("status"), res.get("details")))
        print("=====================================================")
        sys.exit(1)
    for c_info in cluster_list:
        if (c_info.get("name") == account_info[2]):
            print("The cluster name is already exist in your account")
            sys.exit(1)
    log("The cluster name {} is valid for create".format(account_info[2]))

    # Create now
    print("Submit create VM request to stack and wait for completion")
    res = sendRequest("?operation=build", account_info, data=get_create_json(account_info))
    req_id = res.get("request_id")
    print("Create request id is {}".format(req_id))

    # Loop to check the building is done
    while True:
        res = sendRequest("?operation=query&request=showrequests&request_id=" + req_id, account_info)
        req_list = res.get("request")
        req_info = req_list[0]
        req_status = req_info.get("status")
        if req_status == "error":
            print("Failed to create cluster due to: {}".format(req_info.get("error_details")))
            sys.exit(1)
        elif req_status == "new":
            log("Still in new state")
        elif req_status == "building":
            log("Still in building state")
        elif req_status == "completed":
            log("Completed state right now!")
            if req_info.get("error_details") != "0":
                print("Create completed with error: {}".format(req_info.get("error_details")))
                sys.exit(1)
            break
        else:
            print("Unrecognized create status: {}".format(req_status))
            sys.exit(1)

        time.sleep(5)

    # Return the cluster info
    res = sendRequest("?operation=query&request=showclusterdetails&cluster_name=" + account_info[2], account_info)
    if not res.has_key(account_info[2]):
        print("Invalid response when getting information for cluster {}".format(account_info[2]))
        print("=====================================================")
        print(str(res))
        print("=====================================================")
        sys.exit(1)
    return res


# Creating the configuration file according to the stack api response
def create_file(cluster_info):
    global cluster_information_ip_pass, parted_ip_list, deploy_data, proxy_ip, node_hostName, mergeStorage
    field, clus_info = cluster_info.items()[0]
    node_hostName = []
    for l in clus_info:
        node_hostName.append(l["node"])

    global conf_file
    conf_file = "xdp." + field + ".conf"
    if os.path.exists(os.getcwd() + "/" + conf_file):
        os.remove(os.getcwd() + "/" + conf_file)
    f = open(os.getcwd() + "/" + conf_file, 'w')
    f.write("# Warning: This file generated by a script, do NOT share\n")
    if not icp_base:
        f.write("user=root\n")
    else:
        f.write("ssh_key=/root/.ssh/id_rsa\n")
    proxy_ip = get_proxy_ip(PROXY_GET_IP_URL, ["", "", field])

    virtual_exists = 0
    for line in clus_info:
        node_info = line.get("node").split("-")
        if node_info[-1] == "virtual":
            proxy_ip = line.get("privateip")
            if not icp_base:
                f.write("virtual_ip_address=%s\n" % (line.get("privateip")))

        for name in nodeTypes:
            if line.get("publicip") != "":
                deploy_data = {"ip": line.get("publicip"), "password": line.get("root_password")}
                if external_access:
                    f_dev = open(os.getcwd() + "/" + DEV_CONF_FILE, 'w')
                    f_dev.write("EXTERNAL_IP=%s\n" % (deploy_data["ip"]))
                    f_dev.close()

            if node_info[-2] == name and node_info[-2] != "virtual":
                raw_disk = RAW_DISK_WORKER[platform]
                space = "_"
                if node_info[-2] == "master":
                    raw_disk = RAW_DISK_MASTER[platform]
                    if three_node:
                        name = ""
                        space = ""

                f.write("{}{}node_{}={}\n".format(name, space, node_info[-1], line.get("privateip")))
                if icp_base:
                    if int(node_info[-1]) <= 3 and name == "worker" and not three_node:
                        f.write("{}{}node_data_{}=/data\n".format(name, space, node_info[-1]))
                        parted_ip_list.append(line.get("privateip"))
                        raw_disk = RAW_DISK_WORKER_2[platform]
                elif mergeStorage and (name == "master" or name == ""):
                    f.write("{}{}node_data_{}=/data\n".format(name, space, node_info[-1]))
                    parted_ip_list.append(line.get("privateip"))

                if add_docker_raw_disk:
                    f.write("{}{}node_docker_disk_{}={}\n".format(name, space, node_info[-1], raw_disk))

                if node_info[-2] == "storage":
                    if one_partition:
                        f.write("storage_node_data_{}=/ibx\n".format(node_info[-1]))
                    else:
                        f.write("storage_node_data_{}=/data\n".format(node_info[-1]))

                    parted_ip_list.append(line.get("privateip"))
                f.write("{}{}node_path_{}=/ibx\n".format(name, space, node_info[-1]))

                cluster_information_ip_pass.append({"ip": line.get("privateip"), "password": line.get("root_password"), "node": line.get("node")})

            elif node_info[-2] == name and node_info[-2] == "virtual":
                if not proxy_ip is None and virtual_exists == 0:
                    f.write("virtual_ip_address_1={}\n".format(proxy_ip))
                    virtual_exists += 1
                number = int(node_info[-1]) + 1
                f.write("virtual_ip_address_%s=%s\n" % (str(number), line.get("privateip")))

        if node_info[-1] == "balancer":
            f.write("load_balancer_ip_address=%s\n" % (line.get("privateip")))
            global balancer_ip
            balancer_ip = {"ip": line.get("privateip"), "password": line.get("root_password")}
    if virtual_exists == 0:
        f.write("virtual_ip_address={}\n".format(proxy_ip))
    f.write("ssh_port=22\n")
    f.write("overlay_network=9.242.0.0/16\n")
    f.write("suppress_warning=true\n")
    f.close()


# Wait for all nodes are running
def wait_all_running(account_info):
    for _ in range(60):
        res = sendRequest("?operation=query&request=showclusterdetails&cluster_name=" + account_info[2], account_info)
        if not res.has_key(account_info[2]):
            print("Invalid response when getting information for cluster {}".format(account_info[2]))
            print("=====================================================")
            print(str(res))
            print("=====================================================")
            sys.exit(1)
        cluster_info = res.get(account_info[2])

        is_all_running = True
        for line in cluster_info:
            if line.get("state") != "running" and line.get("node").find("-virtual-") == -1 and line.get("node").find("-proxy") == -1:
                is_all_running = False
                break
        if is_all_running:
            print("All nodes are on running state")
            return
        time.sleep(5)
    print("Timeout to wait for all nodes to become running state")


# Set selinux, mount directory etc
def configure_nodes(account_info):
    write_part_script(account_info[2])

    print("Configuring each node")
    threads = []
    for node_info in cluster_information_ip_pass:
        t = Thread(None, node_config, None, (deploy_data['ip'], node_info['ip'], deploy_data['password'], node_info['password'], node_info['node'], account_info))
        t.start()
        threads.append(t)

    for t in threads:
        t.join()

    if load_balance:
        client, jhost = nested_ssh(deploy_data['ip'], balancer_ip['ip'], deploy_data['password'], balancer_ip['password'])
        load_balancer(deploy_data, balancer_ip, cluster_information_ip_pass, client, jhost)

    if os.path.exists(os.getcwd() + "/part_disk.sh"):
        os.remove(os.getcwd() + "/part_disk.sh")

    print("rebooting all nodes")
    for hostname in node_hostName:
        if not hostname.endswith("-proxy") and "virtual" not in hostname:
            sendRequest("?operation=reboot&node_name={}".format(hostname), account_info)
        else:
            sendRequest("?operation=shutdown&node_name={}".format(hostname), account_info)
    print("Intended sleep 60 seconds")
    time.sleep(60)
    wait_all_running(account_info)
    os.remove(part_disk_script_name)


def node_config(src_ip, dest_ip, src_pwd, dest_pwd, hostname, account_info):
    client, jhost = nested_ssh(src_ip, dest_ip, src_pwd, dest_pwd)

    log("Copying partition script to " + dest_ip)
    ftp = jhost.open_sftp()
    f = ftp.put(part_disk_script_name, "part_disk.sh")
    if f is None:
        print("Unable to copy partition script")
        exit(1)

    cmd = [
        "yum install -y libselinux-python tmux",
        "sed -i 's/^net.ipv4.ip_forward = 0$/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf >& /dev/null",
        "sysctl -p >& /dev/null",
        "uuidgen > /etc/machine-id",
        "sed -i 's/^SELINUX=.*$/SELINUX=permissive/g' /etc/selinux/config >& /dev/null",
        "chmod +x ~/part_disk.sh; ~/part_disk.sh " + IBX_DISK[platform] + " /ibx >& /dev/null"]

    if oc:
        cmd = add_openshift_commands(cmd)
    # Commands to be executed on all the nodes
    for cur_cmd in cmd:
        log("Node {} execute command: {} ".format(dest_ip, cur_cmd))
        _, stdout, stderr = jhost.exec_command(cur_cmd)
        if stdout.channel.recv_exit_status() != 0:
            print("Node {} execute command: {}\nStatus: {}\nOutput:\n{}\nError:\n{}".format(
                dest_ip, cur_cmd, str(stdout.channel.recv_exit_status()), str(stdout.readlines()), str(stderr.readlines())))
            exit(1)

    # For the storage nodes only
    if dest_ip in parted_ip_list and not oc:
        log("Executing partition script on {} for /data".format(dest_ip))
        _, stdout, stderr = jhost.exec_command("chmod +x ~/part_disk.sh; ~/part_disk.sh " + DATA_DISK[platform] + " /data >& /dev/null")
        log("Exit status:" + str(stdout.channel.recv_exit_status()))
        log("Command output: " + str(stdout.readlines()))
        if stdout.channel.recv_exit_status() != 0:
            print("Unable to execute partition script on {}".format(dest_ip))
            exit(1)

    # Do conf file scp on master -1
    if dest_ip == cluster_information_ip_pass[0]['ip']:
        log("Scp the xdp.conf file")
        f = ftp.put(conf_file, "/ibx/xdp.conf")
        if f is None:
            print("Failed to scp the conf file, please try again by yourself")
            sys.exit(1)
        if external_access:
            f = ftp.put(DEV_CONF_FILE, "/ibx/xdp_dev.conf")
            if f is None:
                print("Failed to scp the external access conf file, please try again by yourself")
                sys.exit(1)

    if load_balance:
        load_balancer(deploy_data, balancer_ip, cluster_information_ip_pass, client, jhost)

    ftp.close()
    client.close()
    jhost.close()


def load_balancer(deploy_data, balancer_ip, cluster_information_ip_pass, client, jhost):
    log("Creating load balancer " + balancer_ip['ip'])
    wget_cmd = "wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm; yum install -y epel-release-latest-7.noarch.rpm; yum install -y nginx;"
    _, stdout, stderr = jhost.exec_command(wget_cmd)
    log("Exit status:" + str(stdout.channel.recv_exit_status()))
    if stdout.channel.recv_exit_status() != 0:
        log("Error in getting epel-release and installing nginx")
        log("Command output: " + str(stdout.readlines()))
        log("Command error: " + str(stderr.readlines()))
        exit(1)
    setup_conf_cmd = """mkdir -p /etc/nginx/tcpconf.d; 
                       echo \"stream { 
                                  upstream kubeapi { 
                                      server %s:6443; 
                                      server %s:6443; 
                                      server %s:6443;
                                  } 
                                  upstream dsxportal { 
                                      server %s:443; 
                                      server %s:443; 
                                      server %s:443;
                                  } 
                                  server { 
                                      listen     6443; 
                                      proxy_pass kubeapi;
                                  } 
                                  server {  
                                      listen     443; 
                                      proxy_pass dsxportal;
                                  }
                              }\" > /etc/nginx/tcpconf.d/load-balancer.conf;""" % (
    cluster_information_ip_pass[0]['ip'], cluster_information_ip_pass[1]['ip'], cluster_information_ip_pass[2]['ip'], cluster_information_ip_pass[0]['ip'], cluster_information_ip_pass[1]['ip'],
    cluster_information_ip_pass[2]['ip'])
    _, stdout, stderr = jhost.exec_command(setup_conf_cmd)
    log("Exit status:" + str(stdout.channel.recv_exit_status()))
    if stdout.channel.recv_exit_status() != 0:
        log("Error in setup of load-balancer.conf")
        log("Command output: " + str(stdout.readlines()))
        exit(1)
    include_conf_cmd = "sed -i '/include\ \/usr\/share\/nginx\/modules\/\*.conf/a include\ \/etc\/nginx\/tcpconf.d\/\*;' /etc/nginx/nginx.conf;"
    _, stdout, stderr = jhost.exec_command(include_conf_cmd)
    log("Exit status:" + str(stdout.channel.recv_exit_status()))
    if stdout.channel.recv_exit_status() != 0:
        log("Unable to copy the include command into nginx conf")
        log("Command output: " + str(stdout.readlines()))
        exit(1)
    start_nginx_cmd = "systemctl enable nginx; systemctl start nginx"
    _, stdout, stderr = jhost.exec_command(start_nginx_cmd)
    log("Exit status:" + str(stdout.channel.recv_exit_status()))
    if stdout.channel.recv_exit_status() != 0:
        log("Error cannot enable or start nginx")
        log("Command output: " + str(stdout.readlines()))
        exit(1)

    # Connecting to the deploy node as jump server and then ssh to the target ip


def nested_ssh(levelOneIP, levelTwoIP, passwordIP1, passwordIP2):
    for count in range(11):
        log('trying to make ssh tunnel on {} number of try {}'.format(levelTwoIP, count))
        client = paramiko.client.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(levelOneIP, username='root', password=passwordIP1)
        vmtransport = client.get_transport()
        if vmtransport.is_active():
            vmchannel = vmtransport.open_channel("direct-tcpip", (levelTwoIP, 22), (levelOneIP, 22))
            jhost = paramiko.SSHClient()
            jhost.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            jhost.connect(levelTwoIP, username='root', password=passwordIP2, sock=vmchannel)
            if jhost.get_transport().is_active():
                return client, jhost
            else:
                jhost.close()
                client.close()
                log('Unable to connect to ' + levelTwoIP + ' through ' + levelOneIP + ' trying again')
                if count == 10:
                    exit(1)
                time.sleep(10)
        elif count == 10:
            log('Unable to connect to ' + levelOneIP + ' through ssh with paramiko')
            exit(1)
        else:
            client.close()


def add_openshift_commands(cmd):
    cmd.append("""cat <<EOF > /etc/yum.repos.d/oc.repo
[oc]
name = oc
baseurl = http://9.30.110.240/oc
gpgcheck = 0
EOF""")
    cmd.append("""cat <<EOF > /root/ansible.cfg
[defaults]
# Set the log_path
#log_path = /tmp/ansible.log
# Additional default options for OpenShift Ansible
forks = 20
host_key_checking = False
retry_files_enabled = False
retry_files_save_path = ~/ansible-installer-retries
nocows = True
remote_user = root
roles_path = roles/
gathering = smart
fact_caching = jsonfile
fact_caching_connection = $HOME/ansible/facts
fact_caching_timeout = 600
callback_whitelist = profile_tasks
inventory_ignore_extensions = secrets.py, .pyc, .cfg, .crt, .ini
timeout = 30
[inventory]
unparsed_is_failed=true
[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=600s
timeout = 10
control_path = %(directory)s/%%h-%%r
EOF""")
    cmd.append("yum install docker NetworkManager atomic-openshift-utils -y")
    cmd.append("systemctl enable docker NetworkManager")
    return cmd


# The script starts here
def run():
    print("Validating the the arguments")
    account_info = validate_args()

    if external_access:
        if os.path.isfile(os.getcwd() + "/" + DEV_CONF_FILE):
            print(
                "There is an external access configuration file with the same name {} in the directory already, please move them away and try again...".format(DEV_CONF_FILE))
            sys.exit(1)

    # Suppress warning message when sending insecure request
    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

    # Ignoring the paramiko warning
    #   /usr/lib/python2.7/dist-packages/Crypto/Cipher/blockalgo.py:141: FutureWarning: CTR mode needs counter parameter, not IV
    warnings.simplefilter(action="ignore", category=FutureWarning)
    global main_mode
    if main_mode == "new":
        cluster_info = create_cluster(account_info)
    elif main_mode == "reload":
        cluster_info = reload_cluster(account_info)
    print("Request completed and generating the conf file")
    time.sleep(2)
    create_file(cluster_info)
    print("File generated")
    configure_nodes(account_info)
    print("Script finished successfully")
    sys.exit(0)


if __name__ == '__main__':
    run()