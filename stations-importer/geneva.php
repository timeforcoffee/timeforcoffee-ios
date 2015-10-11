<?php

$handle = new SQLite3("/Users/chregu/Documents/SingleViewCoreData.sqlite");
$results = $handle->query("select * from ZTFCSTATIONMODEL where ZCOUNTY = 'Geneva' AND ZDEPARTURESURL ISNULL  "); 

while ($row = $results->fetchArray()) {
    $url = "http://prod.ivtr-od.tpg.ch/v1/GetStops.json?latitude=" . $row['ZLATITUDE'] . "&longitude=" . $row['ZLONGITUDE'] . "&key=21a25080-9bbc-11e4-bc99-0002a5d5c51b";
    
    $json = file_get_contents($url);
    $r = json_decode($json,true);
    if (isset($r['stops'][0])) {
        $stop = $r['stops'][0];
        $distance = $stop['distance'];
        print $row['ZNAME'] . " <=> ";
        print " ". $stop['stopName'];
        print "\n";
        if ($distance < 50) {
            $handle->exec("update ZTFCSTATIONMODEL set ZDEPARTURESURL = 'http://www.timeforcoffee.ch/api/gva/stationboard/". $stop['stopCode'] . "' where ZID = '". $row['ZID'] ."'");
        } if ($distance < 250) {
            if ($row['ZNAME'] ==  $stop['stopName']) {
                $handle->exec("update ZTFCSTATIONMODEL set ZDEPARTURESURL = 'http://www.timeforcoffee.ch/api/gva/stationboard/". $stop['stopCode'] . "' where ZID = '". $row['ZID'] ."'");
                
            } else {
                $parts = explode(",", $row['ZNAME']);
                if (isset($parts[1])) {
                    if (trim($parts[1]) == $stop['stopName']) {
                        $handle->exec("update ZTFCSTATIONMODEL set ZDEPARTURESURL = 'http://www.timeforcoffee.ch/api/gva/stationboard/". $stop['stopCode'] . "' where ZID = '". $row['ZID'] ."'");
                        print $parts[1] . ' == ' . $stop['stopName'] ."\n";
                    }
                } else {
                    print "Distance ($distance) too long for ". $row['ZNAME']. "\n";
                    
                }
            }
        } else {
            print "Distance ($distance) too long for ". $row['ZNAME']. "\n";
        }
    } else {
        print "nothing found for ". $row['ZNAME']. "< $url >\n";
    }
}

$result = $handle->querySingle("select count(*) from ZTFCSTATIONMODEL where ZCOUNTY = 'Geneva' AND ZDEPARTURESURL ISNULL  "); 
print $result . " are still without an URL\n";

function getFirst($url) {
    
    $result = file_get_contents( "http://www.timeforcoffee.ch/api/".$url);
    $r = json_decode($result, true);
    return $r['departures'];
}
