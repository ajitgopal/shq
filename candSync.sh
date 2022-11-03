#!/bin/bash
# enable below flag to view detailed process
#set -x

#including configuration file 
config_path="/usr/bin/db-driver/BashConfigs"
source "${config_path}/config.sh"
source "${config_path}/functions.sh"

current_date="$(date +'%Y%m%d')"
sensehq_folder_path="${base_path}/SenseHQ"
log_file="${sensehq_folder_path}/bash/logs/sensehq_log_${current_date}.txt"

# calling php file for getting company id's,its count etc

# writing in log
Write_log "Calling getCompaniesForSync.php API for fetching all senseHQ enabled companies list." "" "${log_file}"

companies=$($php_exe_path -q $sensehq_folder_path"/getCompaniesForSync.php");
exitcode=$?
#echo "$exitcode"

# send alert email
# $1 => exitcode value
# $2 => error message
# $3 => company id
# $4 => mail subject
# $5 => mail matter
Send_Alert_Email "$exitcode" "Fatal error in ${sensehq_folder_path}/getCompaniesForSync.php file" "" "$sync_issue" "$sync_message"

echo -e "$companies\n\n" 
#exit

# separating companies in loop
company_array=(${companies//###@@AKKEN@@###/ })

# writing in log
Write_log "Fetched companies data:\n ${company_array[*]}." "" "${log_file}"

for company_info in "${company_array[@]}";
do
	#echo -e "$company_info"
	batches=0
	company_data=(${company_info//,/ })
	company_id="${company_data[0]}"
	candidates_count="${company_data[1]}"
	company_server="${company_data[2]}"
	
	batches=$((candidates_count / sensehq_cand_limit_count))
	total_processed_count=0
	
	# if any records pending after creating batch, we will increment batch by 1 to iterate one more time.
	remaining_count=$((candidates_count - (batches * sensehq_cand_limit_count)))
	if [ "$remaining_count" -gt "0" ]
	then 
		batches=$((batches+1))
	fi
	
	#batches=$((batches+1))
	
	echo -e "$company_id\n $candidates_count\n $company_server\n $batches\n $remaining_count\n\n\n"
	#exit
	
	# writing in log
	Write_log "Log started for company: '$company_id' \n\n-------------------------------------------------------------------------------------\n" "${company_id}" "${log_file}"
	
	# writing in log
	Write_log "Started Sync process for company '$company_id':\n\nTotal candidate count: $candidates_count.\nTotal batches are: $batches \n" "${company_id}" "${log_file}"
	
	# # getting company sensehq sync status from main db
	company_sync_status_result=$(mysql -h "${main_db_host}" -u "${db_username}" -p"${db_password}" "${main_database}" -sse "SELECT status FROM sensehq_sync_stats WHERE module='candidates' AND comp_id = '$company_id' AND mode='sync' order by sno desc LIMIT 1;")
	
	exitcode=$?
	# send alert email
	Send_Alert_Email "$exitcode" "Error came while performing this query in shell: SELECT status FROM sensehq_sync_stats WHERE module='candidates' AND comp_id = '$company_id' AND mode='sync' order by sno desc LIMIT 1;" "${company_id}" "$sync_issue" "$sync_message"
	
	company_sync_status="${company_sync_status_result[0]}"
	
	# # # writing in log
	Write_log "Company Query Status: $company_sync_status_result. \nCompany '$company_id' sync status: $company_sync_status\n" "${company_id}" "${log_file}"
	
	# # # If company sync current staus is not in progress, then we can update the status, total candidate count to respective company
	if [ "$company_sync_status" != "in-progress" ]
	then
		#echo -e "$company_sync_status"
		if [ "$company_sync_status" == "completed" ]
		then
			result1=$(mysql -h "${main_db_host}" -u "${db_username}" -p"${db_password}" "${main_database}" -sse "update sensehq_sync_stats set status='in-progress',count='$candidates_count',start_date=NOW(),mdate=NOW() where comp_id='$company_id' and module='candidates' ORDER BY sno DESC
LIMIT 1;")
			
			exitcode=$?
			# send alert email
			Send_Alert_Email "$exitcode" "Error came while performing this query in shell: update sensehq_sync_stats set status='in-progress',count='$candidates_count',start_date=NOW(),mdate=NOW() where comp_id='$company_id' and module='candidates';" "${company_id}" "$sync_issue" "$sync_message"
			
			# # writing in log
			Write_log "Main db Query status: $result1. Main db Query is: update sensehq_sync_stats set status='in-progress',count='$candidates_count',start_date=NOW(),mdate=NOW() where comp_id='$company_id' and module='candidates';\n" "${company_id}" "${log_file}"
		else
			result1=$(mysql -h "${main_db_host}" -u "${db_username}" -p"${db_password}" "${main_database}" -sse "INSERT INTO sensehq_sync_stats(comp_id,mode,module,count,status,start_date,cdate) VALUES('$company_id','sync','candidates','$candidates_count','in-progress',NOW(),NOW());")
			
			exitcode=$?
			# send alert email
			Send_Alert_Email "$exitcode" "Error came while performing this query in shell: INSERT INTO sensehq_sync_stats(comp_id,mode,module,count,status,start_date,cdate) VALUES('$company_id','sync','candidates','$candidates_count','in-progress',NOW(),NOW());" "${company_id}" "$sync_issue" "$sync_message"
			
			# # writing in log
			Write_log "Main db Query status: $result1. Main db Query is: INSERT INTO sensehq_sync_stats(comp_id,mode,module,count,status,start_date,cdate) VALUES('$company_id','sync','candidates','$candidates_count','in-progress',NOW(),NOW());\n" "${company_id}" "${log_file}"
		fi
		
		result2=$(mysql -h "${company_server}" -u "${db_username}" -p"${db_password}" "${company_id}" -sse "INSERT INTO sensehq_sync_stats(mode,module,count,status,start_date,cdate) VALUES('sync','candidates','$candidates_count','in-progress',NOW(),NOW());")
		
		exitcode=$?
		# send alert email
		Send_Alert_Email "$exitcode" "Error came while performing this query in shell: INSERT INTO sensehq_sync_stats(mode,module,count,status,start_date,cdate) VALUES('sync','candidates','$candidates_count','in-progress',NOW(),NOW());" "${company_id}" "$sync_issue" "$sync_message"
		
		# # writing in log
		Write_log "Company db Query status: $result2. Company db Query is: INSERT INTO sensehq_sync_stats(mode,module,count,status,start_date,cdate) VALUES('sync','candidates','$candidates_count','in-progress',NOW(),NOW());\n" "${company_id}" "${log_file}"
		
		#running batch loop
		# writing in log
		Write_log "Started batches loop for company '$company_id'\n" "${company_id}" "${log_file}"
		
		Send_Alert_Email "1" "Actual count: ${candidates_count}<br>Batches to be run: ${batches}" "${company_id}" "$sync_started" "$sync_started_message"
		
		batch_counter=1
		while [ "$batch_counter" -le "$batches" ]
		do
			 processed_count=0
			 # calling sync api here
			 processed_count=$($php_exe_path $sensehq_folder_path"/syncCandidates.php" $company_id $sensehq_cand_limit_count $batch_counter)
			 exitcode=$?
			 
			 # send alert email
			 Send_Alert_Email "$exitcode" "Fatal error in ${sensehq_folder_path}/syncCandidates.php file" "${company_id}" "$sync_issue" "$sync_message"
			 
			 # writing in log
			 Write_log "Batch '$batch_counter': Processed records are: '$processed_count' \n" "${company_id}" "${log_file}"
			 
			 if is_int "$processed_count" ;then
				total_processed_count=$((total_processed_count+processed_count))
			 fi
			 
			 batch_counter=$((batch_counter+1))
			 #exit
			 
		done 
		
		# # writing in log
		Write_log "Total processed count: $total_processed_count, Actual count: $candidates_count\n" "${company_id}" "${log_file}"
		
		# if all batches done, then update sync status for company
		if [ "$total_processed_count" == "$candidates_count" ]
		then
			result3=$(mysql -h "${main_db_host}" -u "${db_username}" -p"${db_password}" "${main_database}" -sse "UPDATE sensehq_sync_stats set status='completed',end_date=NOW(),mdate=NOW() WHERE comp_id='$company_id' AND status='in-progress' AND module='candidates';")
			
			exitcode=$?
			# send alert email
			Send_Alert_Email "$exitcode" "Error came while performing this query in shell: UPDATE sensehq_sync_stats set status='completed',end_date=NOW(),mdate=NOW() WHERE comp_id='$company_id' AND status='in-progress' AND module='candidates';" "${company_id}" "$sync_issue" "$sync_message"
			
			# # writing in log
			Write_log "Main db Query status: $result3. Main db Query is: UPDATE sensehq_sync_stats set status='completed',end_date=NOW(),mdate=NOW() WHERE comp_id='$company_id' AND status='in-progress' AND module='candidates';\n" "${company_id}" "${log_file}"
			
			result4=$(mysql -h "${company_server}" -u "${db_username}" -p"${db_password}" "${company_id}" -sse "UPDATE sensehq_sync_stats set status='completed',end_date=NOW(),mdate=NOW() WHERE status='in-progress' AND module='candidates';")
			
			exitcode=$?
			# send alert email
			Send_Alert_Email "$exitcode" "Error came while performing this query in shell: UPDATE sensehq_sync_stats set status='completed',end_date=NOW(),mdate=NOW() WHERE status='in-progress' AND module='candidates';" "${company_id}" "$sync_issue" "$sync_message"
			
			# # writing in log
			Write_log "Company db Query status: $result4. Company db Query is: UPDATE sensehq_sync_stats set status='completed',end_date=NOW(),mdate=NOW() WHERE status='in-progress' AND module='candidates';\n" "${company_id}" "${log_file}"
			
			exitcode=0
			# writing in log
			 Write_log "Marking Company '$company_id' sync status as 'completed' \n\n-------------------------------------------------------------------------------------\n" "${company_id}" "${log_file}"
			 
			 Send_Alert_Email "1" "Total processed count: ${total_processed_count}<br>Actual count: ${candidates_count}" "${company_id}" "$sync_completed" "$sync_completed_message"
			 
		else
			Send_Alert_Email "1" "Sync not completed. <br>Total processed count: ${total_processed_count}<br>Actual count: ${candidates_count}" "${company_id}" "$sync_issue" "$sync_message"
			
			exitcode=0
			# writing in log
			 Write_log "Sync not completed. <br>Total processed count: '$total_processed_count'<br>Actual count: '$candidates_count' \n\n-------------------------------------------------------------------------------------\n" "${company_id}" "${log_file}"
		fi
	fi
done