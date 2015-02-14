echo "Configuring ImpalaToGo"

read -p "Please enter your access key " ACCESS_KEY
read -p "Please enter your secret key " SECRET_KEY
read -p "Please enter your default s3 backet " S3_BUCKET
read -p "Please enter your key name " KEY_NAME
read -p "please enter you key file name " KEY_FILE_NAME


SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
S3_CONFIG=$SCRIPTPATH/s3.config
echo ACCESS_KEY=$ACCESS_KEY >$S3_CONFIG
echo SECRET_KEY=$SECRET_KEY >>$S3_CONFIG
echo S3_BUCKET=$S3_BUCKET >>$S3_CONFIG

INSTANCE_KEY_CONFIG=$SCRIPTPATH/instance_key.config
echo KEY_NAME=$KEY_NAME >$INSTANCE_KEY_CONFIG
echo PRIVATE_KEY=$KEY_FILE_NAME >>$INSTANCE_KEY_CONFIG

echo configuration finished. Please make sure that your key file $KEY_FILE_NAME is sitting in /home/ec2-user/cluster directory
