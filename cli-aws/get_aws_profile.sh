#!/bin/bash
##################################################################################################
# Script: get_aws_profile.sh                                                                     #
#                                                                                                #
# Description: It creates a temporary token access with user credentials stored in default       #
#              Then, it uses provided role to asuming it, creating other temporary               #
#              credentials. With those credentials called "assumed-role", any aws command        #
#              can be run.                                                                       #
#              NOTE: The crendentials file will be backup. You need to customize global          #
#              variables them with your own values.                                              #
#												                                                             #
# Syntaxis:    usage: ./get_aws_profile.sh ACCOUNT-ALIAS AWS-REGION                              #
#												                                                             #
# Example:     ./get_aws_profile.sh main                                                         #
#              ./get_aws_profile.sh main eu-west-1                                               #
#                                                                                                #
# Author:      inaki-rodriguez                                                                   #
#                                                                                                #
##################################################################################################

# NOTE: Make a backup of aws credentials:
# cp ~/.aws/credentials ~/.aws/credentials_bak

# Global variables
MFA_ARN=arn:aws:iam::123456789012:mfa/user
ROLE_NAME=none

if [ $# -ne 1 ]; then
  if [ $# -ne 2 ]; then
    echo "Mising parameter"
    echo "Valid syntax: ./get_aws_profile.sh ENVIRONMENT-NAME [AWS-REGION]"
    exit -1
  fi
fi

echo ""
read -p 'Input your MFA token: ' MFA_TOKEN
echo ""

# Valid ACCOUNT-ALIAS
case "$1" in

'dev') echo "Getting temporary credentials for DEV_ADMIN"
        ROLE_NAME=arn:aws:iam::000000000000:role/DEV_ADMIN
        ;;
'test') echo "Getting temporary credentials for TEST_ADMIN"
        ROLE_NAME=arn:aws:iam::111111111111:role/TEST_ADMIN
        ;;
'prod') echo "Getting temporary credentials for PROD_ADMIN"
        ROLE_NAME=arn:aws:iam::222222222222:role/PROD_ADMIN
        ;;

esac

if [ "$ROLE_NAME" = "none" ]; then
   echo "Invalid environment provided. Valid values are:"
   echo "dev"
   echo "test"
   echo "prod"
   echo ""
   exit -1
fi

DEFAULT_REGION="region=eu-west-1"
if [ "$#" -ne 1 ]; then
        if [ "$#" -ne 2 ]; then
                echo "There was an error. Check your parameters!!"
                echo "usage: role MFA_TOKEN ACCOUNT-ALIAS [AWS_REGION]"
                exit -1
        fi
        DEFAULT_REGION="region=$2"
fi

# Debug purpose only...
echo "Using MFA"
echo $MFA_TOKEN

# Get temp credentials
OUTPUT="$(aws --profile main sts get-session-token --serial-number $MFA_ARN --token-code $MFA_TOKEN)"
if [ "$?" -ne 0 ]; then
  echo "There was an error. Check your MFA token or verify your AWS keys credentials are active"
  exit -1
fi
echo "temporary credentials fetched"

