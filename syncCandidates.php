<?php
$include_path="/usr/bin/db-driver";
ini_set("include_path",$include_path);

require("global.inc");
require_once('sysdb.inc');
require_once("include/SenseHQ.php");

$companyuser = $argv[1];
$sensehq_sync_limit = $argv[2];
$batch_counter = $argv[3];

if($companyuser!="")
{
	require("database.inc");

	// getting sense hq client details
	$sensehq_setup_que = "SELECT client_id,client_secret FROM sensehq_account WHERE status='A' AND auto_sync = 'Yes' LIMIT 1";
	$sensehq_setup_res = mysql_query($sensehq_setup_que,$db);
	
	if(!$sensehq_setup_res) {
		echo "error#:# <br>
		Company: $companyuser.<br><br>
		Called Query: $sensehq_setup_que<br><br>
		Error: ".mysql_error()."
		<br>";
	}
	
	$sensehq_setup_row = mysql_fetch_assoc($sensehq_setup_res);

	$client_id = $sensehq_setup_row["client_id"];
	$client_secret = $sensehq_setup_row["client_secret"];

	$sensehq_sync_limit = ($sensehq_sync_limit > 0) ? $sensehq_sync_limit : 500;

	$qry = "SELECT cl.address1,cl.address2,cl.city,cl.country,DATE_FORMAT(cl.ctime,'%Y-%m-%dT%TZ') as ctime,DATE_FORMAT(cl.mtime,'%Y-%m-%dT%TZ') as mtime,cl.email,cl.fname,cl.sno,cl.owner,cl.lname,cl.mobile,cl.dontemail,cl.dontcall,cl.cl_source,cl.state,cl.cl_status,cl.profiletitle,cl.zip,cl.username,cg.cphone as phone_pref,cg.cmobile as mobile_pref,cg.cfax as fax_pref,cg.cemail as email_pref,cl.status as cand_status FROM candidate_list cl LEFT JOIN candidate_general cg ON  cl.username = cg.username WHERE cl.sno NOT IN(SELECT cand_sno FROM sensehq_candidates WHERE modified = 'N') ORDER BY cl.sno LIMIT $sensehq_sync_limit";

	$dataRes = mysql_query($qry, $db);
	if(!$dataRes) {
		echo "error#:# <br>
		Company: $companyuser.<br><br>
		Called Query: $qry<br><br>
		Error: ".mysql_error()."
		<br>";
	}

	$senseString = "";
	$candApiJson = "";
	$senseHQAuth = new SenseHQ('Auth');
	$idVals = [];
	$candprocCompleted = 0;

	while($row = mysql_fetch_assoc($dataRes)) 
	{
		if($row["cand_status"] == "ACTIVE")
		{
			$cand_pref="";

			if($row["phone_pref"] == "TRUE"){
				$cand_pref .= 'phone,';
			}
			if($row["mobile_pref"] == "TRUE"){
				$cand_pref .= 'mobile,';
			}
			if($row["fax_pref"] == "TRUE"){
				$cand_pref .= 'fax,';
			}
			if($row["email_pref"] == "TRUE"){
				$cand_pref .= 'email,';
			}

			$cand_pref = rtrim($cand_pref,',');

			$candApiJson .= '{
			    "active": true,
			    "address1": "'.$senseHQAuth->escapeJsonString($row["address1"]).'",
			    "address2": "'.$senseHQAuth->escapeJsonString($row["address2"]).'",
			    '.$senseHQAuth->getCatsJson($row['username']).'
			    "city": "'.$senseHQAuth->escapeJsonString($row["city"]).'",
			    "country": "'.$senseHQAuth->getCountryname($row["country"]).'",
			    "date_added": "'.$row["ctime"].'",
			    "date_last_activity": "'.$row["mtime"].'",
			    "date_last_modified": "'.$row["mtime"].'",
			    "email": "'.$senseHQAuth->escapeJsonString($row["email"]).'",
			    "first_name": "'.$senseHQAuth->escapeJsonString($row["fname"]).'",
			    "id": "'.$row["sno"].'",
			    "internal_user_id": "'.$row["owner"].'",
			    "is_archived": false,
			    "last_name": "'.$senseHQAuth->escapeJsonString($row["lname"]).'",
			    "mobile_phone": "'.$senseHQAuth->escapeJsonString($row["mobile"]).'",
			    "opt_out_email": '.($row["dontemail"]=="Y"?"true":"false").',
			    "opt_out_sms": '.($row["dontcall"]=="Y"?"true":"false").',
			    "preferred_contact_method": "'.$cand_pref.'",
			    '.$senseHQAuth->getSkillJson($row["username"]).'
			    "source": "'.$senseHQAuth->escapeJsonString($row["source"]).'",
			    '.$senseHQAuth->getSpcltyJson($row["username"]).'
			    "state": "'.$senseHQAuth->escapeJsonString($row["state"]).'",
			    "status": "'.$senseHQAuth->getCandStatus($row["cl_status"]).'",
			    "title": "'.$senseHQAuth->escapeJsonString($row["profiletitle"]).'",
			    "zipcode": "'.$senseHQAuth->escapeJsonString($row["zip"]).'"
			},';

		} //active case end
		else 
		{
			$candApiJson .= '{
			    "active": false,
			    "address1": "",
			    "address2": "",
			    "categories":[""],
			    "city": "",
			    "country": "",
			    "date_last_modified": "'.$row["mtime"].'",
			    "email": "",
			    "first_name": "",
			    "id": "'.$row["sno"].'",
			    "internal_user_id": "",
			    "is_archived": true,
			    "last_name": "",
			    "mobile_phone": "",
			    "preferred_contact_method": "",
			    "skills":[""],
			    "source": "",
			    "specialties":[""],
			    "state": "",
			    "status": "",
			    "title": "",
			    "zipcode": ""
			},';
		} //inactive case end

		$idVals[] = $row["sno"];
		$candprocCompleted++;

	} //while loop end

	$candApiJson = "[".rtrim($candApiJson, ',')."]";
	
	//echo $candApiJson; exit;
	
	$candApiArr = json_decode($candApiJson);
	
	$cand_sno = implode(",", $idVals);
	
	$getAccess = $senseHQAuth->authenticateClientCredentials($client_id,$client_secret);
	if(array_key_exists('access_token', $getAccess))
	{	

		$senseHQApi = new SenseHQ('Api',$getAccess['access_token']);
		if(!empty($candApiArr))
		{
			$syncCands 	= $senseHQApi->syncCandidates($candApiArr);
			if(trim($syncCands) == 201) {
				echo $candprocCompleted;
			} else {
				echo "error#:# <br>
				Company: $companyuser.<br><br>
				Sync failed for batch: $batch_counter.<br>
				Not getting response code 201<br>
				Error from Sync: $syncCands<br>
				Cand sno: $cand_sno
				<br>";
				
				//$senseHQApi->updateFailedCandSync($syncCands);
			}
		} else {
			echo "error#:# <br>
			Company: $companyuser.<br><br>
			Sync failed for batch: $batch_counter.<br>
			JSON not parsing properly<br>
			Cand sno: $cand_sno
			<br>";
			
			$senseHQApi->updateFailedCandSync('JSON not parsing properly');
		}
	} else {
		echo "error#:# <br>
		Company: $companyuser.<br><br>
		Sync failed for batch: $batch_counter.<br>
		Error: Access token not generated for sense hq<br>
		Cand sno: $cand_sno
		<br>";
		
		$senseHQApi->updateFailedCandSync('Access token not generated for sense hq');
	}
}
else
{
	echo 0;
}
?>