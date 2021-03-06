#!/bin/bash

#*****************************************************************************************
#用例名称：NIC_BASIC_MAC_002
#用例功能：网口MAC地址设置功能测试
#作者：hwx653129
#完成时间：2019-1-25

#前置条件：
# 	1.单板启动正常
# 	2.所有网口各模块加载正常

#测试步骤：
# 	1.网口正常初始化后，调用命令“ifconfig ethx hw ether xx:xx:xx:xx:xx:xx”，配置新的MAC地址
# 	2.配置mac地址后查询（ifconfig ethx）

#测试结果:
# 	1 .设置MAC地址成功，结果与配置的一致                                                   
#*****************************************************************************************

#加载公共函数,具体看环境对应的位置修改
. ../../../../utils/error_code.inc
. ../../../../utils/test_case_common.inc
. ../../../../utils/sys_info.sh
. ../../../../utils/sh-test-lib
#. ./utils/error_code.inc
#. ./utils/test_case_common.inc
#获取脚本名称作为测试用例名称
test_name=$(basename $0 | sed -e 's/\.sh//')
#创建log目录
TMPDIR=./logs/temp
mkdir -p ${TMPDIR}
#存放脚本处理中间状态/值等
TMPFILE=${TMPDIR}/${test_name}.tmp
#存放每个测试步骤的执行结果
RESULT_FILE=${TMPDIR}/${test_name}.result

