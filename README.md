# Ansible Hadoop Cluster

Ansible playbooks for constructing hadoop cluster.  
For now, the cluster has following features:

1. Single namenode, multi datanodes
2. Kerberos authentication
3. HDFS, Yarn, MapReduce
4. Docker containers for devlopment environment

## Requirements

### Client machine for management the cluster

1. Python
2. Ansible
3. Keytab files (put the specifying directories)

### Nodes for NameNode/DataNode

1. Debian (OS)
2. SSH connection (to client machine)

## Build and Start the cluster

1. [SSH key copy](#1-ssh-key-copy)
2. [Install Hadoop cluster binaries and settings](#2-install-hadoop-cluster-binaries-and-settings)
3. [Init Hadoop cluster](#3-init-hadoop-cluster)
4. [Start Hadoop cluster](#4-start-hadoop-cluster)
5. [(Optional) Add user for executing yarn jobs](#5-optional-add-user-for-executing-yarn-jobs)

### 1. SSH key copy

Copy ssh keys to nodes from client machine for ansible.  
It is recommended to configure the connection user in `.ssh/config` to avoid specifying the user in `hosts` of Ansible.

```
ssh-copy-id user@namenode_ip
ssh-copy-id user@datanode1_ip
ssh-copy-id user@datanode2_ip
```

### 2. Install Hadoop cluster binaries and settings

Install Hadoop cluster binaries and settings to nodes.  
Before running the playbook, you need to configure the following files:

1. `inventories/dev/hosts` or `inventories/prod/hosts`
2. `roles/hadoop/files/keytab`
3. `roles/hadoop/files/jks`
4. `roles/hadoop/defaults/main.yaml` (princial names, etc.)

Also, you need to up docker containers if you use the development environment.

```bash
docker compose up -d
```

```
ansible-playbook -i inventories/(dev|prod)/hosts playbooks/install_hadoop.yaml
```

### 3. Init Hadoop cluster

You need to initialize the Hadoop cluster before starting it for first time.
When starting the cluster for first line, A Ignored Error is occured at JobHistoryServer.
It caused by the required directories are not created in HDFS yet, but it can be ignored.

The keytab file path and principal name are required for the initialization.
It can be specified as variables when running playbooks.

Specifically, the following initialization processes are performed:

1. Formatting HDFS
2. Creating required directories in HDFS
3. Granting permissions to the directories

```
ansible-playbook -i inventories/dev/hosts playbooks/start_hadoop.yaml
ansible-playbook -i inventories/dev/hosts playbooks/format_hdfs.yaml
ansible-playbook -i inventories/dev/hosts playbooks/init_hadoop.yaml
ansible-playbook -i inventories/dev/hosts playbooks/stop_hadoop.yaml
```

### 4. Start Hadoop cluster

Once the necessary initialization processes are complete, start the Hadoop cluster. At this stage, no errors should occur during startup.

```
ansible-playbook -i inventories/dev/hosts playbooks/start_hadoop.yaml
```

### 5. (Optional) Add user for executing yarn jobs

For executing Yarn jobs, you need to add a user to the cluster, and also this playbooks create a user home directories in HDFS.

```
ansible-playbook -i inventories/dev/hosts \
playbooks/add_hadoopuser.yaml \
-e "user_name=<user>"
```
