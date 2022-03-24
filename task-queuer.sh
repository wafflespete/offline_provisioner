#! /bin/bash

#task-queuer.sh

### GLOBAL VARS###
MASTER_PATH="/opt/offline_provisioner"
MASTER_ROLES_DIR="${MASTER_PATH}/ansible/roles"
WORKSTATION_DB="postgres"
INVENTORY_DIR="$MASTER_PATH/ansible/inventory"
ANSIBLE_LOG="$MASTER_PATH/ansible/log"
STD_OUT_MON='/tmp/prov_mon'
BLUE='\033[01;36m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
WHITE='\033[0m'
export TERM=xterm
##################

#Cut Whitespace off End of Lines
function TRIM () {

     tr -d "[:blank:]"
}

#Reset Terminal to Default Text Color
function N () {

    echo -en $WHITE
    #tput sgr0

}

#Print Blank Line
function nL () {
    echo
}

#Print Seperator in Terminal
function PRINT_SEPERATOR () {

    printf -v horule '%*s' "${COLUMNS:-$(tput cols)}" ''
    printf >&2 "%s" "${horule// /-}"
    
}

#Print Line to match length of Tables
function PRETTY_OUTPUT () {

        num=$1
        v=$(printf "%-${num}s" "-")
        echo "${v// /-}"
}

#do nothing function
function PASS () {

    echo -n

}


function LOCK_CHECK () {

    #Don't run until task-manager finishes queuing job
    while true
    do
        LOCK_FILE='/tmp/taskMan-lock'
        if [[ -f $LOCK_FILE ]]; then
            echo -e $YELLOW"task-queuer locked until task-manager completes" >> $STD_OUT_MON; N 
            nL
            sleep 5
        else
            break
        fi
    done
}

function BROKEN () {

    echo "CRITICAL: $*"
    
}

#Check that workstation DB is avail
function DB_CHECK () {

        PG_READY=$(pg_isready \
        -d postgres \
        -h localhost \
        -p 5432 -U postgres > /dev/null 2>&1; echo $?)
        if [[ $PG_READY != 0 ]]; then
            echo -e $RED "Workstation DB not Ready, exiting"
            exit 2
        fi

}


function SSH_ADD () {

    KEYS='<your public key>'
    KEY_DIR='/var/lib/postgresql/.ssh/'
    for K in $KEYS; do
        if [[ -z ${KEY_DIR}${K} ]]; then
            echo -e $RED"$K not in $KEY_DIR, exiting"
            exit 1
        else
            ssh-agent > /dev/null
            eval $(ssh-agent) > /dev/null
            ssh-add ${KEY_DIR}${K} &> /dev/null
            if [[ $? != 0 ]]; then 
                echo -e $RED "CRITICAL: Couldn't Add $K to ssh-agent, exiting... "
                exit 1
            fi
        fi
    done

}

#Clean all empty arrays and Primary Keys from both tables if no jobs remain in change_queue column

#Declare Where the Inv for the Corresponding Job is and select hosts that are online for corresponding job
function FIND_INV () {

    JOB_INV="${INVENTORY_DIR}/${J}"
    ONLINE_INV=$(psql $WORKSTATION_DB -tc \
    "SELECT hostname FROM clients WHERE '$J'=ANY(change_queue) and avail = 'Online'" | TRIM) 


}

function FILL_INV () {

    #Reset Inventory (double check)
    echo -n > $JOB_INV
    #Grab Variable if there is one, if not continue with static playbook
    VAR=$(psql $WORKSTATION_DB -t -c \
    "SELECT unnest(variables) FROM jobs WHERE job = '$J'")
    if [[ -z $VAR ]]
    then  
        echo "$ONLINE_INV" > $JOB_INV
    #Else parse jobs table variables array
    else
        RAW_VAR=$(cut -d "=" -f2 <<< $VAR)
        for Z in $ONLINE_INV; do 
            echo "${Z}" >> $JOB_INV     
            for O in $VAR; do
                FINAL_VAR_VAL=$(psql $WORKSTATION_DB -t -c \
                "SELECT $RAW_VAR FROM clients WHERE hostname = '$Z'"| xargs)
                FINAL_PRE_VAR=$(awk -F = '{print $1}' <<< $O)
                FINAL_VAR_STRING=" ${FINAL_PRE_VAR}=${FINAL_VAR_VAL}"
                #use a little sed to append as many variables as you want to the end of the hostname
                sed -i "/$Z/ s/$/${FINAL_VAR_STRING}/" $JOB_INV
            done
        done
    fi  

}

