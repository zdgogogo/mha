#!/bin/bash
###获取损坏的master ip
w_master=`awk '/is not reachable!/{print}' manager.log|awk 'END{print $9}'|cut -b 1-12`
###获取w_master的长度
length=${#w_master}
if [ $length -eq 0 ];then
	echo "无主库损坏。"&&exit
fi
###获取新的master ip
r_master=`awk '/^Master failover to/{print}' manager.log|awk 'END{print $4}'|cut -b 1-12`
master_ssh=`ssh $r_master "mysql -uroot -p123456 -e 'show master status'"`
###获取新的主库的binlog文件
master_v1=`echo $master_ssh|awk '{print $6}'`
###获取新的主库的pos
master_v2=`echo $master_ssh|awk '{print $7}'`
###到损坏的master上重启服务并加入到当前的主库中
ssh $w_master "systemctl restart mysqld&&mysql -uroot -p123456 -e 'change master to master_host=\"$r_master\",master_user=\"repl\",master_password=\"123456\",master_log_file=\"$master_v1\",master_log_pos=$master_v2;start slave'"
###把损坏的master加入app1.cnf中
for i in {1..3}
do
grep server$i /etc/mha/app1.cnf
if [ $? -ne 0 ];then
echo "
[server$i]
candidate_master=1
hostname=$w_master
" >> /etc/mha/app1.cnf
fi
done
###删除该日志文件，不然再次启用会有问题
rm -rf /etc/mha/manager.log
###重新挂启mha_manager
masterha_manager --conf=/etc/mha/app1.cnf --remove_dead_master_conf --ignore_last_failover