OUTPUT="$(echo "$OUTPUT" | tr -d '"')"
OUTPUT="$(echo "$OUTPUT" | tr -d '}')"
OUTPUT="$(echo "${OUTPUT//{/}")"
OUTPUT="$(echo "${OUTPUT//Credentials: /}")"
my_array=($(echo $OUTPUT | tr "," "\n"))

# Enable switches when value is next one, while looping array
TAKE_ACCESS_KEY="OFF"
TAKE_SECRET_KEY="OFF"
TAKE_SESSION_TOKEN="OFF"

# Looping the API response
for i in "${my_array[@]}"
do
    # Enabling switches
    if [ "$i" = "AccessKeyId:" ]; then
       TAKE_ACCESS_KEY="ON"
       continue
    fi
    if [ "$i" = "SecretAccessKey:" ]; then
       TAKE_SECRET_KEY="ON"
       continue
    fi
    if [ "$i" = "SessionToken:" ]; then
       TAKE_SESSION_TOKEN="ON"
       continue
    fi

    # Get KEYS
    if [ "$TAKE_ACCESS_KEY" = "ON" ]; then
       ACCESS_KEY_ID="$i"
       TAKE_ACCESS_KEY="OFF"
       continue
    fi
    if [ "$TAKE_SECRET_KEY" = "ON" ]; then
       SECRET_ACCESS_KEY="$i"
       TAKE_SECRET_KEY="OFF"
       continue
    fi
    if [ "$TAKE_SESSION_TOKEN" = "ON" ]; then
       SESSI0N_TOKEN="$i"
       TAKE_SESSION_TOKEN="OFF"
       continue
    fi
done

# cp ~/.aws/credentials ~/.aws/credentials_bak

# Create MFA temporary credentials
MFA_ENTRY="[mfa]"
MFA_OUTPUT="output=json"
MFA_REGION="${DEFAULT_REGION}"
MFA_ACCESS_KEY="aws_access_key_id=$ACCESS_KEY_ID"
MFA_SECRET_ACCESS_KEY="aws_secret_access_key=$SECRET_ACCESS_KEY"
MFA_SESSION_TOKEN="aws_session_token=$SESSI0N_TOKEN"
MFA_CREDENTIALS="${MFA_ENTRY}\n${MFA_OUTPUT}\n${MFA_REGION}\n${MFA_ACCESS_KEY}\n${MFA_SECRET_ACCESS_KEY}\n${MFA_SESSION_TOKEN}"

# Creating MFA credentials
LINE_START="$(nl -b a ~/.aws/credentials | grep mfa)"
if [ "$LINE_START" = "" ]; then
  echo "" >> ~/.aws/credentials
  echo -e $MFA_CREDENTIALS >> ~/.aws/credentials
  # MFA credentials created
else
  # Removing current MFA credentials
  LINE_START=(${LINE_START// / })
  LINE_END=$(($LINE_START + 5))
  cp ~/.aws/credentials ~/.aws/credentials_copy
  sed -e ''$LINE_START','$LINE_END'd' < ~/.aws/credentials_copy > ~/.aws/credentials
  rm ~/.aws/credentials_copy

  #echo "" >> ~/.aws/credentials
  echo -e $MFA_CREDENTIALS >> ~/.aws/credentials
  # MFA credentials created
fi

# Creating assumed-role credentials
OUTPUT="$(aws sts assume-role --role-arn $ROLE_NAME --role-session-name AWSCLI-Session --profile mfa )"
if [ "$?" -ne 0 ]; then
  echo "There was an error. Check your profile name"
  exit -1
fi
echo "role assumed"

OUTPUT="$(echo "$OUTPUT" | tr -d '"')"
OUTPUT="$(echo "$OUTPUT" | tr -d '}')"
OUTPUT="$(echo "${OUTPUT//{/}")"
OUTPUT="$(echo "${OUTPUT//Credentials: /}")"
my_array=($(echo $OUTPUT | tr "," "\n"))
my_array=($(echo $OUTPUT | tr "," "\n"))

TAKE_ACCESS_KEY="OFF"
TAKE_SECRET_KEY="OFF"
TAKE_SESSION_TOKEN="OFF"

for i in "${my_array[@]}"
do
    # Enabling switches if needed
    if [ "$i" = "AccessKeyId:" ]; then
       TAKE_ACCESS_KEY="ON"
       continue
    fi
    if [ "$i" = "SecretAccessKey:" ]; then
       TAKE_SECRET_KEY="ON"
       continue
    fi
    if [ "$i" = "SessionToken:" ]; then
       TAKE_SESSION_TOKEN="ON"
       continue
    fi

    # Get KEYS
    if [ "$TAKE_ACCESS_KEY" = "ON" ]; then
       ACCESS_KEY_ID="$i"
       TAKE_ACCESS_KEY="OFF"
       continue
    fi
    if [ "$TAKE_SECRET_KEY" = "ON" ]; then
       SECRET_ACCESS_KEY="$i"
       TAKE_SECRET_KEY="OFF"
       continue
    fi
    if [ "$TAKE_SESSION_TOKEN" = "ON" ]; then
       SESSI0N_TOKEN="$i"
       TAKE_SESSION_TOKEN="OFF"
       continue
    fi
done

# Create Assumed-Role temporary credentials
ASSUMED_ROLE_ENTRY="[default]"
ASSUMED_ROLE_REGION="${DEFAULT_REGION}"
ASSUMED_ROLE_ACCESS_KEY="aws_access_key_id=$ACCESS_KEY_ID"
ASSUMED_ROLE_SECRET_ACCESS_KEY="aws_secret_access_key=$SECRET_ACCESS_KEY"
ASSUMED_ROLE_SESSION_TOKEN="aws_session_token=$SESSI0N_TOKEN"
ASSUMED_ROLE_CREDENTIALS="${ASSUMED_ROLE_ENTRY}\n${ASSUMED_ROLE_REGION}\n${ASSUMED_ROLE_ACCESS_KEY}\n${ASSUMED_ROLE_SECRET_ACCESS_KEY}\n${ASSUMED_ROLE_SESSION_TOKEN}"

#echo $ASSUMED_ROLE_CREDENTIALS
#echo ""

LINE_START="$(nl -b a ~/.aws/credentials | grep default)"
if [ "$LINE_START" = "" ]; then
  echo "" >> ~/.aws/credentials
  echo -e $ASSUMED_ROLE_CREDENTIALS >> ~/.aws/credentials
  # Assumed-Role credentials created
else
  # Removing current Assumed Role credentials...
  LINE_START=(${LINE_START// / })
  LINE_END=$(($LINE_START + 4))
  cp ~/.aws/credentials ~/.aws/credentials_copy
  sed -e ''$LINE_START','$LINE_END'd' < ~/.aws/credentials_copy > ~/.aws/credentials
  rm ~/.aws/credentials_copy

  #echo "" >> ~/.aws/credentials
  echo -e $ASSUMED_ROLE_CREDENTIALS >> ~/.aws/credentials
  # Assumed-Role credentials created
fi
echo "Temporary credentials set correctly"

echo "Use profile -> "default" for all next commands for same default"
echo "e.g. -> aws --profile default ec2 describe-instances"
echo "By default, session credentials are 1h valid, so get new session after: $(date -v+1H)"

exit 0
