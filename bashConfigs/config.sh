#!/bin/bash

base_path="/usr/bin/db-driver"
php_exe_path="/usr/bin/php"

# defining main database access details
main_db_host='192.168.2.71'
db_username='educeit'
db_password='educeit'
main_database='iwnasp'
main_sys_database='akken_sysdb'

# Version of companies
default_version="production";
version_clause=" AND company_info.version='$default_version'";

sensehq_cand_limit_count=500
exitcode=0

sync_started='Sync started'
sync_started_message='Sync has been started. Please check below details'
sync_completed='Sync completed'
sync_completed_message='Total sync has been completed. Please check below details'
sync_issue='Issue came while sync for SenseHQ'
sync_message='Issue came while sync for SenseHQ data. Please check below details'
