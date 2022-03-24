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
	if apt-get install -y perl python3 python3-pip  postgresql-12 postgresql-client-12 postgresql-plpython3-12 ansible fping > $LOG 2>&1; then
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
	cp database/example_client.sql /var/lib/postgresql/example_client.sql
	sudo -u postgres sh -c "cd /var/lib/postgresql; psql -f schema.sql" > $LOG 2>&1 || error "Issue Adding Schema To Postgres DB"
	function check_db () 
	{
		##Add Example Woprkstation To Get Daemon Started
		sudo -u postgres sh -c "cd /var/lib/postgresql; psql -f example_client.sql"
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
	fix_perms ()
	{
		chown -R postgres:postgres /opt/offline_provisioner
	}
	for i in log inventory files; do
		mkdir -p ansible/$i
	done
	echo 'Hello World' > ansible/files/foo.txt
	fix_perms || error "Issue adjusting permissions"
}

function setup_services ()
{
	set -e
	if ! grep -q workstation /etc/hosts; then
		echo '192.168.1.47    workstation1' >> /etc/hosts
	fi
	chown -R postgres:postgres /opt/offline_provisioner
	echo "Installing System Daemons"
	echo "#########################"
	cd /opt/offline_provisioner
	cp misc/task-queuer.service /etc/systemd/system/task-queuer.service
	cp misc/client_discovery.service /etc/systemd/system/client_discovery.service
	systemctl daemon-reload
	systemctl start task-queuer.service && echo "Task Queuer Started!"
	systemctl start client_discovery.service && echo "Client Discovery Daemon Started!"

}

install || exit 1
setup_psql || exit 1
setup_files || exit 1
setup_services || exit 1