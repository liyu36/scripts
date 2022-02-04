#!/usr/bin/env bash
__Author__="liy"

set -e
source /etc/profile
export ETCDCTL_API=3

# backup etcd
function backup(){
	endpoints=${ETCD_ENDPOINTS-"https://127.0.0.1:2379"}
	cacert=${ETCD_CACERT-"/etc/kubernetes/pki/etcd/ca.crt"}
	cert=${ETCD_CERT-"/etc/kubernetes/pki/etcd/server.crt"}
	key=${ETCD_KEY-"/etc/kubernetes/pki/etcd/server.key"}
	dbfile=${ETCD_DB_FILE-"/data/etcd-backup/etcd-snap-$(date +%F-%H-%M-%S).db"}	
	
	if [ -d "${dbfile%/*}" ];then
		if [ "$now" != "true" ];
		then
			echo -e "\033[32m10 seconds of backup !!!\033[0m";sleep 10
		fi
		# backup
		etcdctl snapshot save \
			${dbfile} \
			--endpoints=${endpoints} \
			--cacert=${cacert} \
			--cert=${cert} \
			--key=${key} |tee /tmp/backup-etcd.log
		
		if [ $? -eq 0 ];then
			echo -e "\033[32mThe backup successful!!!\033[0m"
			exit 0
		fi
	else
		echo -e "\033[31m${dbfile%/*} does not exist or is not a directory\033[0m"
		exit 127
	fi
}

# restore etcd
function restore(){
	date="$(date +%F-%H-%M-%S)"
	manifest_dir=${MANIFEST_DIR-"/etc/kubernetes/manifests"}
	etcd_data_dir=${ETCD_DATA_DIR-"/var/lib/etcd"}
	dbfile=${ETCD_DB_FILE-"$(ls -tr /data/etcd-backup/etcd-snap-*.db|tail -1)"}
	
	echo -e "\033[32mUse the ${dbfile} file for recovery\033[0m"
	if read -p "Are you sure? (Enter/Ctrl+C) " 
	then
		# 停止相关组件
		if [ "$now" != "true" ];
		then
			echo -e "\033[31mTo stop \n$(for i in $(ls ${manifest_dir}); do echo "\t${i%%.*}"; done)\nwait 10 seconds!\033[0m";sleep 10
		else
			echo -e "\033[31mTo stop \n$(for i in $(ls ${manifest_dir}); do echo "\t${i%%.*}"; done)\n\033[0m"
		fi
		echo -e "\033[31mMove ${manifest_dir} to ${manifest_dir}-${date}"
		mv ${manifest_dir} ${manifest_dir}-${date}
		# 对现有 etcd 数据进行备份
		echo -e "\033[31mMove ${etcd_data_dir} to ${etcd_data_dir}-${date}\033[0m"
		mv ${etcd_data_dir} ${etcd_data_dir}-${date}

		# 恢复 etcd 数据
		etcdctl snapshot restore ${dbfile} --data-dir=${etcd_data_dir}

		# 启动相关组件
		mv ${manifest_dir}-${date} ${manifest_dir}
	else 
	    echo "bye"
		exit 0 
	fi
}

TEMP=`getopt -o brnha:c:k:f:e:m:d: --long backup,restore,now,help,cacert:,cert:,key:,dbfile:,endpoints:,manifest:,datadir: -- "$@"`
eval set -- "${TEMP}"
while true;do
	case "$1" in 
	-b|--backup)
		# etcd 备份
		job="backup"
		shift
		;;
	-r|--restore)
		# etcd 恢复
		job="restore"
		shift 
		;;
	-n|--now)
		# 马上执行
		now="true"
		shift
		;;
	-a|--cacert)
		# etcd ca cert
		ETCD_CACERT="$2"
		shift 2
		;;
	-c|--cert)
		# etcd server cert
		ETCD_CERT="$2"
		shift 2
		;;
	-k|--key)
		# etcd server key
		ETCD_KEY="$2"
		shift 2
		;;
	-f|--dbfile)
		# etcd backup file
		ETCD_DB_FILE="$2"
		shift 2
		;;
	-e|--endpoints)
		# etcd endponits
		ETCD_ENDPOINTS="$2"
		shift 2
		;;
	-m|--manifest)
		# kubeadm deploy k8s manifest file directory.
		MANIFEST_DIR="$2"
		shift 2
		;;
	-d|--datadir)
		# etcd data directory.
		ETCD_DATA_DIR="$2"
		shift 2
		;;
	--)
		shift
		break
		;;
	--help|-h)
		echo -e "$0 <-b,--backup|-r,--restore> [-n,--now]
        -b|--backup  # backup etcd!
                -e|--endpoints <etcd-endponits>
                -a|--cacert <etcd-ca-cert>
                -c|--cert <etcd-server-cert>
                -k|--key <etcd-server-key>
                -f|--dbfile <etcd-backup-file>
        -r|--restore # recovery etcd!
                -d|--datadir <etcd-data-directory>
                -m|--manifest <k8s component manifest directory>
                -f|--dbfile <etcd-backup-file>
        -n|--now         # Run now! 
        -h|--help
"
		shift 
		;;
	*) 
		echo "Internal error!"
		exit 1 ;;
	esac
done


case "$job" in
	backup)
		backup
		;;
	restore)
		restore
		;;
esac
