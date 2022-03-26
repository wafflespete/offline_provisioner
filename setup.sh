#! /bin/bash

LOG=/tmp/op_setup.log

if [[ -f misc/completed_setup ]]; then 
    echo 'Offline Provisioner Setup Already Completed'
	exit 0
fi
## setup.sh
function PRETTY_OUTPUT () 
{
    num=$1
    v=$(printf "%-${num}s" "-")
    echo "${v// /-}"
}

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
		sudo -u postgres sh -c "cd /var/lib/postgresql; psql -f example_client.sql" > $LOG 2>&1
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
	systemctl start task-queuer.service && echo -e "Task Queuer Started! \xE2\x9C\x94"
	systemctl start client_discovery.service && echo -e "Client Discovery Daemon Started! \xE2\x9C\x94"

}

install || exit 1
setup_psql || exit 1
setup_files || exit 1
setup_services || exit 1
touch misc/completed_setup
echo
echo "OFFLINE PROVISIONER SETUP COMPLETE!"
echo "###################################"
echo "Example Workstation has been added to clients table:"
echo
WORKSTATION1=$(sudo -u postgres sh -c 'psql postgres -tc "select hostname, state, os, ipv4, avail, last_seen, mac from clients" | grep -v 'row'')
WORKSTATION1_LEN=$(wc -L <<< $WORKSTATION1)
PRETTY_OUTPUT $WORKSTATION1_LEN
echo $WORKSTATION1
PRETTY_OUTPUT $WORKSTATION1_LEN
echo
echo "To add additional workstations, run the add_clients.sh script"
echo "To test out the task-queuer, run: ./custom-add.sh -P add_bogus_file -H workstation1"
echo