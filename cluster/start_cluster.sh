#!/bin/bash

BATCH_ID=$(uuidgen)
#BATCH_ID=ce5bdd53-a6fb-426f-95be-3490bc785499
. resize.config
. communication.functions
. tag.functions
#param $1 instance count
#param $2 instance type
#param $3 BATCH_ID
#param $4 Security group IDs


function createInstanceGroup {
	local INSTANCE_COUNT_LOCAL=$1
	local INSTANCE_TYPE_LOCAL=$2
	local BATCH_ID_LOCAL=$3
	local SECURITY_GROUP_IDS_LOCAL=$4

	echo $($LOG_PREFIX) Requesting to start $INSTANCE_COUNT_LOCAL instances of $INSTANCE_TYPE_LOCAL size with AMI: $IMAGE_ID|$LOG_APPEND

	$AWS_CMD run-instances --image-id $IMAGE_ID --count $INSTANCE_COUNT_LOCAL --instance-type $INSTANCE_TYPE_LOCAL --security-group-ids $SECURITY_GROUP_IDS_LOCAL --placement AvailabilityZone=$AVAILABILITY_ZONE --key-name $KEY_NAME --client-token $BATCH_ID_LOCAL --user-data "\'$USER_DATA\'" |$LOG_APPEND

	echo $($LOG_PREFIX) Run-instances request sent, waiting for all instances to run|$LOG_APPEND
	$AWS_CMD wait instance-running --filters Name=client-token,Values=$BATCH_ID_LOCAL|$LOG_APPEND

	echo $($LOG_PREFIX_LOCAL) All instances running querying instance details |$LOG_APPEND
	$AWS_CMD describe-instances --filters Name=client-token,Values=$BATCH_ID_LOCAL|$LOG_APPEND >$TEMP_FILE
	echo $($LOG_PREFIX_LOCAL) Getting DNS names|$LOG_APPEND
	DNS_NAMES=$(grep $BATCH_ID_LOCAL <${TEMP_FILE}|cut -f 15|tee ${CLUSTER_HOSTS}|$LOG_APPEND)

        while grep -q -v '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$' $CLUSTER_HOSTS
        do
                echo waiting for instances to be ready
                sleep 4
	        rm -f $CLUSTER_HOSTS
	        rm -f $TEMP_FILE
                $AWS_CMD describe-instances --filters Name=client-token,Values=$BATCH_ID_LOCAL|$LOG_APPEND >$TEMP_FILE
                DNS_NAMES=$(grep $BATCH_ID_LOCAL <${TEMP_FILE}|cut -f 15|tee ${CLUSTER_HOSTS}|$LOG_APPEND)
        done



	echo $($LOG_PREFIX_LOCAL) Adding ssh public-keys records to $SSH_KNOWN_HOSTS_FILE|$LOG_APPEND
	CLUSTER_HOSTS_COUNT=$(cat $CLUSTER_HOSTS|wc -w)
	#TODO: Add timeout
	while [ $(cat $SSH_KNOWN_HOSTS_FILE|wc -l) -lt $(expr $CLUSTER_HOSTS_COUNT \* 2) ]; do
		echo $($LOG_PREFIX) Trying to perform keyscan
		ssh-keyscan -H -f $CLUSTER_HOSTS  >$SSH_KNOWN_HOSTS_FILE
		sleep 1
	done
	echo $($LOG_PREFIX) Keyscan complete. Added $(cat $SSH_KNOWN_HOSTS_FILE|wc -l) keys for cluster|$LOG_APPEND

	echo $($LOG_PREFIX) Getting instance IDs|$LOG_APPEND
	grep $BATCH_ID_LOCAL <${TEMP_FILE}|cut -f8|tee ${CLUSTER_INSTANCES}
}

# script parameters are
# param 1 - number of servers to add.
# param 2 - access key 
# param 3 - secret key
# param 4 - DNS of the master node
set +x
COUNT=$1
NODE_TYPE=$2
shift 2
MASTER_NODE=$1

if [ -z $NODE_TYPE ];
then
	echo usage:
	echo "$0 <COUNT> <NODE TYPE> <MASTER URL>"
	exit 2
fi

#TODO: Create profile with keys
#TODO: Fixup logging

take_lock
echo $($LOG_PREFIX) Trying to start cluster $BATCH_ID|$LOG_APPEND
store_cluster_id $BATCH_ID
echo $($LOG_PREFIX) Creating security group if required|$LOG_APPEND

. create_impala_security_group.sh
SECURITY_GROUP_IDS=$(get_or_create_security_group ${SECURITY_GROUP} $NODE_TYPE|$LOG_APPEND)


echo $($LOG_PREFIX) Checking if requested AMI: $IMAGE_ID available|$LOG_APPEND
IMAGE_AVAILABLE=$($AWS_CMD describe-images --image-ids $IMAGE_ID|$LOG_APPEND|grep -o $IMAGE_ID)
if [ -z "$IMAGE_AVAILABLE" ];
then
        release_lock
	echo Image: $IMAGE_ID is not available
	echo please check configuration.
	exit 1
fi

createInstanceGroup "$COUNT" "$INSTANCE_TYPE" "$BATCH_ID" "$SECURITY_GROUP_IDS"
if [ "$NODE_TYPE" = "master" ]
then
	tag_masters
else
	tag_slaves $MASTER_NODE
fi
set -x
echo $($LOG_PREFIX) Creating RAID on instances|$LOG_APPEND
copy_to_all create_raid /tmp
run_cmd_on_all "sudo cp /tmp/create_raid /etc/init.d/ && [[ ! -h /etc/rc3.d/S16create_raid ]] && sudo ln -s /etc/init.d/create_raid /etc/rc3.d/S16create_raid && [[ ! -h /etc/rc3.d/S16create_raid ]] &&  sudo ln -s /etc/init.d/create_raid /etc/rc2.d/S16create_raid && sudo /etc/init.d/create_raid"|$LOG_APPEND
run_cmd_on_all "sudo /etc/init.d/create_raid"|$LOG_APPEND

copy_to_all target/attachToCluster.sh /home/ec2-user/
copy_to_all conf/* /home/ec2-user/conf/

echo $($LOG_PREFIX) Starting $BASE_NAME Cluster|$LOG_APPEND
if [ "$NODE_TYPE" = "master" ]; then
	run_cmd_on_all "sudo /home/ec2-user/attachToCluster.sh  $ACCESS_KEY $SECRET_KEY localhost $S3_BUCKET &&  sudo /home/ec2-user/restart_master.sh" |$LOG_APPEND
else
	run_cmd_on_all "sudo /home/ec2-user/attachToCluster.sh  $ACCESS_KEY $SECRET_KEY $MASTER_NODE $S3_BUCKET &&  sudo /home/ec2-user/restart_slave.sh" |$LOG_APPEND
fi

rm -f $TEMP_FILE
#echo $($LOG_PREFIX) All cluster nodes got configuration command. See master node $MASTER_NODE for details|$LOG_APPEND
release_lock
echo $($LOG_PREFIX) Cluster $BATCH_ID is up and running.|$LOG_APPEND
master_host=$(head -n 1 $CLUSTER_HOSTS)

if [ "$NODE_TYPE" = "master" ]; then
echo master node is started. YOUR MASTER NODE IS:  $master_host
else
echo $COUNT servers are added to the cluster 
fi


