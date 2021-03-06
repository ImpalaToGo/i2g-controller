#!/bin/bash
if [ -z "$AWS_CMD" ];
then
	AWS_CMD="aws ec2"
fi
if [ -z "$MASTER_PORTS" ]
then
	MASTER_PORTS="80 22 21050 22000 23000 25000 25010 25020 24000 28000 15002 26000 15000 15001"
	SLAVE_PORTS="22 21050 23000 22000 21000 25000"

fi
#TODO: Redirect stderr to log
function get_group_id(){
	local group_name=$1
	local id=$($AWS_CMD describe-security-groups --group-names $group_name 2>/dev/null|grep $group_name|grep -oe "sg-[[:alnum:]]*")
	echo $id
}
function set_tcp_port(){
	local PORT=$1
        local GROUP_NAME=$2
	$AWS_CMD authorize-security-group-ingress --group-name $GROUP_NAME --protocol tcp --port $PORT --cidr 0.0.0.0/0 2>&1 >/dev/null
}
function create_group(){
	local GROUP_NAME=$1
	local id=$($AWS_CMD create-security-group --group-name $GROUP_NAME --description "Security group for Impala2go slave node" 2>/dev/null)
	echo $id
}
function get_or_create_security_group(){
	local GROUP_NAME=$1
	local ROLE=$2
	shift 2
	if [ "x$ROLE" = "xmaster" ]
	then
		local REQUIRED_PORTS=$MASTER_PORTS
	else
                local REQUIRED_PORTS=$SLAVE_PORTS
	fi

	if [ -z $GROUP_NAME -o ! -z "$DRY_RUN" ]; then
	        echo error
	fi

	local GROUP_ID=$(get_group_id $GROUP_NAME-$ROLE)
	if [  -z "$GROUP_ID" ]; then
		GROUP_ID=$(create_group $GROUP_NAME-$ROLE)
	fi

        local ALLOWED_PORTS=$($AWS_CMD describe-security-groups --group-names $GROUP_NAME-$ROLE|grep IPPERMISSIONS|grep tcp|cut -f4)

	for port in $REQUIRED_PORTS 
	do
		if [ -z "$(echo "$ALLOWED_PORTS" |grep $port)" ];
		then
			set_tcp_port $port $GROUP_NAME-$ROLE
		fi
	done

	if [ -z "$(echo $GROUP_ID|grep -oe "sg-[[:alnum:]]*")" ];
	then 
		GROUP_ID=error
	fi
	echo $GROUP_ID
}

case $1	in
	run )
		echo Group id for master: $(get_or_create_security_group $2-master master)
		echo Group id for slave: $(get_or_create_security_group $2-slave)
	;;
esac
