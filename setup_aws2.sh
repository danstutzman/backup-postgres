#!/bin/bash -ex

# Run first: sudo pip install -U awscli

IAM_USERNAME=backup-postgres-recovery
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

tee policy.json <<EOF
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::$BUCKET_NAME"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:GetObjectVersion"],
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF
aws iam put-user-policy --user-name $IAM_USERNAME \
 --policy-name can-upload-to-s3 \
 --policy-document file://policy.json
rm policy.json
