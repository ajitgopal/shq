<?php
// Set include folder
$include_path="/usr/bin/db-driver";
ini_set("include_path",$include_path);

require("global.inc");
require("smtp.inc");
require("html2text.inc");
require("saveemails.inc");

$error_param = $argv[1];
$company_id = $argv[2];
$error_param = str_replace("\\n", '<br>', $error_param);

$smtp=new smtp_class;
$smtp->debug=1;
$smtp->html_debug=0;
$smtp->saveCopy=false;

$efrom = "Akken Notifications <donot-reply@akken.com>";
//$to = array("srinivasa.l@akkentech.com");
$to = array("nani.lukalapu@gmail.com");
$mailtype = "text/html";
$cc = "";

$subject = $argv[3];
$matter = $argv[4];

$message = "
Hi,<br><br>

".$matter.":<br><br>";

if($company_id!="") {
	$message.="<b>Company:</b> ".$company_id."<br>";
}

if(strtolower($subject)!="sync started" && strtolower($subject)!="sync completed")
{
	$message.="<b>Issue:</b> ".$error_param."";
} else {
	$message.="<b>Details:</b> ".$error_param."";
}

$message.="<br><br>Regards<br>Akken";

$mailheaders = array("Date: $curtime_header","From: ".stripslashes($efrom),"To: ".stripslashes($to),"Cc: $cc","Subject: $subject","MIME-Version: 1.0");
$msg_body = prepareBody($message,$mailheaders,$mailtype);

//$suc = $smtp->SendMessage($efrom,$to,$mailheaders,$msg_body) ? "true" : "false";
$suc = $smtp->SendMessage($efrom,$to,$mailheaders,$msg_body);
echo $suc;
?>
