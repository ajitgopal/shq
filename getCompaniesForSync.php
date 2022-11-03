<?php
$include_path="/usr/bin/db-driver";
ini_set("include_path",$include_path);

require("global.inc");
require_once('sysdb.inc');
require_once("include/SenseHQ.php");

//$dque="SELECT capp_info.comp_id FROM company_info LEFT JOIN capp_info ON (capp_info.sno = company_info.sno) LEFT JOIN options ON (options.sno = company_info.sno) WHERE company_info.status IN ('ER','ERA') AND options.sensehq = 'Y' $version_clause";
/*$dque="SELECT capp_info.comp_id FROM company_info LEFT JOIN capp_info ON (capp_info.sno = company_info.sno) LEFT JOIN options ON (options.sno = company_info.sno) WHERE company_info.status IN ('ER','ERA') AND options.sensehq = 'Y' $version_clause";

$dres=mysql_query($dque,$maindb);

$final_array = [];
$sensehq_enabled_companies = [];

while($drow=mysql_fetch_row($dres))
{
	if($drow[0]!="" || $drow[0]!=0) {
		$sensehq_enabled_companies[] = strtolower($drow[0]);
	}
}*/

$sensehq_enabled_companies = ['srinivasal'];
foreach ($sensehq_enabled_companies as $key => $companyuser) 
{
	require("database.inc");
	
	$candQuery = "SELECT COUNT(*) as num FROM candidate_list cl LEFT JOIN candidate_general cg ON  cl.username = cg.username WHERE cl.sno NOT IN(SELECT cand_sno FROM sensehq_candidates WHERE modified = 'N')";
	$candRes = mysql_query($candQuery, $db);
	
	if(!$candRes) {
		echo "error#:# <br>
		Company: $companyuser.<br><br>
		Called Query: $candQuery<br><br>
		Error: ".mysql_error()."
		<br>";
		continue;
	}
	
	$candData = mysql_fetch_assoc($candRes);
	$candCount = ($candData['num'] == "") ? 0 : $candData['num'];
	//$candCount = 500;
	
	$sensehq_setup_que = "SELECT client_id,client_secret FROM sensehq_account WHERE status='A' AND auto_sync = 'Yes' LIMIT 1";
	$sensehq_setup_res = mysql_query($sensehq_setup_que,$db);
	
	if(!$sensehq_setup_res) {
		echo "error#:# <br>
		Company: $companyuser.<br><br>
		Called Query: $sensehq_setup_que<br><br>
		Error: ".mysql_error()."
		<br>";
		continue;
	}
	
	$sensehq_setup_row = mysql_fetch_assoc($sensehq_setup_res);
	
	if(mysql_num_rows($sensehq_setup_res) > 0 && $candCount > 0 ) 
	{
		$final_array[] = array($companyuser,$candCount,$int_master_db[0]);
	}
	
}



$result = array();
foreach ($final_array as $sub) {
  $result[] = implode(',', $sub);
}
$result_array = implode('###@@AKKEN@@###', $result);

echo $result_array;
?>