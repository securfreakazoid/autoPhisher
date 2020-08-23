#!/bin/bash
hostname="$1"

#Setting up the hostname
hostname "$hostname"
echo "$hostname" > /etc/hostname
sed -i "s/127.0.0.1 localhost/127.0.0.1 localhost $hostname/g" /etc/hosts

#Setting up automated postfix install
#https://serverfault.com/questions/143968/automate-the-installation-of-postfix-on-ubuntu
debconf-set-selections <<< "postfix postfix/mailname string $hostname"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install --assume-yes postfix 
sed -i "s/myhostname = .*/myhostname = $hostname/g" /etc/postfix/main.cf
apt-get install opendkim opendkim-tools mailutils

#Things to lower your spam rating

#SPF
echo "Add the following to your dns record:"
echo "A record for mail.$hostname pointing to $hostname's ip"
echo "SPF record: "
echo "$hostname 3600 IN TXT \"v=spf1 a:mail.$hostname -all\""

#DKIM
#Applying opendkim config according to https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy
echo "Updating /etc/opendkim.conf"

echo "AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes
Canonicalization        relaxed/simple
ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256
UserID                  opendkim:opendkim
Socket                  inet:12301@localhost" >> /etc/opendkim.conf

echo "Configuring the socket in /etc/default/opendkim"
echo "SOCKET=\"inet:12301@localhost\"" >> /etc/default/opendkim

echo "Configuring postfix's milters"
echo "milter_protocol = 2
milter_default_action = accept
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301" >> /etc/postfix/main.cf

echo "Creating the keys"
sudo mkdir /etc/opendkim
sudo mkdir /etc/opendkim/keys
echo "127.0.0.1
localhost
192.168.0.1/24
$hostname

*.$hostname" > /etc/opendkim/TrustedHosts

echo "Creating a KeyTable"
echo "mail._domainkey.$hostname $hostname:mail:/etc/opendkim/keys/$hostname/mail.private" > /etc/opendkim/KeyTable

echo "Creating a SigningTable"
echo "*@$hostname mail._domainkey.$hostname" >  /etc/opendkim/SigningTable

cd /etc/opendkim/keys
sudo mkdir $hostname
cd $hostname
sudo opendkim-genkey -s mail -d $hostname
sudo chown opendkim:opendkim mail.private

echo "Append the following values to your dns:"
echo "Record type: txt
Record host: mail._domainkey
Txt value: everything between parenthesis"
cat mail.txt
