#! /bin/bash

LOG=/tmp/op_setup.log

## setup.sh

function error () 
{
	echo $* && return 1
}

function install ()
{

	function psql_apt_key ()
	{
		echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list || error "Issue Occured while adding postgresql to sources.list.d"
		sudo apt-key add misc/ACCC4CF8.asc || error "Issue Occured while add psql asc key"
	}
	echo "Obtaining PSQL Apt Key"
	echo "######################"
	if psql_apt_key > $LOG 2>&1; then
		echo "Apt Key Added
		"
	else
		error "Issue Occured Obtaining PSQL Apt Key"
	fi
	echo "Getting Apt Update"
	echo "###################"
	if apt-get update > $LOG 2>&1; then
		echo "Update Successful
		"
	else
		error "Critical Issue Occured during apt-get update"
	fi

	echo "Installing Needed Packages"
	echo "##########################"
	if apt-get install -y perl python3 python3-pip  postgresql-12 postgresql-client-12 postgresql-plpython3-12  ansible fping > $LOG 2>&1; then
		echo "Applications Installed
		"
	else
		error "Issue Occured Installing necessary applications"
	fi
}

function setup_psql ()
{
	echo "Setting Up Database"
	echo "###################"
	cp  database/provisioner_schema.sql /var/lib/postgresql/schema.sql
	sudo -u postgres sh -c "cd /var/lib/postgresql; psql -f schema.sql" > $LOG 2>&1
	function check_db () 
	{
		##Add Example User To Get Daemon Started
		sudo -u postgres sh -c "cd /var/lib/postgresql; psql postgres -c 'insert into clients (hostname, state, os, supervisor, ipv4, avail, last_seen, mac) \
								value ('workstation1', 'ca', 'ubuntu 20', t, 192.168.1.95, 'Offline', '$(date +%Y-%m-%d)', '8064F4084B87')"
	}
	if check_db; then
		echo "Database set up successfully!
		"
	else
		error "Critical: Failed to setup database"
	fi
	
}
function setup_files ()
{
	mkdir -p ansible/log
	mkdir -p ansible/inventory
	mkdir -p ansible/files
	echo 'Hello World' > ansible/files/foo.txt
}

install || exit 1
setup_psql || exit 1