#!/bin/bash -ex

mkdir -p ssh_creds

for INSTANCE_NAME in pg backup; do
  if [ ! -e ssh_creds/barman@$INSTANCE_NAME.id_rsa.pub ]; then
    gcloud compute ssh $INSTANCE_NAME <<EOF
      set -ex
      sudo mkdir -p /var/lib/barman/.ssh
      sudo chown barman:barman /var/lib/barman/.ssh
      sudo chmod 700 /var/lib/barman/.ssh
      # "yes no" means don't overwrite if the file already exists
      yes no | sudo sudo -u barman ssh-keygen -t rsa -N '' -y -f /var/lib/barman/.ssh/id_rsa
      sudo cp /var/lib/barman/.ssh/id_rsa.pub ~/barman@$INSTANCE_NAME.id_rsa.pub
      sudo chown \$USER ~/barman@$INSTANCE_NAME.id_rsa.pub
EOF
    gcloud compute copy-files $INSTANCE_NAME:barman@$INSTANCE_NAME.id_rsa.pub ssh_creds/barman@$INSTANCE_NAME.id_rsa.pub
    gcloud compute ssh $INSTANCE_NAME "rm ~/barman@$INSTANCE_NAME.id_rsa.pub"
  fi
done

# Add barman@pg's public key to barman@backup's authorized_keys
gcloud compute copy-files ssh_creds/barman@pg.id_rsa.pub backup:barman@pg.id_rsa.pub
gcloud compute ssh backup <<EOF
set -ex
sudo grep -q barman@pg /var/lib/barman/.ssh/authorized_keys || cat barman@pg.id_rsa.pub | sudo tee -a /var/lib/barman/.ssh/authorized_keys
sudo chown barman:barman /var/lib/barman/.ssh/authorized_keys
sudo chmod 600 /var/lib/barman/.ssh/authorized_keys
rm barman@pg.id_rsa.pub
EOF
gcloud compute ssh pg "sudo sudo -u barman ssh -o StrictHostKeyChecking=no barman@backup echo success"

# Add barman@backup's public key to barman@pg's authorized_keys
gcloud compute copy-files ssh_creds/barman@backup.id_rsa.pub pg:barman@backup.id_rsa.pub
gcloud compute ssh pg <<EOF
set -ex
sudo grep -q barman@backup /var/lib/barman/.ssh/authorized_keys || cat barman@backup.id_rsa.pub | sudo tee -a /var/lib/barman/.ssh/authorized_keys
sudo chown barman:barman /var/lib/barman/.ssh/authorized_keys
sudo chmod 600 /var/lib/barman/.ssh/authorized_keys
rm barman@backup.id_rsa.pub
EOF
gcloud compute ssh backup "sudo sudo -u barman ssh -o StrictHostKeyChecking=no barman@pg echo success"