#自定义变量区域（可选）
#var_name1="xxxx"
#var_name2="xxxx"
test_result="pass"
#************************************************************#
# Name        : find_physical_card                                        #
# Description : 查询物理网卡                                 #
# Parameters  : 无           #
# return value：total_network_cards[]
#************************************************************#
function find_physical_card(){
	total_network_cards=(`ls /sys/class/net/`)
	virtual_network_cards=(`ls /sys/devices/virtual/net/`)
	len_total=${#total_network_cards[@]}
	len_virtual=${#virtual_network_cards[@]}
	
	#去除非目录文件
	for ((i=0;i<${len_total};i++))
	do
		if [ ! -d "/sys/class/net/${total_network_cards[i]}" ]; then
			unset total_network_cards[i]
			total_network_cards=(`echo ${total_network_cards[@]}`)
		fi	
	done

	#去除非目录文件
	for ((i=0;i<${len_virtual};i++))
	do
		if [ ! -d "/sys/devices/virtual/net/${virtual_network_cards[i]}" ]; then
			unset virtual_network_cards[i]
			virtual_network_cards=(`echo ${virtual_network_cards[@]}`)
		fi	
	done

	#去除虚拟网卡
	for ((i=0;i<${len_total};i++))
	do
		for ((j=0;j<${len_virtual};j++))
		do
			if [ "${total_network_cards[i]}" == "${virtual_network_cards[j]}" ]; then
				unset total_network_cards[i]				
				break
			fi
		done	
	done
	total_network_cards=(`echo ${total_network_cards[@]}`)
	
	for net in ${virtual_network_cards[@]}
	do
		PRINT_LOG "INFO" "please check this $net port"
	done	
}
#************************************************************#
# Name        : verify_network_module                        #
# Description : 确认网络模块                                 #
# Parameters  : 无
# return      : 无                                      #
#************************************************************#
function verify_network_module(){
	#查找所有物理网卡
	#find_physical_card
	#保存所有网卡驱动
	
	for ((i=0;i<${#total_network_cards[@]};i++))
	do
		driver[i]=`ethtool -i ${total_network_cards[i]} | grep driver | awk '{print $2}'`
	done
	
	#删除重复驱动
	len=${#driver[@]}
	#控制循环次数
	for ((i=0;i<${len}-1;i++))
	do
		#与下一个元素比较，直到最后一个相同则删除
		for ((j=i+1;j<${len};j++))
		do
			if [ "${driver[i]}" == "${driver[j]}" ]; then
				unset driver[i]
				break
			fi
		done
	done
	driver=(`echo ${driver[@]}`)
	
	for d in ${driver[@]}
	do
		if [ ! $d ];then
			PRINT_LOG "FATAL" "some error or fail with this $d module"
			fn_writeResultFile "${RESULT_FILE}" "$d module error or fail" "fail"
			return 1
		else
			PRINT_LOG "INFO" "This $d module is normal"
			fn_writeResultFile "${RESULT_FILE}" "$d module normal" "pass"
		fi
	done
}
#************************************************************#
# Name        : pre_mac                        #
# Description : 获取原先mac地址                                 #
# Parameters  : 无
# return      : 无                                      #
#************************************************************#
function pre_mac(){
	for ((i=0;i<${#total_network_cards[@]};i++))
	do
		mac[i]=`ifconfig ${total_network_cards[i]} | grep "ether" | awk '{print $2}'`	
		#ethtool -P $net | awk '{print $3}'
	done
}
#************************************************************#
# Name        : restore_mac                        #
# Description : 恢复mac地址                                 #
# Parameters  : 无
# return      : 无                                      #
#************************************************************#
function restore_mac(){
	for ((i=0;i<${#total_network_cards[@]};i++))	
	do
		ifconfig ${total_network_cards[i]} hw ether ${mac[i]}
		
	done
}


#预置条件
function init_env()
{
    #检查结果文件是否存在，创建结果文件：
    fn_checkResultFile ${RESULT_FILE}
    
    #root用户执行
    if [ `whoami` != 'root' ]
    then
        PRINT_LOG "WARN" " You must be root user " 
        return 1
    fi
	ifconfig -h
	if [ $? -eq 0 ]
	then
		PRINT_LOG "INFO" " exec<ifconfig -h> is scuccess"
	else
		fn_install_pkg "net-tools" 10
		if [ $? -eq 0 ]
		then
			PRINT_LOG "INFO" "install net-tool is scuccess "
		else
			PRINT_LOG "FATAL" "install net-tool is fail"
		fi
	fi
	fn_install_pkg "ethtool" 10
	find_physical_card
	verify_network_module
	pre_mac
    #自定义测试预置条件检查实现部分：比如工具安装，检查多机互联情况，执行用户身份 
      #需要安装工具，使用公共函数install_deps，用法：install_deps "${pkgs}"
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"
}





#测试执行
function test_case()
{
	tmp_mac="00:18:85:00:00:4e"
	#给网口配置新的MAC地址
	for net in ${total_network_cards[@]}
	do
		#PRINT_LOG "INFO" "please check this $net port"
		ifconfig $net hw ether $tmp_mac
		PRINT_LOG "INFO" " exec<ifconfig $net hw ether $tmp_mac> is scuccess"
		aft_mac=$(ifconfig  $net |grep "ether"|awk '{print $2}')
		if [ "${tmp_mac}" == "${aft_mac}" ]
		then 
			PRINT_LOG "INFO" "$net can set up MAC address."
			fn_writeResultFile "${RESULT_FILE}" "modify $net mac address" "pass"
		else
			PRINT_LOG "FATAL" "$net can not set up MAC address, please check it."
			fn_writeResultFile "${RESULT_FILE}" "modify $net mac address" "fail"
		fi
	done
    #检查结果文件，根据测试选项结果，有一项为fail则修改test_result值为fail，
    check_result ${RESULT_FILE}
}

#恢复环境
function clean_env()
{
	restore_mac
    #清除临时文件
    FUNC_CLEAN_TMP_FILE
    #自定义环境恢复实现部分,工具安装不建议恢复
      #需要日志打印，使用公共函数PRINT_LOG，用法：PRINT_LOG "INFO|WARN|FATAL" "xxx"

}


function main()
{
    init_env || test_result="fail"
    if [ ${test_result} = 'pass' ]
    then
        test_case || test_result="fail"
    fi
    clean_env || test_result="fail"
	[ "${test_result}" = "pass" ] || return 1
}

main $@
ret=$?
#LAVA平台上报结果接口，勿修改
lava-test-case "$test_name" --result ${test_result}
exit ${ret}