#Execute Play 
function PLAY () {
    
    echo -e $BLUE"Running TASK: $J"; N
    #PRINT_SEPERATOR >> $STD_OUT_MON 2>&1
    ansible-playbook -i $1 -u root $MASTER_ROLES_DIR/$2 

}

#Create Log File for Play, Use date to avoid redundant names
function GENERATE_LOG () {

    NOW=$(date +"%m.%d.%y_%H:%M")
    LOG=${ANSIBLE_LOG}/${J}_$NOW
    touch $LOG
    
}

#Nested Function that encompasses entire Log Parsing Mechanism (nested for organization/readability)
function PARSE_LOG () {
    
    #Create temporary success dir to collect report of all hosts that completed successfully (could be empty if things go horribly wrong)
    SUCCESS_TMP='/tmp/success_body'
    echo "$J Status Report" > $SUCCESS_TMP
    echo "----------------------------------------" >> $SUCCESS_TMP

    #FIND PLAY RECAP AREA OF LOG AND USE IT TO DETERMINE EACH HOSTS OUTCOME
    function RECAP () {

        awk '/PLAY RECAP/{y=1;next}y' $LOG
    
    }

    #FIND THE INTEGER ASSOCIATED WITH PLAY FOR EACH COLUMN 
    #EXAMPLE:
    #PLAY RECAP ********************************************************************************************************
    #workstation3                    : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
    function NUM () {
        
        if [[ ! -z $HOST ]]; then
            #the extra whitespace is key to identifying the correct host string
            RECAP | grep -w "$HOST " | awk '{print '$1'}' | cut -d "=" -f2 
        fi

    }
    
    function ADD_SUCCESS () {

        echo -e "$HOST: COMPLETED" >> $SUCCESS_TMP
    }

    #Remove job from host's change_queue array if determined that job is complete
    function REMOVE_FROM_QUEUE () {
        
        #echo "Removing $J from $HOST in clients table"
        nL
        echo "REMOVING $HOST FROM QUEUE"
        echo '-------------------------'
        psql $WORKSTATION_DB -tc \
        "UPDATE clients SET change_queue = array_remove(change_queue, '$J') where hostname = '$HOST'" | grep -q 'UPDATE 1' > /dev/null
        DB_REMOVE_STATUS=$?
        if [[  $DB_REMOVE_STATUS == 0 ]]; then
            echo -e "DB REMOVED: OK" $GREEN"\xE2\x9C\x94"; N
        elif [[ $DB_REMOVE_STATUS == 1 ]]; then 
            echo -e $RED "$HOST NOT REMOVED, ISSUE UDPATING TABLE"; N
        else 
            echo -e $RED "Unexpected Status Code of: $?, for Updating $HOST with Job: $J"; N
        fi
        sed -i "/$HOST/d" $JOB_INV
        INV_REMOVE_STATUS=$(grep -q $HOST $JOB_INV; echo $?)
        if [[  $INV_REMOVE_STATUS == 1 ]]; then
            echo -e "ANSIBLE REMOVED: OK" $GREEN"\xE2\x9C\x94"; N
        elif [[ $INV_REMOVE_STATUS == 0 ]]; then 
            echo -e $RED "CRITICAL: $HOST NOT REMOVED, REMOVING HOST FROM INV"; N
        fi
        nL

    }

        function QUARENTINE_FAILURE () {
        FAILURE_STDERR=$(echo -e "[$J]: " $(grep "$HOST" $LOG | grep fatal: | sed 's/^[^{]*//;s/[^}]*$//' | tr -d \'\"\{\}))
        #INSERT INTO mycopy(colA, colB) SELECT col1, col2 FROM mytable;
        function ADD_FAIL () { 
        
            #JOB DETAIL PRIMARY KEY
            psql $WORKSTATION_DB -t -c \
            "INSERT INTO failure (hostname, date, failure, job) VALUES ( NULL, '$F_NOW', '$FAILURE_STDERR', '$J') ON CONFLICT DO NOTHING"
            #UPDATE THAT ROW WITH INFORMATION ABOUT HOST
            #(hostname, job_details)
            psql $WORKSTATION_DB -t -c \
            "UPDATE failure SET hostname = array_append(hostname, '$HOST') where date = '$F_NOW'"

        }
        
        ADD_FAIL > /dev/null || BROKEN Problem Occured Adding $HOST Issue to Failure Table; N
        REMOVE_FROM_QUEUE > /dev/null ||  BROKEN Problem Occured While Removing $HOST FROM QUEUE; N

    }
    function BUILD_FAIL_REPORT () {
    UNIQUE_FAIL_ARRAY=$(psql $WORKSTATION_DB -t -c \
                        "SELECT failure FROM failure where job = '$J' and date = '$F_NOW'")
    PRETTY_FAIL=$(echo $UNIQUE_FAIL_ARRAY| head -1  | wc -L)
    #Set Job Detail
    #Loop over unique failures 
    for F in "$UNIQUE_FAIL_ARRAY"; do
        echo "           JOB FAILURE JOB: $J"
        PRETTY_OUTPUT $PRETTY_FAIL
        echo "FAILURE: $F"
        nL
        echo "HOSTS INVOLVED:"
        psql $WORKSTATION_DB -t -c \
        "SELECT unnest(hostname) from failure where date = '$F_NOW'"
        PRETTY_OUTPUT $PRETTY_FAIL
    done
    }

    #Using All Functions above, read the log's play recap and execute actions based on each hosts outcome
    # If ok = 1 and no change, the job was already completed, no change was made
    # If the sum of all changes + 1  for fact gathering = OK, then every task was executed successfully
    # If the sum of all bad $NUM is 0, it can be assumed that there were no errors, but some of the tasks were already completed
    # If output of every $NUM is 0, no change was observed
    # If UNREACH is greater than 0 then try pinging, then try adding pub key to host
    # If sum of integers is anything else, it is assumed there was a problem with the host

    function MAIN_PARSE_LOOP () {


    while read -r LINE; 
        do  
            HOST=$(echo $LINE | awk '{print $1}')
            OK=$(NUM '$3')
            CHANGED=$(NUM '$4')
            UNREACH=$(NUM '$5')
            FAILED=$(NUM '$6')
            SKIPPED=$(NUM '$7')
            RESCUED=$(NUM '$8')
            IGNORED=$(NUM '$9')
            NO_CHANGE_SUM=$((1+OK+FAILED+UNREACH+IGNORED))
            ALL_SUM=$((CHANGED+SKIPPED+RESCUED+IGNORED))
            BAD_SUM=$((RESCUED+UNREACH+FAILED))
            if [ -z "$LINE" ]; then
                #SKIP IF BLANK
                continue
          elif [[ $UNREACH -gt 0 ]];then
               echo "$HOST Having Connectivity Issues"
               echo "---------------------------------"
               echo -e $YELLOW"$HOST SSH or TASK Failed"
               echo 'Trying Ping'; N
               TRY_PING=$(ping -q -W .5 -c 1 $HOST > /dev/null; echo $?)
               if [[ $TRY_PING == 0 ]]; then
                    echo -e $GREEN"$HOST Online"; N
               else
                    echo -e $RED"$HOST Offline"; N
                    psql $WORKSTATION_DB -tc \
                    "UPDATE clients set avail = 'Offline' WHERE hostname = '$HOST'"
                    continue
               fi   
                echo -e $RED"[CRITICAL]: SSH keys can't be added, quarentining...."; N
                sleep .5
                nL
                QUARENTINE_FAILURE && \
                  echo -e "FAILURE LOGGED SUCCESSFULLY ON: "$RED $HOST; N
                  echo -e "-------------------------------------------"
                  echo -e "CLIENT DB REMOVED: OK" $GREEN"\xE2\x9C\x94"; N
                  echo -e "ANSIBLE REMOVED: OK" $GREEN"\xE2\x9C\x94"; N
                  echo -e "FAILURE DB ADDED: OK" $GREEN"\xE2\x9C\x94"; N
                    
          elif [[ $FAILED -gt 0 ]]; then
                echo -e $YELLOW"WARNING: Failed Task Detected on: $HOST"; N
                nL
                QUARENTINE_FAILURE && \
                    echo -e "-------------------------------------------"
                    echo -e "CLIENT DB REMOVED: OK" $GREEN"\xE2\x9C\x94"; N
                    echo -e "ANSIBLE REMOVED: OK" $GREEN"\xE2\x9C\x94"; N
                    echo -e "FAILURE DB ADDED: OK" $GREEN"\xE2\x9C\x94"; N

          elif [[ $NO_CHANGE_SUM == 1 ]]; then
                #echo  -e $GREEN "No Change to $HOST, task complete"; N
                REMOVE_FROM_QUEUE && ADD_SUCCESS
          elif [[ $((1+ALL_SUM)) == "$OK" ]]; then
                #echo -e $GREEN "$HOST task was completed"; N
                REMOVE_FROM_QUEUE && ADD_SUCCESS
          elif [[ $BAD_SUM == 0 ]]; then
                #echo -e $GREEN "$HOST Some Tasks were Completed, Others Were Already Done"; N
                REMOVE_FROM_QUEUE && ADD_SUCCESS
          elif [[ $ALL_SUM == 0 ]]; then
                #echo -e $GREEN "$HOST Task Was Already Completed"; N
                REMOVE_FROM_QUEUE && ADD_SUCCESS
          else 
               echo -e $RED "Problem Parsing $HOST from $LOG"; N
            fi
        done < <(RECAP)
        
        ANY_FAILS=$(psql  $WORKSTATION_DB -tc \
        "SELECT date FROM failure where job = '$J' and date = '$F_NOW'")
        #Check if there are any fails associated corresponding epoch timestamp
        for MULTI_FAIL in $ANY_FAILS; do 
            if [[ $ANY_FAILS -eq "$MULTI_FAIL" ]]; then
                NOTIFY_FAIL || BROKEN CANT NOTIFY FAILURE; N
            fi
        done
    }
    MAIN_PARSE_LOOP
    NOTIFY_SUCCESS
               
}

  
#Clean out jobs table if no hosts remain in change_queue
function SCRUB_JOBS () {

    JOBS_REMAIN=$(psql $WORKSTATION_DB -tc \
    "SELECT hostname from clients WHERE '$J'=ANY(change_queue)" || BROKEN Problem Occured While Scrubbing Jobs Table)
    #need to add more checks to this, -z is too ambiguous for such a volitile function
    if [[ -z $JOBS_REMAIN ]]; then
        psql $WORKSTATION_DB -tc \
        "DELETE FROM jobs WHERE job = '$J'" > /dev/null
    fi

}

#Check if there are jobs in clients table but not in jobs and fill in jobs if need be.
function JOBS_SYNC () {

    CLIENTS_EMPTY=$(psql $WORKSTATION_DB -tc \
    "SELECT unnest(change_queue) FROM clients WHERE cardinality(change_queue) != 0" | sort |uniq)
    for Q in $CLIENTS_EMPTY; do
        JOBS_EMPTY=$(psql $WORKSTATION_DB -tc \
        "SELECT job FROM jobs where job = '$Q'" | TRIM)
        if [[ $Q == "${JOBS_EMPTY}" ]]; then
            #echo -e $GREEN "$Q in sync on Clients and Jobs"; N
            #sleep 1
            continue
        elif [[ -z $JOBS_EMPTY ]]; then
            echo -e $YELLOW"WARNING: $Q in Clients table but not in Jobs Table, Syncing change_queue to Jobs now..."; N
            sleep .5
            psql $WORKSTATION_DB -tc \
            "INSERT INTO jobs(job) VALUES ('$Q') ON CONFLICT DO NOTHING" > /dev/null
            # It's theoretically impossible to have this happen unless manually done
            # more so for my own convenience if I add a job by hand to a custom group of hosts
        fi
    done

}

#GET STATUS OF HOSTS IN QUEUE FOR JOB
function STATUS_CHECK () {

    psql $WORKSTATION_DB -tc \
    "SELECT unnest(change_queue) from clients where '$J'=ANY(change_queue) $* "

}

#Before Starting main loop,check to see if there are any jobs in queue
#Also check if all jobs in queue contain exclusivley retired hosts (use this to extend sleep time between tasks)
function START_CHECK () {
    
    RETIRED_OPTS='and avail != '\'Retired\'''
    JOB_CHECK=$(psql $WORKSTATION_DB -tc \
    "SELECT unnest(change_queue) FROM clients WHERE cardinality(change_queue) != 0")
    ALL_RETIRED=$(psql $WORKSTATION_DB -tc \
    "SELECT unnest(change_queue) FROM clients WHERE cardinality(change_queue) != 0 $RETIRED_OPTS")
}

#Standard Summary of all remaining offline and retired hosts
function QUEUE_SUMMARY () {

    QUEUE_SUM=$(psql $WORKSTATION_DB -c \
              "SELECT hostname, state, os, ipv4, avail, supervisor as Sup,  last_seen FROM clients WHERE '$J'=ANY(change_queue) and avail != 'Retired' ORDER BY state" \
              | grep -v 'row' \
              | awk 'NF')
        QUEUE_SUM_LEN=$(echo "$QUEUE_SUM" | grep '-'| wc -L)
        PRETTY_OUTPUT $QUEUE_SUM_LEN
        echo "$QUEUE_SUM"
        PRETTY_OUTPUT $QUEUE_SUM_LEN
        nL
}

#Summary output if all hosts are retired
function RETIRE_SUMMARY () {

    RET_SUM=$(psql $WORKSTATION_DB -c \
            "SELECT hostname, state, os, ipv4, avail, supervisor as Super, last_seen, unnest(change_queue) as Job FROM clients WHERE cardinality(change_queue) != 0 ORDER BY state" \
            | grep -v 'row' \
            | awk 'NF')
    RET_SUM_LEN=$(echo "$RET_SUM" | wc -L)
    echo -e $YELLOW "                      No Jobs With Non Retired Hosts Available"; N
    PRETTY_OUTPUT $RET_SUM_LEN
    echo "$RET_SUM"
    PRETTY_OUTPUT $RET_SUM_LEN
    nL

}

function EXIT_MON () {

    echo -e $RED'PRESS CTRL-C TO EXIT MONITOR'; N

}


#if theres jobs contine ---> if theres any jobs with non retired hosts ---> if specific job has has non-retired hosts ---> if job has hosts online ---> execute or bail
function MAIN_LOOP () {

    JOB=$(psql $WORKSTATION_DB -t -c \
    "SELECT job FROM jobs" | TRIM)
        for J in $JOB; do
            F_NOW=$(date +%s)
            #Scrub jobs table before and after each Job run to ensure accurate summary
            #SCRUB_JOBS
            JOB_RETIRED=$(STATUS_CHECK "${RETIRED_OPTS[@]}")
                if [[ -z $JOB_RETIRED ]]; then
                    echo -e $BLUE "No Non-Retired Hosts Available for Job: $J"; N
                    continue
                fi
            FIND_INV
                if [[ -z $ONLINE_INV ]]; then 
                    echo -e $BLUE"       No Hosts Online for Job: $J"; N
                    QUEUE_SUMMARY
                    continue
                else 
                    FILL_INV
                fi
            GENERATE_LOG
            PLAY $JOB_INV $J | tee $LOG
            PARSE_LOG
            SCRUB_JOBS
        done
        ALL_JOBS_AVAIL=$(psql $WORKSTATION_DB -t -c "SELECT avail FROM clients WHERE cardinality(change_queue) != 0 and avail = 'Online'")
        if [[ -z $ALL_JOBS_AVAIL ]]; then
            nL
            echo -e $YELLOW"No One Online, Sleeping for 30 Seconds"; N
            nL
            EXIT_MON
            sleep 30
            clear
        fi 
}

#External global start function, perform multiple host checks before entering main function loop

LOCK_CHECK
while :
do
    START_CHECK
    echo -n > $STD_OUT_MON
    #CHECK IF ANY JOBS
    if [[ -z $JOB_CHECK ]]; then 
        echo -e $BLUE "NO JOBS AVAILABLE" >> $STD_OUT_MON; N
        EXIT_MON >> $STD_OUT_MON
        echo -e $YELLOW"Sleeping 2 Minutes" >> $STD_OUT_MON; N
        sleep 120
    #CHECK IF ALL JOBS IN QUEUE ONLY HAVE RETIRED HOSTS IN THEM
    #Daemon will not start unless there are hosts non-retired hosts in queue. Retired hosts will be treated as if they don't exist.
    elif [[ -z $ALL_RETIRED ]]; then
        RETIRE_SUMMARY >> $STD_OUT_MON
        EXIT_MON >> $STD_OUT_MON
        echo -e $YELLOW"Sleeping 2 Minutes" >> $STD_OUT_MON
        sleep 120
    else
        #REDIRECT THAT PRETTY OUTPUT TO A FILE THAT CAN BE MONITORED OUTSIDE OF DAEMON
        
        LOCK_CHECK >> $STD_OUT_MON
        JOBS_SYNC >> $STD_OUT_MON
        MAIN_LOOP >> $STD_OUT_MON
    fi
done

