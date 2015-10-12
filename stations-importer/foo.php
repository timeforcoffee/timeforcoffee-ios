<?php

$handle = new SQLite3("/Users/chregu/Documents/SingleViewCoreData.sqlite");
$results = $handle->query("select * from ZTFCSTATIONMODEL where ZID like '0%' "); 

while ($row = $results->fetchArray()) {
    print preg_replace("/^0*/", "", $row['ZID']) ;
    print " " .  $row['ZID']  ." \n";
    
        $handle->exec("update ZTFCSTATIONMODEL set ZID = '" . preg_replace("/^0*/", "", $row['ZID']) ."' where ZID = '". $row['ZID'] ."'");
}
