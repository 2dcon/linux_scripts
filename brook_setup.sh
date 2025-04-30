#!/bin/bash

#define colors
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
clr=$'\e[0m'

#local path
path='/bin/brook'
fname='brook_linux_amd64'

#get latest release
dlink=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/txthinking/brook/releases/latest/)
latest=$(echo $dlink | tr -dc '0-9')
dlink='https://github.com/txthinking/brook/releases/download/v'$latest'/brook_linux_amd64'

#check bbr
if ! $(sysctl net.ipv4.tcp_congestion_control | grep -q bbr); then
   echo "Would you like to enable BBR? (y/n)"
   read YN
   if [[ $YN == y ]]; then
   	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
	sysctl -p
   fi
fi

if test -f "$path/brook"; then
	current=$($path/brook -v | tr -dc '0-9')
	if (( latest > current )); then
		echo 'New version found, would you like to update?'
		echo $yel$current$clr' -> '$grn$latest$clr
		read YN
		if [[ $YN == y ]]; then
			systemctl stop brook
			cd /temp/
			wget $dlink
			cp -rf $fname /bin/brook/brook
			chmod +x /bin/brook/brook
			rm -f brook_linux_amd64

			systemctl start brook
			
			echo 'Done!'
			exit 0
		fi
	else
		echo 'You have already installed the latest version '$grn$current$clr
	fi
fi


printf "What would you like to do?\n"
printf "$grn\t1.Install Brook\n$clr"
printf "$red\t2.Uninstall Brook$clr"

read OPTION

case $OPTION in
	#install
	1)
		printf "Install Brook?(y/n)"
		read YN
		if [[ $YN != Y && $YN != y ]]; then
			printf "Operation terminated.\n"
		exit 0
		fi
		
		if [ -f /etc/os-release ]; then
			. /etc/os-release
			OS=$ID
			VER=$VERSION_ID
		fi
		
		if [[ $OS == debian || $OS == ubuntu ]]; then
			PM='apt'
		elif [[ $OS == centos ]]; then
			PM='yum'
		fi
		
		#required package
		$PM -y update
		$PM -y install wget
		$PM -y install net-tools

		systemctl stop brook #stop brook if it exists
		
		mkdir /bin/brook
		cd /bin/brook
		#Overwrite if brook exists
		if [[ -f brook ]]; then
			rm brook
		fi

		wget $dlink
		
		mv brook_linux_amd64 brook
		chmod +x brook
		#Create systemd service
		cd /etc/systemd/system/
		printf "Which port would you like to use? (Leave blank for random prot)\n"
		read PORT
		if [[ -z $PORT ]]; then
			PORT=$((10000 + RANDOM % 55536))
		fi

		printf "Set the password (default: 2dcon@github): "
		read PW
		if [[ -z $PW ]]; then
			PW='2dcon@github'
		fi

		#Delete brook.service if it exists
		if [[ -f brook.service ]]; then
			rm brook.service
		fi

		echo "[Unit]
Description=Brook VPN

[Service]
Type=idle
LimitNOFILE=99999
ExecStart=/bin/brook/brook server -l :$PORT -p $PW
SuccessExitStatus=1 143
Restart=on-failure

[Install]
WantedBy=multi-user.target" > brook.service
		
		if [[ $OS==centos ]]; then
			#Add port to firewall
			firewall-cmd --permanent --zone=public --add-port=$PORT/tcp
			firewall-cmd --permanent --zone=public --add-port=$PORT/udp
			firewall-cmd --reload
		fi
		
		systemctl daemon-reload
		systemctl enable brook
		systemctl start brook

		IPADDR="$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')"
		printf "$grn\nInstallation success$clr!
		Server IP: $IPADDR
		Port:      $PORT
		Password:  $PW"
		;;
	
	2)
		printf "Uninstall Brook(y/n)"
		read YN
		if [[ $YN != Y && $YN != y ]]; then
		printf "Operation terminated.\n"
		exit 0
		fi
	systemctl stop brook
	systemctl disable brook
	rm -f /etc/systemd/system/brook.service
	rm -rf /bin/brook
	  ;;
	*)
esac

exit 0
