
## gcp-terraform


```bash
For Mac ssh with agent

# aad the following .ssh/config
Host *
  StrictHostKeyChecking no
  ForwardAgent yes

# make sure ssh-agent running
ssh-agent

# add the private key to the chain
ssh-add -K ~/.ssh/id_rsa

ssh username@gcp_public_ip

```

##
```bash
#find package version
apt-cache policy  ansible
```
