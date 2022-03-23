#! /bin/bash

LOG=/tmp/op_setup.log

## setup.sh

function error () 
{
	echo $* && return 1
}

function install ()
{
	echo "Obtaining PSQL Apt Key"
	echo "######################"
	echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list || error "Issue Occured while adding postgresql to sources.list.d"
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - || error "Issue Occured while obtaining psql gpg key"

	echo "Getting Apt Update"
	echo "###################"
	if apt-get update > $LOG; then
		echo "Update Successful"
	else
		error "Critical Issue Occured during apt-get update"
	fi

	echo "Installing Needed Packages"
	echo "##########################"
	if apt-get install -y perl python3 python3-pip  postgresql-12 postgresql-client-12 postgresql-plpython3-12  ansible swaks > $LOG; then
		echo "Applications Installed"
	else
		error "Issue Occured Installing necessary applications"
	fi
}

function setup_psql ()
{
	echo "Setting Up Database"
	echo "###################"
	cp  database/provisoner_schema.sql /var/lib/postgresql/schema.sql
	if sudo -u postgres psql -f /var/lib/postgresql/schema.sql; then
		echo "Database set up successfully!"
	else
		error "Critical: Failed to setup database"
	fi
	

}

install || exit 1
setup_psql || exit 1