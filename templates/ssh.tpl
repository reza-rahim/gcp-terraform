ssh-add
ssh-agent

ssh root@${bastion_ip}  "echo alias m0=\'f\(\) { ssh kube-master-0 kubectl \"\\\$@\" \;  unset \-f f\; }\; f\'   >> .bashrc"
ssh root@${bastion_ip}  "echo alias m1=\'f\(\) { ssh kube-master-1 kubectl \"\\\$@\" \;  unset \-f f\; }\; f\'   >> .bashrc"
ssh root@${bastion_ip}  "echo alias m2=\'f\(\) { ssh kube-master-2 kubectl \"\\\$@\" \;  unset \-f f\; }\; f\'   >> .bashrc"

ssh root@${bastion_ip}  "echo alias skm0=ssh kube-master-0 -L 9090:localhost:9090  -L 3000:localhost:3000  -L 8080:localhost:8080   >> .bashrc"
ssh root@${bastion_ip}  "echo alias skm1=ssh kube-master-1 -L 9090:localhost:9090  -L 3000:localhost:3000  -L 8080:localhost:8080   >> .bashrc"
ssh root@${bastion_ip}  "echo alias skm2=ssh kube-master-2 -L 9090:localhost:9090  -L 3000:localhost:3000  -L 8080:localhost:8080   >> .bashrc"

#ssh root@${bastion_ip} git clone https://github.com/reza-rahim/kubeadm-ansible
scp ./inventory/inventory.ini root@${bastion_ip}:/root/kubeadm-ansible
scp ./scripts/config  root@${bastion_ip}:/root/.ssh
#ssh root@${bastion_ip} apt update; 
#ssh root@${bastion_ip} apt-get install -y python-pip python-dev; 
#ssh root@${bastion_ip} pip install ansible==2.5  ; 
ssh root@${bastion_ip} echo "kube_master_lb: ${kube_master_lb} >> kubeadm-ansible/group_vars/all/main.yaml" ; 
ssh root@${bastion_ip} echo "sed -i 's/{{ lb }}/${kube_master_lb}/' ~/kubeadm-ansible/group_vars/all/main.yaml";
ssh root@${bastion_ip} mkdir -p /var/klovercloud.com/cache;  
ssh root@${bastion_ip} mount -t tmpfs -o size=1M,mode=0755 tmpfs /var/klovercloud.com/cache ;
ssh root@${bastion_ip} echo "tmpfs  /var/klovercloud.com/cache size=100M,mode=0755 0 0" >> /etc/fstab;

## umount -l /var/klovercloud.com/cache 
ssh root@${bastion_ip} -L 9090:localhost:9090  -L 3000:localhost:3000  -L 8080:localhost:8080 -L 8001:localhost:8001

