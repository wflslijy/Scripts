#!/bin/bash -xe
#
#######################################################
##                  Journal Migration                ##
#######################################################
#
#This is tested in CentOS 7.*
#Description: Migrate journal to ssd v1.0
#Useage: sh migrate_journal.sh ${JOURNAL_DISK}
#${JOURNAL_DISK}: sd[b-z] base on real situation
#Email: wflslijy@gmail.com
#Author: Jy L


echo "#######################################################"
echo "##                  Journal Migration                ##"
echo "#######################################################"

JOURNAL_DISK=$1
OSD_NUM=`lsblk |grep /var/lib/ceph/osd/ |wc -l`
OSD_ID=(`lsblk |grep /var/lib/ceph/osd/ |awk -F '-' '{print $2}'`)
PART_UUID=(`blkid |grep ${JOURNAL_DISK} |awk -F '"' '{print $4}'`)


# Funcs =============================================

#Change permission ceph:ceph for journal disks
function permission(){
    for ((i = 1; i <= ${OSD_NUM}; i++))
    do
    DISK=/dev/${JOURNAL_DISK}${i}
        chown ceph:ceph ${DISK}
    done

}

#Journal disks migration 
function migration {
    for ((i = 0; i < ${OSD_NUM}; i++))
    do
        ceph-osd -i ${OSD_ID[$i]} --flush-journal
        sleep 1
        rm /var/lib/ceph/osd/ceph-${OSD_ID[$i]}/journal
        sleep 1
        ln -s /dev/disk/by-partuuid/${PART_UUID[$i]} /var/lib/ceph/osd/ceph-${OSD_ID[$i]}/journal
        sleep 1
        echo  ${PART_UUID[$i]} >/var/lib/ceph/osd/ceph-${OSD_ID[$i]}/journal_uuid
        sleep 1
        ceph-osd -i ${OSD_ID[$i]} --mkjournal
        sleep 1
    done
}
# Body ==============================================

permission

#Set noout noscrub nodeep-scrub 
#Make sure less influence during migration
ceph osd set noout
ceph osd set noscrub
ceph osd set nodeep-scrub

systemctl stop ceph-osd.target
sleep 1
systemctl status ceph-osd.target

migration
sleep 1

systemctl start ceph-osd.target
sleep 1
systemctl status ceph-osd.target

#Reset noout noscrub nodeep-scrub
ceph osd unset noout
ceph osd unset noscrub
ceph osd unset nodeep-scrub
