#!/bin/bash -ex

# Run first: sudo pip install -U awscli

IAM_USERNAME=backup-postgres-appendonly
BUCKET_NAME=backup-postgres-danstutzman

mkdir -p aws_creds

if [ ! -e aws_creds/$IAM_USERNAME.iam.json ]; then
  aws iam create-user --user-name $IAM_USERNAME \
    | tee aws_creds/$IAM_USERNAME.iam.json
fi

if [ ! -e aws_creds/$IAM_USERNAME.accesskey.json ]; then
  aws iam create-access-key --user-name $IAM_USERNAME \
    | tee aws_creds/$IAM_USERNAME.accesskey.json
fi

aws s3 mb s3://$BUCKET_NAME

aws s3api put-bucket-versioning --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

tee policy.json <<EOF
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF
aws iam put-user-policy --user-name $IAM_USERNAME \
 --policy-name can-upload-to-s3 \
 --policy-document file://policy.json
rm policy.json
