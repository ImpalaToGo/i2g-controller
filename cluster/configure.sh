#!/bin/bash
echo Starting Impala2go configuration.
echo -n Creating required folders. This may ask your sudo password.
sudo ./init_required_folders.sh
echo "- Done"
. s3.config
read -p "Please enter aws access key (Configured: $ACCESS_KEY): " ACCESS_KEY_INPUT
read -p "Please enter aws secret key (Configured: *****${SECRET_KEY:(-6)}): " SECRET_KEY_INPUT
read -p "Please enter default s3 bucket (Configured: $S3_BUCKET): " S3_BUCKET_INPUT
[[ ! -z "$ACCESS_KEY_INPUT" ]] && ACCESS_KEY=$ACCESS_KEY_INPUT
[[ ! -z "$SECRET_KEY_INPUT" ]] && SECRET_KEY=$SECRET_KEY_INPUT
[[ ! -z "$S3_BUCKET_INPUT" ]] && S3_BUCKET=$S3_BUCKET_INPUT

. instance_key.config
read -p "Please enter you key file name (Configured: $PRIVATE_KEY): " KEY_FILE_NAME_INPUT
if [ ! -z "$KEY_FILE_NAME_INPUT" ]
then
	eval PRIVATE_KEY=$KEY_FILE_NAME_INPUT
fi

function get_key_name()
{
	#function gets path to key and returns key name if key exists and exits script otherwise.
	#error message printed to STDERR
	local key_path=$1
	local a=$(dirname $key_path|wc -c)
	echo ${key_path:$a:256}|cut -f1 -d"."
}

if [  -e $PRIVATE_KEY -o -h $PRIVATE_KEY ]
then
	KEY_NAME=$(get_key_name $PRIVATE_KEY)
	chmod 400 $PRIVATE_KEY
else
	>&2 echo "Provided key $_key_path does not exist"
	exit 2
fi

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
S3_CONFIG=$SCRIPTPATH/s3.config
echo ACCESS_KEY=$ACCESS_KEY >$S3_CONFIG
echo SECRET_KEY=$SECRET_KEY >>$S3_CONFIG
echo S3_BUCKET=$S3_BUCKET >>$S3_CONFIG

INSTANCE_KEY_CONFIG=$SCRIPTPATH/instance_key.config
echo KEY_NAME=$KEY_NAME >$INSTANCE_KEY_CONFIG
echo PRIVATE_KEY=$PRIVATE_KEY >>$INSTANCE_KEY_CONFIG

echo Configuration skript finished successfuly.
