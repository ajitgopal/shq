#!/bin/bash
# common shell functions

# writing new log into existing log file. If not exist, will create new one
Write_log () {
   if [ "$1" != "" ]
   then
	#echo -e "$(date +'%Y-%m-%d %R:%S'): $1\n " >> "$3"
	echo -e "$(date +'%Y-%m-%d %R:%S'): ${1//<br>/\n}\n " >> "$3"
	
	if [[ "${1,,}" == *"error#:#"* ]] 
	then
		Send_Alert_Email "1" "$1" "$2" "$sync_issue" "$sync_message"
		#echo -e "$1"
	fi
	
   fi
}

# calling API to send email by passing params
Send_Alert_Email () {
	if [ "$1" -gt "0" ]
	then
		# $2 => error message
		# $3 => company id
		# $4 => mail subject
		# $5 => mail matter
		mail_ack=$($php_exe_path -q "/usr/bin/db-driver/BashConfigs/sendEmail.php" "$2" "$3" "$4" "$5");
		#echo -e "$mail_ack\n\n" 
		
		
	fi
}

# Function to get provided value is INT or not
function is_int() {
    if is_empty "${1}" ;then
        false
        return
    fi
    tmp=$(echo "${1}" | sed 's/[^0-9]*//g')
    if [[ $tmp == "${1}" ]] || [[ "-${tmp}" == "${1}" ]] ; then
        #echo "INT"
        true
    else
        #echo "NOT INT"
        false
    fi
}

# Function to get provided value is float or not
function is_float() {
    if is_empty "${1}" ;then
        false
        return
    fi
    if ! strindex "${1}" "-" ; then
        false
        return
    fi
    tmp=$(echo "${1}" | sed 's/[^a-z. ]*//g')
    if [[ $tmp =~ "." ]] ; then
        #echo "FLOAT  (${1}) tmp=$tmp"
        true
    else
        #echo "NOT FLOAT  (${1}) tmp=$tmp"
        false
    fi
}

# Function to get provided value is strict string or not. Means having only alphabets
function is_strict_string() {
    if is_empty "${1}" ;then
        false
        return
    fi
    if [[ "${1}" =~ ^[A-Za-z]+$ ]]; then
        #echo "STRICT STRING (${1})"
        true
    else
        #echo "NOT STRICT STRING (${1})"
        false
    fi
}

# Function to get provided value is string or not
function is_string() {
    if is_empty "${1}" || is_int "${1}" || is_float "${1}" || is_strict_string "${1}" ;then
        false
        return
    fi
    if [ ! -z "${1}" ] ;then
        true
        return
    fi
    false
}

# Function to get provided value is empty or not
function is_empty() {
    if [ -z "${1// }" ] ;then
        true
    else
        false
    fi
}