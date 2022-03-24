# Offline Linux Provisioner

Push based provisioning system for Ubuntu Server. Used for client systems that aren't available 24/7. Script daemon will wait for target systems to come online and push updates/changes via ansible as targets become available.


## Installation

Clone the install to /opt ctory on a linux server

```bash
cd /opt; git clone https://github.com/wafflespete/offline_provisioner.git
```

Run the setup script:

```bash
  cd offline_provisioner
  ./setup.sh 
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
  Database Built Successfully
  
```
    
This will install and setup the necessary postgresql tables, schemas, and directories.


## Usage/Examples

To use the offline provisioning system, build a playbook or use one of the example ones provided.


```bash

    ./custom-add.sh -P add_bogus_file -H workstation1

```

This will queue the 'add_bogus_file.yaml' play to workstation1 and install the changes once workstation1 comes online.


![proviion_task_1.gif](https://s1.gifyu.com/images/proviion_task_1.gif)

Here is an example of when a task is queued to a client and that client is unavailable (at first)

![proviion_task_with_wait.gif](https://s1.gifyu.com/images/proviion_task_with_wait.gif)
