#!/bin/bash
#系统检测
OS_CHECK(){
	##系统版本检测
	OS_SYSTEM_CHECK(){
		if [ -e /etc/readhat-release ];then
			READHAT=$(awk '{printf $1}' /etc/readhat-release)
		elif [ -e /etc/centos-release ];then
			READHAT=$(awk '{printf $1}' /etc/centos-release)
		else
			DEBIAN=$(awk '{printf $1}' /etc/issue)
		fi
		if [ $READHAT == CentOS -o $READHAT == Red ];then
			P_M=yum
		elif [ $DEBIAN == Ubuntn -o $DEBIAN == ubuntn ];then
			P_M=apt-get
		else
			exit 1
		fi
	}

	##系统用户检测
	OS_USER_CHECK(){
		if [ $LOGNAME != root ];then
			exit 2
		fi
	}

	##网络检测
	OS_NETWORK_CHECK(){
		timeout=1
		target=www.baidu.com
		ret_code=$(curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1)
		if [ "$ret_code" != "200" ]; then
			exit 3
		fi
	}
	OS_SYSTEM_CHECK
	OS_USER_CHECK
	OS_NETWORK_CHECK
}

#防火墙检测删除
OS_FIREWALL_DEFAULT(){
	systemctl  stop firewalld.service
	systemctl  disable  firewalld.service >> /dev/null 2>&1
	sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0
	service network restart
}

