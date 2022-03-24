#! /bin/bash
WORKSTATION_DB="postgres -t -c "


 function USAGE ()
 {
    echo "Usage: ./custom-add.sh -P <name of ansible play> -H <name of workstation> -V <state=state>"
    exit 1
 }

function WORKSTATION_ADD ()
{
    read -r -p "Enter Names of Target Clients (workstation1 workstation2... etc): " HOSTS
}

function DB_UPDATE ()
{
for i in $HOSTS
do

psql $WORKSTATION_DB \
    "UPDATE clients SET change_queue = array_append(change_queue, '$ROLE')  WHERE hostname = '$i' AND ('$ROLE' != ALL(coalesce(change_queue, array[]::text[])))" && echo "Job Added To Queue for: $i"

psql $WORKSTATION_DB \
    "INSERT INTO jobs(job) VALUES ('$ROLE') ON CONFLICT DO NOTHING" > /dev/null
done

if [[ -n $VARIABLE ]]; then

        if ! psql $WORKSTATION_DB "select variables from jobs where job = '$ROLE'" | grep -q $VARIABLE; then
                psql $WORKSTATION_DB \
                "UPDATE jobs SET variables = array_append(variables, '$VARIABLE') where job = '$ROLE'" > /dev/null && echo "Var Added To Jobs table: $VARIABLE"
        fi
fi
}


while getopts H:V:P:s option
do
    case "${option}"
    in
    H)  #Only Display Matching Name
        HOSTS=${OPTARG}
        ;;
    V)  VARIABLE=${OPTARG}
        ;;
    P) #NAME OF PLAY
        PLAY=${OPTARG}
        if  [[ -f ansible/roles/$PLAY ]]; then
            ROLE=$PLAY
        else
            echo "$PLAY: Doesn't Exist, choose from these:
            $(ls ansible/roles)"
            exit 1
        fi
        ;;
    *) USAGE
    esac
done


if [[ -z $HOSTS ]]; then
    WORKSTATION_ADD
fi

DB_UPDATE