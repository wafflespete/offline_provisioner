# Offline Linux Provisioner

Push based provisioning system for Ubuntu Server. Used for client systems that aren't available 24/7. Script daemon will wait for target systems to come online and push updates/changes via ansible as targets become available.

## How Does it Work?

The offline provisioning system works in 4 parts centered around a PSQL Database:

1) Target clients are stored in the auto-generated PSQL database with important data about each client such as ipv4 address, hostname, MAC, etc...
2) Tasks (ansible plays) are queued into the PSQL database via a script (custom_add.sh) which assigns ansible tasks to target clients and stores those tasks in the DB for each workstation.
3) The client_discovery.sh daemon updates the postgresql table to inform the task-queuer daemon when clients are available
4) The task-queuer.sh daemon scans the clients table and inteprets tasks (ansible plays) to execute on targets when they avail is set to Online.

With all scripts used in combination the target clients are provisioned with whatever update is assigned as they come online. The SQL database also tracks failures of jobs and has the ability to notify necessary parties upon failure.

## Installation

Clone the install to the /opt directory on a linux server

```bash
cd /opt; git clone https://github.com/wafflespete/offline_provisioner.git
```

Run the setup script:

```bash
cd offline_provisioner; ./setup.sh

```
Wait 2 - 5 minutes for setup to complete:
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

To use the offline provisioning system, build a playbook or use one of the examples provided.


```bash

./custom-add.sh -P add_bogus_file -H workstation1

```

This will queue the 'add_bogus_file.yaml' play to workstation1 and install the changes once workstation1 comes online.


![proviion_task_1.gif](https://s1.gifyu.com/images/proviion_task_1.gif)

Here is an example of when a task is queued to a client and that client is unavailable (at first)

![proviion_task_with_wait.gif](https://s1.gifyu.com/images/proviion_task_with_wait.gif)