#yum源检测安装
OS_REPO_DEFAULT(){
	rm -rf /root/repo_old
	mkdir -p /root/repo_old
	mv -f /etc/$P_M.repos.d/* /root/repo_old
	curl http://mirrors.163.com/.help/CentOS7-Base-163.repo -o /etc/$P_M.repos.d/CentOS7-Base-163.repo
	curl http://mirrors.aliyun.com/repo/epel-7.repo -o /etc/$P_M.repos.d/epel-7.repo
	$P_M clean all
	$P_M repolist
}

#DOCKER检测
DOCKER_CACHE1(){
	if which docker &> /dev/null;then
		exit 4
	fi
}
DOCKER_CACHE2(){
	if ! which docker &> /dev/null;then
		exit 5
	fi
}
DOCKER_CACHE3(){
	registry=$(docker ps -a | grep -o 'registry')
	if [ "x$registry" != "x" ];then
		exit 6
	fi
}
DOCKER_CACHE4(){
	harbor=$(docker ps -a | grep -o 'harbor')
	if [ "x$harbor" != "x" ];then
		exit 7
	fi
}

#DOCKER安装
DOCKER(){
	##检测基础软件安装
	OS_SOFTWARE_CHECK_DEFAULT(){
		if ! which netstat &> /dev/null;then
			echo "netstat commadn not found,now the install"
			sleep 1
			$P_M -y install net-tools
			echo "----------------------------------------------------------"
		fi
		if ! which wget &> /dev/null;then
			echo "wget commadn not found,now the install"
			sleep 1
			$P_M -y install wget
			echo "----------------------------------------------------------"
		fi
		if ! which git &> /dev/null;then
			echo "git commadn not found,now the install"
			sleep 1
			$P_M -y install git
			echo "----------------------------------------------------------"
		fi
		if ! which vim &> /dev/null;then
			echo "vim commadn not found,now the install"
			sleep 1
			$P_M -y install vim
			echo "----------------------------------------------------------"
		fi
		if ! which unzip &> /dev/null;then
			echo "unzip commadn not found,now the install"
			sleep 1
			$P_M -y install unzip
			echo "----------------------------------------------------------"
		fi
		if ! which rz &> /dev/null;then
			echo "lrzsz commadn not found,now the install"
			sleep 1
			$P_M -y install lrzsz
			echo "----------------------------------------------------------"
		fi
		if ! which htop &> /dev/null;then
			echo "htop commadn not found,now the install"
			sleep 1
			$P_M -y install htop
			echo "----------------------------------------------------------"
		fi
		$P_M -y install iptables-services
		echo "----------------------------------------------------------"
		#$P_M -y update
	}

	##路由转发
	OS_ROUTER_DEFAULT(){
		$P_M -y install iptables-services
		cat >/etc/sysctl.conf <<-EOF
		net.ipv4.ip_forward = 1
		net.ipv4.conf.default.rp_filter = 0
		net.ipv4.conf.all.rp_filter = 0
		EOF
		sysctl -p
		systemctl restart iptables
		systemctl enable iptables
		iptables -F
		iptables -X
		iptables -Z
		/usr/sbin/iptables-save
	}

	##DOCKER安装
	DOCKER_INSTALL(){
		rm -rf /root/download
		mkdir -p /root/download
		wget -P /root/download https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.03.0.ce-1.el7.centos.x86_64.rpm
		wget -P /root/download https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-selinux-17.03.0.ce-1.el7.centos.noarch.rpm
		$P_M install -y /root/download/*
		systemctl start docker
		systemctl enable docker
		cp /lib/systemd/system/docker.service /etc/systemd/system/docker.service
		chmod 777 /etc/systemd/system/docker.service
		sed -i 's!ExecStart=.*!ExecStart=/usr/bin/dockerd --registry-mirror=https://kx68dhpj.mirror.aliyuncs.com!g' /etc/systemd/system/docker.service
		systemctl daemon-reload
		systemctl restart docker
		ps -ef | grep docker
		docker run hello-world
	}
	OS_SOFTWARE_CHECK_DEFAULT
	OS_ROUTER_DEFAULT
	DOCKER_INSTALL
}

#DOCKER扩展
DOCKER_PRO(){
	curl -L https://get.daocloud.io/docker/compose/releases/download/1.25.4/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
	chmod 777 /usr/local/bin/docker-compose
}

#IP地址检测(调用)
IP_CHECK(){
    local IP=$1
    VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [ $VALID_CHECK == "yes" ]; then
            return 0
        else
            return 50
        fi
    else
        return 50
    fi
}

#DOCKER普通型仓库安装
DOCKER_HOUSE(){
	read -p "Server(1) or Client(2) or exit:" NUMBER
	if [ "$NUMBER" == "1" ];then
		IP=$(ip a|awk 'NR==9 {printf $2}'|awk 'BEGIN {FS="/"} {print $1}')
		docker run -d -v /opt/registry:/var/lib/registy -p 5000:5000 --restart=always registry
		if [ ! -e /etc/docker/daemon.json ];then
			touch /etc/docker/daemon.json
			cat >/etc/docker/daemon.json <<-EFO
			{	
			"insecure-registries": ["$IP:5000"]
			}
			EFO
		else
			sed -i 's/\".*/&\,"insecure-registries": [\"'$IP':5000\"]/g' /etc/docker/daemon.json
		fi
			systemctl restart docker
			docker ps -a
	elif [ "$NUMBER" == "2" ];then
		while true; do
			read -p "Server IP or exit:" IP
			[ "$IP" == "exit" ] && exit
			IP_CHECK $IP
			[ $? -eq 0 ] && break
		done
		if [ ! -e /etc/docker/daemon.json ];then
			touch /etc/docker/daemon.json
			cat >/etc/docker/daemon.json <<-EFO
			{	
			"insecure-registries": ["$IP:5000"]
			}
			EFO
		else
			sed -i 's/\".*/&\,"insecure-registries": [\"'$IP':5000\"]/g' /etc/docker/daemon.json
		fi
			systemctl restart docker
	else
        	exit
	fi
}
	
#DOCKER增强型仓库安装
DOCKER_HOUSE_PRO(){
	read -p "Server(1) or Client(2) or exit:" NUMBER
	if [ "$NUMBER" == "1" ];then
		while :;do
			read -p "Input your Web address(eg:a.com):" INTERNET
			if [ "$INTERNET" != "" ]; then
				break
			fi
		done
		while :;do
			read -p "Input your Web password:" PASSWORD
			if [ "$INTERNET" != "" ]; then
				break
			fi
		done
		if ! which python &> /dev/null;then
			echo "python commadn not found,now the install"
			sleep 1
			$P_M -y install python
			echo "----------------------------------------------------------"
		fi
		if ! which pip &> /dev/null;then
			echo "pip commadn not found,now the install"
			sleep 1
			$P_M -y install epel-release python-pip
			#pip install --upgrade pip -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
			#pip install docker-compose --ignore-installed requests -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
		#else
			#echo "pip commadn is found,now the update"
			#sleep 1
			#pip install --upgrade pip -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
			#pip install docker-compose --ignore-installed requests -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com
			echo "----------------------------------------------------------"
		fi
		if ! which openssl &> /dev/null;then
			echo "openssl commadn not found,now the install"
			sleep 1
			$P_M -y install openssl
			echo "----------------------------------------------------------"
		fi	
		if ! which docker-compose &> /dev/null;then
			echo "docker-compose commadn not found,now the install"
			sleep 1
			DOCKER_PRO 
			echo "----------------------------------------------------------"
		fi
		if ! which expect &> /dev/null;then
			echo "expect commadn not found,now the install"
			sleep 1
			$P_M -y install expect
			echo "----------------------------------------------------------"
		fi
		
		wget -P /root/download  http://harbor.orientsoft.cn/harbor-1.2.0/harbor-offline-installer-v1.2.0.tgz
		tar -zxvf /root/download/harbor-offline-installer-v1.2.0.tgz -C /usr/local/
		if [ ! -d /data/cert ];then
			mkdir -p /data/cert
		else
			rm -rf /data/cert/*
		fi
		openssl genrsa -out /data/cert/server.key 2048
		expect <<-EOF
		set timeout -1
		spawn openssl req -new -key /data/cert/server.key -out /data/cert/server.csr
		expect "*:"
		send "\r"
		expect "*:"
		send "\r"
		expect "*:"
		send \r"
		expect "*:"
		send "\r"
		expect "*:"
		send "\r"
		expect "*:"
		send "$INTERNET\r"
		expect "*:"
		send "\r"
		expect "*:"
		send "\r"
		expect "*:"
		send "\r"
		expect eof
		EOF
		cp /data/cert/server.key /data/cert/server.key.org
		openssl rsa -in /data/cert/server.key.org -out /data/cert/server.key
		openssl x509 -req -days 365 -sha256 -in /data/cert/server.csr -signkey /data/cert/server.key -out /data/cert/server.crt
		sed -i 's/hostname =.*/hostname = '$INTERNET'/g' /usr/local/harbor/harbor.cfg
		sed -i 's/ui_url_protocol =.*/ui_url_protocol = https/g' /usr/local/harbor/harbor.cfg
		sed -i 's/harbor_admin_password =.*/harbor_admin_password = '$PASSWORD'/g' /usr/local/harbor/harbor.cfg
		/usr/local/harbor/install.sh
		systemctl restart docker
		if [ ! -e /etc/docker/daemon.json ];then
			touch /etc/docker/daemon.json
			cat >/etc/docker/daemon.json <<-EFO
			{	
			"insecure-registries": ["$INTERNET"]
			}
			EFO
		else
			sed -i 's/\".*/&\,"insecure-registries": [\"'$INTERNET'\"]/g' /etc/docker/daemon.json
		fi
		systemctl restart docker
		IP=$(ip a|awk 'NR==9 {printf $2}'|awk 'BEGIN {FS="/"} {print $1}')
		HOSTS=$(awk '/'$IP'/{print $1}' /etc/hosts)
		if [ "x$HOSTS" == "x" ];then
			echo "$IP $INTERNET" >>/etc/hosts
		else
			sed -i 's/'$IP'.*/'$IP' '$INTERNET'/g' /etc/hosts
		fi
		echo -e "\nYour Web address:$INTERNET"
		echo -e "\nYour Web user:admin"
		echo -e "\nYour Web password:$PASSWORD"	
    elif [ "$NUMBER" == "2" ];then
		while :;do
			read -p "Input your Web address(eg:a.com):" INTERNET
			if [ "$INTERNET" != "" ]; then
				break
			fi
		done
		while true; do
			read -p "Server IP or exit:" IP
			[ "$IP" == "exit" ] && exit
			IP_CHECK $IP
			[ $? -eq 0 ] && break
		done
		if [ ! -e /etc/docker/daemon.json ];then
			touch /etc/docker/daemon.json
			cat >/etc/docker/daemon.json <<-EFO
			{	
			"insecure-registries": ["$INTERNET"]
			}
			EFO
		else
			sed -i 's/\".*/&\,"insecure-registries": [\"'$INTERNET'\"]/g' /etc/docker/daemon.json
		fi
			systemctl restart docker
			HOSTS=$(awk '/'$IP'/{print $1}' /etc/hosts)
		if [ "x$HOSTS" == "x" ];then
			echo "$IP $INTERNET" >>/etc/hosts
		else
			sed -i 's/'$IP'.*/'$IP' '$INTERNET'/g' /etc/hosts
		fi
	else
        	exit
	fi
}

#DOCKER卸载
DOCKER_UNSTALL(){
	$P_M -y remove $(rpm -qa|grep docker)
	rm -rf $(find / -name docker*) &>> /dev/null
	$P_M remove -y 2:container-selinux-2.107-3.el7.noarch
}

#MAIN函数(可随意根据模块组装)
MAIN1(){
	OS_CHECK
}

MAIN2(){
	OS_CHECK
	OS_FIREWALL_DEFAULT
}

MAIN3(){
	OS_CHECK
	OS_FIREWALL_DEFAULT
	OS_REPO_DEFAULT
}

MAIN4(){
	DOCKER_CACHE1
	OS_CHECK
	OS_FIREWALL_DEFAULT
	OS_REPO_DEFAULT
	DOCKER
}

MAIN5(){
	DOCKER_CACHE2
	OS_CHECK
	DOCKER_PRO
}

MAIN6(){
	DOCKER_CACHE2
	DOCKER_CACHE4
	DOCKER_CACHE3
	OS_CHECK
	DOCKER_HOUSE
}

MAIN7(){
	DOCKER_CACHE2
	DOCKER_CACHE4
	DOCKER_CACHE3
	OS_CHECK
	DOCKER_HOUSE_PRO
}

MAIN8(){
	DOCKER_CACHE2
	OS_CHECK
	DOCKER_UNSTALL
}
HELP(){
	echo '-a		系统检测'
	echo -e "\n"
	echo '-b		防火墙检测删除'
	echo -e "\n"
	echo '-c		yum源检测安装'
	echo -e "\n"
	echo '-d		DOCKER安装'
	echo -e "\n"
	echo '-e		DOCKERPRO安装'
	echo -e "\n"
	echo '-f		DOCKER普通型仓库安装'
	echo -e "\n"
	echo '-g		DOCKER增强型仓库安装'
	echo -e "\n"
	echo '-h		查看帮助'
	echo -e "\n"
	echo '-i		DOCKER卸载'
	echo -e "\n"
}
#MAIN函数(可随意根据模块组装)

#菜单
[ "x$2" == "x" ] || echo "Try 'dockerfly -h' for more information."
[ "x$2" == "x" ] || exit
case $1 in
	'-a')
		MAIN1
		;;
	'-b')
		MAIN2
		;;
	'-c')
		MAIN3
		;;
	'-d')
		MAIN4
		;;
	'-e')
		MAIN5
		;;
	'-f')
		MAIN6
		;;
	'-g')
		MAIN7
		;;
	'-h')
		HELP
		;;
	'-i')
		MAIN8
		;;
	*)
		echo "Try 'dockerfly -h' for more information."
		;;
esac
#菜单
