#!/bin/bash -ex

IAM_USERNAME=backup-postgres-recovery
BUCKET_NAME=backup-postgres-danstutzman

if [ `gcloud compute instances list postgres-recovery | wc -l` != "2" ]; then
  gcloud compute instances create postgres-recovery \
    --machine-type g1-small \
    --image ubuntu-14-04
fi

AWS_ACCESS_KEY_ID=$(cat aws_creds/$IAM_USERNAME.accesskey.json | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["AccessKey"]["AccessKeyId"]')
if [ "$AWS_ACCESS_KEY_ID" == "" ]; then
  echo 1>&2 "Empty AWS_ACCESS_KEY_ID"
  exit 1
fi

AWS_SECRET_ACCESS_KEY=$(cat aws_creds/$IAM_USERNAME.accesskey.json | python -c 'import json,sys; obj=json.load(sys.stdin); print obj["AccessKey"]["SecretAccessKey"]')
if [ "$AWS_SECRET_ACCESS_KEY" == "" ]; then
  echo 1>&2 "Empty AWS_SECRET_ACCESS_KEY"
  exit 1
fi

gcloud compute ssh postgres-recovery <<EOF
set -ex
sudo apt-get update
sudo apt-get install -y postgresql

sudo apt-get install -y daemontools python-pip python-dev git lzop pv
if [ ! -e wal-e ]; then
  git clone https://github.com/wal-e/wal-e.git
fi
sudo pip install wal-e
sudo pip install requests==2.8.1 # for some reason it's not installed with wal-e
sudo pip install six==1.9.0 # for some reason it's not installed with wal-e

if [ ! -e /etc/postgresql/9.3/main/postgresql.conf.bak ]; then
  sudo cp /etc/postgresql/9.3/main/postgresql.conf \
    /etc/postgresql/9.3/main/postgresql.conf.bak
fi
sudo cp /etc/postgresql/9.3/main/postgresql.conf.bak /etc/postgresql/9.3/main/postgresql.conf

sudo mkdir -p /etc/wal-e.d/env
echo "$AWS_ACCESS_KEY_ID"     | sudo tee /etc/wal-e.d/env/AWS_ACCESS_KEY_ID
echo "$AWS_SECRET_ACCESS_KEY" | sudo tee /etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY
echo s3://$BUCKET_NAME        | sudo tee /etc/wal-e.d/env/WALE_S3_PREFIX
echo us-east-1                | sudo tee /etc/wal-e.d/env/AWS_REGION
sudo chown -R root:postgres /etc/wal-e.d

sudo service postgresql stop
sudo rm -rf /var/lib/postgresql/9.3/main
sudo sudo -u postgres envdir /etc/wal-e.d/env /usr/local/bin/wal-e backup-fetch /var/lib/postgresql/9.3/main LATEST
echo "restore_command = '/usr/bin/envdir /etc/wal-e.d/env /usr/local/bin/wal-e wal-fetch \"%f\" \"%p\"'" | sudo tee /var/lib/postgresql/9.3/main/recovery.conf
sudo chown postgres:postgres /var/lib/postgresql/9.3/main/recovery.conf
sudo service postgresql start
EOF
