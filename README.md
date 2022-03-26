# Offline Linux Provisioner

Push based provisioning system for Ubuntu Server. Used for client systems that aren't available 24/7. Script daemon will wait for target systems to come online and push updates/changes via ansible as targets become available.

## How Does it Work?

The offline provisioning system works in 3 parts:

1) Clients are stored in the auto-generated postgresql database
2) The task-queuer.sh daemon scans the table and inteprets tasks (ansible plays) as they are assigned to clients
3) The client_discovery.sh daemon updates the postgresql table to inform the task-queuer daemon when clients are available to 

In combination the target clients are provisioned with whatever update is needed as they come online. The SQL database also tracks failures of jobs and has the ability to notify necessary parties upon failure.

## Installation

Clone the install to the /opt directory on a linux server

```bash
cd /opt; git clone https://github.com/wafflespete/offline_provisioner.git
```

Run the setup script:

```bash
cd offline_provisioner; ./setup.sh

```
Then Setup Script Will run for about 2 - 5 minutes:
```
Obtaining PSQL Apt Key
######################
Apt Key Added      

Getting Apt Update 
###################
Update Successful

Installing Needed Packages
##########################
Applications Installed

Setting Up Database
###################
Database set up successfully!

Installing System Daemons
#########################
Task Queuer Started! ✔
Client Discovery Daemon Started! ✔

OFFLINE PROVISIONER SETUP COMPLETE!
###################################
Example Workstation has been added to clients table:

---------------------------------------------------------------------------------
workstation1 | WI | ubuntu 20 | 192.168.1.48 | Online | 2022-03-26 | 8064F4084B87
---------------------------------------------------------------------------------

To add additional workstations, run the add_clients.sh script
To test out the task-queuer, run: ./custom-add.sh -P add_bogus_file -H workstation1  
```
    
This will install and setup the necessary packages, postgresql tables, schemas, and directories.


## Usage/Examples

To use the offline provisioning system, build a playbook or use one of the example ones provided.


```bash

./custom-add.sh -P add_bogus_file -H workstation1

```

This will queue the 'add_bogus_file.yaml' play to workstation1 and install the changes once workstation1 comes online.


![proviion_task_1.gif](https://s1.gifyu.com/images/proviion_task_1.gif)

Here is an example of when a task is queued to a client and that client is unavailable (at first)

![proviion_task_with_wait.gif](https://s1.gifyu.com/images/proviion_task_with_wait.gif)
