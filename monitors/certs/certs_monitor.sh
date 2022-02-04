#!/usr/bin/env bash
__Author__="liy"

source /etc/profile
INNER_PATH=$(cd "$(dirname "$0")";pwd)
LOCAL_IP="$(ip addr show eth0 |grep -Po '(?<=inet )[0-9.]+')"

# 发送钉钉告警
function DingDing(){
    curl -s 'https://oapi.dingtalk.com/robot/send?access_token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' \
    -H 'Content-Type: application/json' \
    -d '{"msgtype": "text",
        "text": {
        "content":" '$1' "
        },
        "at": {
        "atMobiles": [
            "186xxxxxxxx",
        ],
        "isAtAll": false
        }
        }'
}

function checkCerts(){
    host=$1

    SSL_OVER_TIMESTAMP=$(date +%s -d "$(echo |openssl s_client -servername ${host} -connect ${host}:443 2>/dev/null | openssl x509 -noout -enddate|grep -Po "(?<=After=).*(?=GMT)")")
    NOW_TIMESTAMP=$(date +%s)
    OVER_TIMESTAMP=$(echo ${SSL_OVER_TIMESTAMP} - ${NOW_TIMESTAMP} | bc)
    OVER_DAYS=$(echo ${OVER_TIMESTAMP} / 86400 | bc)
    echo "$host $OVER_DAYS" > /tmp/certs_monitor.sh

    if [ $OVER_DAYS -le 60 ];then
        text="${host}的证书将于${OVER_DAYS}天后过期，注意续费和配置更新! \n报警源:${LOCAL_IP}"
        DingDing ${text}
    fi
}

function main(){
    for line in $(cat ${INNER_PATH}/certs.txt)
    do
        checkCerts $line
    done
}
