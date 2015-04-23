#!/bin/bash
. resize.config

function usage()
{
	echo Usage: $0 INSTANCE-ID NAME-SUFFIX
}

INSTANCE_ID=$1
NAME_SUFFIX=$2
shift 2

if [ -z $NAME_SUFFIX ];
then
	usage
	exit 1
fi

. resize.config
IMAGE_NAME=ImpalaToGo-$NAME_SUFFIX
echo Creating image: $IMAGE_NAME
INSTANCE_ID=$($AWS_CMD create-image --instance-id $INSTANCE_ID --name $IMAGE_NAME --block-device-mappings "[{\"DeviceName\": \"/dev/sdb\",\"VirtualName\":\"ephemeral0\"},{\"DeviceName\": \"/dev/sdc\",\"VirtualName\":\"ephemeral1\"},{\"DeviceName\": \"/dev/sdd\",\"VirtualName\":\"ephemeral2\"},{\"DeviceName\": \"/dev/sde\",\"VirtualName\":\"ephemeral3\"},{\"DeviceName\": \"/dev/sdf\",\"VirtualName\":\"ephemeral4\"}]"|$LOG_APPEND)
