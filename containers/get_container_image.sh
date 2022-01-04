#!/usr/bin/env bash
# __Author__="liy"
# 根据容器内使用的客户端端口查找对应的镜像标签，使用此脚本即可查询。


port="$1"
function check_env(){
    if [ -z "$port" ];then
        echo -e "\033[31mUsage: $0 <port>\033[0m"
        exit 1
    fi

    which conntrack &>/dev/null
    if [ $? -ne 0 ];then
        echo -e "\033[31myum install conntrack-tools|apt install conntrack\033[0m"
        exit 2
    fi
}

function get_image(){
    ip=$(conntrack -L |grep "$port"|grep -Po "(?<=src\=)[\d.]+"|sort -t"." -k1,1n -k2,2n -k3,3n -k4,4n |uniq|xargs| tr ' ' '|') > /dev/null
    for id in $(docker ps -q)
    do
        docker inspect $id |grep -P "($ip)" &>/dev/null
        if [ $? -eq 0 ];then
            echo -e "\033[32mimage:$(docker ps |grep $id |awk '{print $2}')\033[0m"
        fi
    done
}


function main(){
    check_env
    get_image
}

main
