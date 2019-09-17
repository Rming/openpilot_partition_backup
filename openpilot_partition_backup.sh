#!/usr/bin/env bash

# Author:  rming <rmingwang@gmail.com>
#
# Notes: openpilot partition backup script
#
# Project home page:
#       https://github.com/Rming/openpilot_partition_backup

clear
printf "
########################################################################
#    openpilot 分区镜像一键备份恢复脚本                                 #
#    更多信息 https://doc.sdut.me/cn/openpilot_partition_backup.html    #
########################################################################
"

BACKUP_DIR=/sdcard/PARTITION_BACKUP


# color
echo=echo
for cmd in echo /bin/echo; do
  $cmd >/dev/null 2>&1 || continue
  if ! $cmd -e "" | grep -qE '^-e'; then
    echo=$cmd
    break
  fi
done
CSI=$($echo -e "\033[")
CEND="${CSI}0m"
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"
CSUCCESS="$CDGREEN"
CFAILURE="$CRED"
CQUESTION="$CMAGENTA"
CWARNING="$CYELLOW"
CMSG="$CCYAN"

# mode select
while :; do echo
  echo -e '模式选择:'
  echo -e "\t${CBLUE}1. 备份分区${CEND}"
  echo -e "\t${CBLUE}2. 恢复分区${CEND}"
  read -e -p "请输入序号(默认备份模式)：" mode_flag
  mode_flag=${mode_flag:-1}

  if [[ ! ${mode_flag} =~ ^[1-2]$ ]]; then
    echo -e "\n${CWARNING}请输入正确的序号！[1-2]${CEND}"
  else
    [[ ${mode_flag} == 1 ]] && mode_str="备份" || mode_str="恢复"
    while :; do echo
      echo -e '分区选择:'
      partitions=(`ls -l /dev/block/bootdevice/by-name | tail -n +2| awk '{print $9}'`)
      partition_count=${#partitions[@]}
      for i in "${!partitions[@]}"; do
        echo -e "\t${CBLUE}${i}. ${partitions[$i]}${CEND}"
      done
      read -e -p "请输入序号(默认${mode_str}所有分区)：" partition_select
      partition_select=${partition_select:-"ALL"}

      if [[ ${partition_select} == "ALL" ]]; then
        read -e -p "${CYELLOW}你确认要${mode_str}所有分区么？[y/n]：${CEND}" partition_confirm
        partition_confirm=${partition_confirm:-"y"}
        if [[ "${partition_confirm}" != "y" ]]; then
          continue
        fi

        echo -e "${CYELLOW}跳过 userdata 分区（已跳过）.${CEND}"
        read -e -p "${CYELLOW}跳过 system 分区（默认跳过）？[y/n]:${CEND}" skip_system
        skip_system=${skip_system:-"y"}

        read -e -p "${CYELLOW}跳过 cache 分区（默认跳过）？[y/n]:${CEND}" skip_cache
        skip_cache=${skip_cache:-"y"}
      fi

      if [[ ${partition_select} -lt ${partition_count} ]] && [[ ${partition_select} -ge 0 ]] || [[ ${partition_select} == "ALL" ]]; then
        [[ ${partition_select} == "ALL" ]] && partition_str="所有分区" || partition_str=${partitions[$partition_select]}
        echo -e "${CGREEN}模式：${mode_str}${CEND}"
        echo -e "${CGREEN}分区：${partition_str}${CEND}"
        echo -e "${CGREEN}备份地址：${BACKUP_DIR}${CEND}"
        # 执行前确认
        read -e -p "${CYELLOW}你确认要执行${mode_str}么？[y/n]：${CEND}" run_confirm
        run_confirm=${run_confirm:-"y"}
        if [[ "${run_confirm}" != "y" ]]; then
          break
        fi

        if [ "${mode_flag}" == '1' ]; then
          # 备份
          if [ ! -d "${BACKUP_DIR}" ]; then
            mkdir "${BACKUP_DIR}"
            if [ $? -ne 0 ]; then
              echo -e "${CFAILURE}备份目录创建失败${CEND}"
              break
            else
              echo -e "${CSUCCESS}备份目录创建中...${CEND}"
            fi
          else
            echo -e "${CSUCCESS}备份目录已存在.${CEND}"
          fi

          # 全部还是指定分区
          if [[ "${partition_select}" == "ALL" ]]; then
            partitionsJob=${partitions[@]}
          else
            partitionsJob=(partition_str)
          fi

          for partition_str in ${partitionsJob[@]}; do
            if [[ "${partition_str}" == "userdata" ]]; then
              echo -e "${CSUCCESS}分区 ${partition_str} ${mode_str} 跳过!${CEND}"
              continue
            fi

            if [[ "${skip_system}" == "y" ]] && [[ "${partition_str}" == "system" ]]; then
              echo -e "${CSUCCESS}分区 ${partition_str} ${mode_str} 跳过!${CEND}"
              continue
            fi

            if [[ "${skip_cache}" == "y" ]] && [[ "${partition_str}" == "cache" ]]; then
              echo -e "${CSUCCESS}分区 ${partition_str} ${mode_str} 跳过!${CEND}"
              continue
            fi

            ret=`ls -l /dev/block/bootdevice/by-name | awk '$9 ~ /^'${partition_str}'$/{cmd="dd if="$11" of="BACKUP_DIR"/"$9".img >/dev/null 2>&1";ret=system(cmd);print ret;}' BACKUP_DIR=${BACKUP_DIR}`
            if [ "${ret}" -ne "0" ]; then
              echo -e "${CFAILURE}分区 ${partition_str} ${mode_str} 失败!${CEND}"
              break
            else
              echo -e "${CSUCCESS}分区 ${partition_str} ${mode_str} 成功.${CEND}"
            fi
          done
        else
          # 恢复
          if [ ! -d "${BACKUP_DIR}" ]; then
            echo -e "${CFAILURE}备份目录不存在！请确认后重试.${CEND}"
          else
            echo -e "${CSUCCESS}备份目录检查完毕.${CEND}"
          fi

          if [[ "${partition_select}" == "ALL" ]]; then
            partitionsJob=${partitions[@]}
          else
            partitionsJob=(partition_str)
          fi

          # 全部还是指定分区
          for partition_str in ${partitionsJob[@]}; do
            if [[ "${partition_str}" == "userdata" ]]; then
              echo -e "${CSUCCESS}分区 ${partition_str} ${mode_str} 跳过!${CEND}"
              continue
            fi

            if [[ "${skip_system}" == "y" ]] && [[ "${partition_str}" == "system" ]]; then
              echo -e "${CSUCCESS}分区 ${partition_str} ${mode_str} 跳过!${CEND}"
              continue
            fi

            if [[ "${skip_cache}" == "y" ]] && [[ "${partition_str}" == "cache" ]]; then
              echo -e "${CSUCCESS}分区 ${partition_str} ${mode_str} 跳过!${CEND}"
              continue
            fi
            ret=`ls -l /dev/block/bootdevice/by-name | awk '$9 ~ /^'${partition_str}'$/{cmd="dd if="BACKUP_DIR"/"$9".img of="$11" >/dev/null 2>&1";ret=system(cmd);print ret;}' BACKUP_DIR=${BACKUP_DIR}`
            if [ "${ret}" -ne "0" ]; then
              echo -e "${CFAILURE}分区 ${partition_str} ${mode_str} 失败!${CEND}"
              break
            else
              echo -e "${CSUCCESS}分区 ${partition_str} ${mode_str} 成功.${CEND}"
            fi
          done

        fi
        break
      else
        echo -e "${CWARNING}请输入正确的序号！1-${partition_count}${CEND}"
      fi
    done
    break
  fi
done
