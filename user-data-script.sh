#!/bin/bash

# Define Variables for Zabbix Agent
ZabbixServerIP1="10.140.241.214"
ZabbixServerIP2="10.140.241.35"
ZabbixServerIP3="10.141.26.206"
ZabbixServerIP4="10.141.26.199"
DomainName="example.local" # Update with your domain
ZabbixProxy="zabbix-proxy.example.local" # Update with your Zabbix Proxy
ServerActive="$ZabbixServerIP1;$ZabbixServerIP2;$ZabbixServerIP3;$ZabbixServerIP4"
Server="$ZabbixServerIP1,$ZabbixServerIP2,$ZabbixServerIP3,$ZabbixServerIP4"

# Define Variables for Cortex Agent
squid_server="your_squid_server_address"
proxy="your_proxy_address"
cortex_agent_source="/home/ec2-user/FIS-Linux-7_7_2_66464.zip" # Update with your Cortex Agent source path
cortex_rpm_path="/etc/panw/cortex-7.7.2.66464.rpm" # Update with your Cortex RPM path

# Define Variables for AD Client
ldap_server="ldap://UKDC1-OC-ADC01.worldpaypp.local ldap://UKDC2-OC-ADC01.worldpaypp.local"
ssh_config_path="/path/to/sshd_config" # Update with your SSHD config path
sssd_config_path="/path/to/pickenv-sssd.conf" # Update with your SSSD config path
sudoers_file_path="/path/to/20-infra-ped-admin-users" # Update with your sudoers file path
certs_glob_path="/path/to/pickenv_certs/*.pem" # Update with your certs path glob

# Install and Configure Zabbix Agent
echo "Installing and Configuring Zabbix Agent..."
sudo rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm
sudo yum clean all
sudo yum install -y zabbix-agent
sudo tee /etc/zabbix/zabbix_agentd.conf > /dev/null <<EOT
Server=$Server
ServerActive=$ServerActive
Hostname=$(hostname)
EOT
sudo systemctl start zabbix-agent
sudo systemctl enable zabbix-agent

# Install and Configure Cortex Agent
echo "Installing and Configuring Cortex Agent..."
if [ ! -d "/etc/panw" ]; then
    sudo mkdir -p /etc/panw
    sudo chmod 0755 /etc/panw
fi
if [ ! -f "/etc/panw/cortex.conf" ]; then
    sudo touch /etc/panw/cortex.conf
fi
if ! grep -q "export YUM_PROXY=$squid_server" ~/.bashrc; then
    echo "export YUM_PROXY=$squid_server" >> ~/.bashrc
fi
sudo cp $cortex_agent_source /etc/panw
sudo tar -xzf $cortex_agent_source -C /etc/panw
if ! rpm -q cortex-agent; then
    sudo yum install $cortex_rpm_path -y
else
    sudo yum reinstall $cortex_rpm_path -y
fi
sudo /opt/traps/bin/cytool proxy set "${proxy}"
sudo /opt/traps/bin/cytool runtime stop all
sleep 30
sudo /opt/traps/bin/cytool runtime start all
sudo /opt/traps/bin/cytool last_checkin

# Install and Configure AD Client
echo "Installing and Configuring AD Client..."
yum install -y openldap-clients pam_ldap nss-pam-ldapd sssd sssd-client
if [ -f /etc/centos-release ] || [ -f /etc/system-release ]; then
    yum install -y libselinux-python
    setenforce 0
fi
authconfig --enableshadow --enablecache --disablekrb5 --enableforcelegacy --ldapbasedn "dc=worldpaypp,dc=local" --ldapserver "$ldap_server" --update
authconfig --enablesssd --enablesssdauth --enablelocauthorize --enablemkhomedir --update
cp $ssh_config_path /etc/ssh/sshd_config
cp $sssd_config_path /etc/sssd/sssd.conf
cp $sudoers_file_path /etc/sudoers.d/20-infra-ped-admin-users
chmod 0440 /etc/sudoers.d/20-infra-ped-admin-users
visudo -cf /etc/sudoers
if [ -f /etc/centos-release ] || [ -f /etc/system-release ]; then
    cp $certs_glob_path /etc/openldap/cacerts/
    sed -i 's/^ldap_tls_cacertdir.*/ldap_tls_cacertdir = \/etc\/openldap\/cacerts/' /etc/sssd/sssd.conf
    cacertdir_rehash /etc/openldap/cacerts/
else
    cp $certs_glob_path /etc/openldap/certs/
    openssl rehash /etc/openldap/certs/
fi
chown root:root /etc/sssd/sssd.conf
chmod 400 /etc/sssd/sssd.conf
systemctl stop sssd
rm -f /var/lib/sss/db/* /var/log/sssd/*
authconfig --updateall --disableldap --disableldapauth
systemctl start sssd
systemctl enable sssd
systemctl restart sshd

echo "Installation and Configuration of Zabbix Agent, Cortex Agent, and AD Client complete."
