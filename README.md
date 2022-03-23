# Offline Linux Provisioner

Remote workstations are constantly unavailable and sometimes a pull based system isn't the answer. To fix this issue, I've created a set of scripts and tools capable of discovering new workstations, pushing updates via ansible to those workstations, or waiting for that workstation to come online to recieve the update.







## Installation

Clone the install to any directory on a linux server

run the setup script:

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
  Database set up successfully!
  
```
    
This will install and setup the necessary postgresql tables, schemas, and directories.


## Usage/Examples

To use the offline provisioning system, build a playbook or use one of the example ones provided.


```bash

    ./custom-add.sh -P add_bogus_file -H workstation3

```

This will queue the 'add_bogus_file.yaml' play to workstation 3 and install the changes once workstation3 comes online.
