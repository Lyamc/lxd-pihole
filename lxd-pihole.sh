#!/bin/bash

## Don't run twice
## Also, this has not been tested

set -e

function askuser
{
echo ""
echo "Don't run this twice, also, this hasn't been tested."
sleep 1
read -r -p "Do you want to run the install anyways? [y/N]: " responseuser
case "$responseuser" in
		[Yy][Ee][Ss]|[Yy]) # Yes or Y (case-insensitive).
      echo "Installing..."
			;;
		*)  # No or N or empty.
			echo "Exiting..."
      exit
			;;
esac
}


function installlxd
{
sudo apt install curl ufw -y 
sudo snap install lxd
sleep 2
sudo lxd init
sleep 2
}

function installcontainer
{
lxc launch ubuntu:focal pihole
sleep 2
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf 
echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf 
lxc exec pihole -- curl -sSL https://install.pi-hole.net | bash
sleep 1
}

function getip
{
while true; do

	echo ""
	ip addr | grep global | awk '{print NR ") "$2}' OFS='\t'
	echo ""

	read -r -p "Select number (1, 2...): " response1
	IP=$(ip addr | grep global | awk -v var=$response1 'FNR == var {print $2}')
	echo ""
	IFS=. read IP1 IP2 IP3 IP4SUB <<< "$IP"
  IFS=/ read IP4 IPSUB <<< "$IP4SUB"
  IP="$IP1.$IP2.$IP3.$IP4"
  IPSUBFULL="$IP1.$IP2.$IP3.0/$IPSUB"
  IPINTERFACE=$(ip route | grep "$IP" | awk '{print $3}')
  PIHOLEIP=$(lxc list | grep pihole | awk '{print $6}')
  echo "You have selected the following: "
  echo ""
  echo -e "IP:\t $IP1.$IP2.$IP3.$IP4"
  echo -e "Subnet:\t $IPSUBFULL"
  echo -e "Interface: $IPINTERFACE"
  echo ""
  echo "Pihole LXD IP: $PIHOLEIP"
	echo ""


read -r -p "Are you sure? [Y/n]: " response2
	case "$response2" in
		[Yy][Ee][Ss]|[Yy]|"") # Yes or Y (case-insensitive).
			break
			;;
		[Nn][Oo]|[Nn])  # No or N or empty.
			echo ""
			;;
      		*) # Anything else is invalid.
			echo "Invalid response"
			echo ""
			;;
    	esac
done
}

function configurepihole
{
sudo tee -a /etc/ufw/before.rules << RULELIST

# NAT TABLE RULES

*nat :PREROUTING ACCEPT [0:0] 
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -i $IPINTERFACE -p tcp --dport 53 -j DNAT --to-destination $PIHOLEIP 
-A PREROUTING -i $IPINTERFACE -p udp --dport 53 -j DNAT --to-destination $PIHOLEIP 
-A POSTROUTING -s $IPSUBFULL -o eth0 -j SNAT --to-source $IP 

COMMIT
RULELIST

sudo ufw enable

lxc network set lxdbr0 raw.dnsmasq dhcp-option=6,$PIHOLEIP

}

function askreboot
{
echo ""
echo "You need to reboot to apply changes."
sleep 1
read -r -p "Do you want to reboot now? [y/N]: " response2
case "$response2" in
		[Yy][Ee][Ss]|[Yy]) # Yes or Y (case-insensitive).
			echo "Rebooting..."
      sudo reboot
			;;
		*)  # No or N or empty.
			echo "Exiting..."
      exit
			;;
esac
}

askuser
installlxd
installcontainer
getip
configurepihole
askreboot

