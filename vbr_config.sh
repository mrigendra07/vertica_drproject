#!/bin/bash
#######################################################################
#			VBR	ini file option configuration
#----------------------------------------------------------------------
# Change item values as per requirement.
# All the values are initially set to default values generated by vbr.py
#######################################################################
sync_dbuser='DRSYNC'

SEC_NAME_MISC='[Misc]'
SEC_NAME_DATABASE='[Database]'
SEC_NAME_PASSWORDS='[Passwords]'
SEC_NAME_MAPPING='[Mapping]'
SEC_NAME_TRANSMISSION='[Transmission]'

snapshotName_item='snapshotName'

dest_verticaBinDir_item='dest_verticaBinDir'
dest_verticaBinDir_val='/opt/vertica/bin'

restorePointLimit_item='restorePointLimit'
restorePointLimit_val='1'

objects_item='objects'

objectRestoreMode_item='objectRestoreMode'
objectRestoreMode_val='createOrReplace'

tempDir_item='tempDir'
tempDir_val='/tmp/vbr'

retryCount_item='retryCount'
retryCount_val='2'

retryDelay_item='retryDelay'
retryDelay_val='1'

dbName_item='dbName'
dbUser_item='dbUser'
dest_dbName_item='dest_dbName'
dest_dbUser_item='dest_dbUser'
dbPassword_item='dbPassword'
dest_dbPassword_item='dest_dbPassword'

encrypt_item='encrypt'
encrypt_val='False'

checksum_item='checksum'
checksum_val='True'

port_rsync_item='port_rsync'
port_rsync_val='50000'

serviceAccessUser_item='serviceAccessUser'
serviceAccessUser_val='None'

total_bwlimit_backup_item='total_bwlimit_backup'
total_bwlimit_backup_val='0'

concurrency_backup_item='concurrency_backup'
concurrency_backup_val='4'

concurrency_restore_item='concurrency_restore'
concurrency_restore_val='4'

total_bwlimit_restore_item='total_bwlimit_restore'
total_bwlimit_restore_val='0'