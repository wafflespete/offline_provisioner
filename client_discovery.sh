#! /bin/bash

DB_SWITCHES='-tc'
CLIENTS_DB="postgres $DB_SWITCHES"

touch /tmp/pingit

function SET_IP () 
{
    psql $CLIENTS_DB \
    "UPDATE clients SET ipv4 = add_ip(hostname)"
}

function CHECK_AVAIL () 
{
    ALL_HOSTS=$(psql $CLIENTS_DB "SELECT hostname from clients")
    fping $ALL_HOSTS -r 1 -a > /tmp/pingit
    AVAIL='/tmp/pingit'
    N=25
    for target in $ALL_HOSTS; do
        ((i=i%N)); ((i++==0)) && wait
        function pingit () {
        if grep -qw "$target" $AVAIL; then
            psql $CLIENTS_DB \
            "UPDATE clients SET avail = 'Online' where hostname = '$target'"
        else
            CHECK_ELAPSED=$(psql $CLIENTS_DB \
            "select make_interval(days => ((extract(epoch from now()) - extract(epoch from last_seen::date))/(60*60*24))::integer)::text from clients where hostname = '$target'" |  grep -o '[0-9]\+')
            if [[ $CHECK_ELAPSED -gt 8 ]]; then
                psql $CLIENTS_DB \
                "UPDATE clients SET avail = 'Retired' where hostname = '$target'"
            else
                 psql $CLIENTS_DB \
                "UPDATE clients SET avail = 'Offline' where hostname = '$target'"
            fi
        fi
        }
        pingit > /dev/null &
    done
}


function MAIN ()
{
    SET_IP || return 1
	CHECK_AVAIL || return 1
}

while :
do
    if ! MAIN; then
        exit 1
    fi
    echo 'going to sleep'
    sleep 120
done