#!/bin/bash
USER=$1
PASS=$2
echo User is: $1
echo Pass is: $2
wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm
rpm -ivh epel-release-7-8.noarch.rpm

yum install -y -q nfs-utils sshpass nmap
yum groupinstall -y "X Window System"
mkdir -p /mnt/nfsshare

chmod -R 777 /mnt/nfsshare/
systemctl enable rpcbind
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
systemctl restart nfs-server

ln -s /opt/intel/impi/5.1.3.181/intel64/bin/ /opt/intel/impi/5.1.3.181/bin
ln -s /opt/intel/impi/5.1.3.181/lib64/ lib

mkdir -p /home/$USER/bin
wget --quiet https://raw.githubusercontent.com/tanewill/5clickTemplates/master/RawCluster/install-fluent.sh
wget --quiet http://azbenchmarkstorage.blob.core.windows.net/ansysbenchmarkstorage/ANSYS.tgz -O /mnt/resource/ANSYS.tgz
wget --quiet https://raw.githubusercontent.com/tanewill/5clickTemplates/master/RawCluster/clusRun.sh -O /home/$USER/bin/clusRun.sh
wget --quiet https://raw.githubusercontent.com/tanewill/5clickTemplates/master/RawCluster/cn-setup.sh -O /home/$USER/bin/cn-setup.sh
chmod +x /home/$USER/bin/clusRun.sh
chmod +x /home/$USER/bin/cn-setup.sh
chown $USER:$USER /home/$USER/bin/*

localip=`hostname -i | cut --delimiter='.' -f -3`
echo "/mnt/nfsshare $localip.*(rw,sync,no_root_squash,no_all_squash)" | tee -a /etc/exports

mv passwordlessAuth.sh /home/$USER/bin/
nmap -sn $localip.* | grep $localip. | awk '{print $5}' > /home/$USER/bin/nodeips.txt
myhost=`hostname -i`
sed -i '/'$myhost'/d' /home/$USER/bin/nodeips.txt
sed -i '/10.0.0.1/d' /home/$USER/bin/nodeips.txt

mkdir -p /home/$USER/.ssh
echo -e  'y\n' | ssh-keygen -f /home/$USER/.ssh/id_rsa -t rsa -N ''

echo 'Host *' >> /home/$USER/.ssh/config
echo 'StrictHostKeyChecking no' >> /home/$USER/.ssh/config
chmod 400 /home/$USER/.ssh/config
chown $USER:$USER /home/$USER/.ssh/config

mkdir -p ~/.ssh
echo 'Host *' >> ~/.ssh/config
echo 'StrictHostKeyChecking no' >> ~/.ssh/config
chmod 400 ~/.ssh/config

for NAME in `cat /home/$USER/bin/nodeips.txt`; do sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'hostname' >> /home/$USER/bin/nodenames.txt;done

NAMES=`cat /home/$USER/bin/nodenames.txt` #names from names.txt file
for NAME in $NAMES; do
        sshpass -p $PASS scp -o "StrictHostKeyChecking no" -o ConnectTimeout=2 /home/$USER/bin/cn-setup.sh $USER@$NAME:/home/$USER/
        sshpass -p $PASS scp -o "StrictHostKeyChecking no" -o ConnectTimeout=2 /home/$USER/nodenames.txt $USER@$NAME:/home/$USER/
        sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'mkdir /home/'$USER'/.ssh && chmod 700 .ssh'
        sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME "echo -e  'y\n' | ssh-keygen -f .ssh/id_rsa -t rsa -N ''"
        sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'touch /home/'$USER'/.ssh/config'
        sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'echo "Host *" >  /home/'$USER'/.ssh/config'
        sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'echo StrictHostKeyChecking no >> /home/'$USER'/.ssh/config'
        sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'chmod 400 /home/'$USER'/.ssh/config'
        cat /home/$USER/.ssh/id_rsa.pub | sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'cat >> /home/'$USER'/.ssh/authorized_keys'
        sshpass -p $PASS scp -o "StrictHostKeyChecking no" -o ConnectTimeout=2 $USER@$NAME:/home/$USER/.ssh/id_rsa.pub /home/$USER/.ssh/sub_node.pub

        for SUBNODE in `cat /home/$USER/bin/nodeips.txt`; do
                sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$SUBNODE 'mkdir -p .ssh'
                cat /home/$USER/.ssh/sub_node.pub | sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$SUBNODE 'cat >> /home/'$USER'/.ssh/authorized_keys'
        done
        sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'chmod 700 /home/'$USER'/.ssh/'
        sshpass -p $PASS ssh -o ConnectTimeout=2 $USER@$NAME 'chmod 640 /home/'$USER'/.ssh/authorized_keys'
done

cp ~/.ssh/authorized_keys /home/$USER/.ssh/authorized_keys
chown azureuser:azureuser /home/$USER/.ssh/*
rm /home/$USER/bin/install-cn.sh
source /home/$USER/bin/clusRun.sh $USER /home/$USER/install-cn.sh

chmod +x install-fluent.sh
source install-fluent.sh $USER


