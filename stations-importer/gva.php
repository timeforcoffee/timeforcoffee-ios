<?php

$handle = new SQLite3("../../tramboard-clj/stations.sqlite");
$results = $handle->query("select * from ZTFCSTATIONMODEL where ZCOUNTY = 'Geneva' AND ZAPIKEY ISNULL  ");

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
            if (checkData($stop['stopCode'])) {
                $handle->exec("update ZTFCSTATIONMODEL set ZAPIKEY = 'gva', ZAPIID = '". $stop['stopCode'] . "' where ZID = '". $row['ZID'] ."'");
            } else {
                print "No departures found for " . $row['ZNAME'] . "\n";
            }
        } if ($distance < 250) {
            if ($row['ZNAME'] ==  $stop['stopName']) {
                if (checkData($stop['stopCode'])) {
                    $handle->exec("update ZTFCSTATIONMODEL set ZAPIKEY = 'gva', ZAPIID = '" . $stop['stopCode'] . "' where ZID = '" . $row['ZID'] . "'");
                } else {
                    print "No departures found for " . $row['ZNAME'] . "\n";
                }
                
            } else {
                $parts = explode(",", $row['ZNAME']);
                if (isset($parts[1])) {
                    if (trim($parts[1]) == $stop['stopName']) {
                        if (checkData($stop['stopCode'])) {
                            $handle->exec("update ZTFCSTATIONMODEL set ZAPIKEY = 'gva', ZAPIID = '". $stop['stopCode'] . "' where ZID = '". $row['ZID'] ."'");
                            print $parts[1] . ' == ' . $stop['stopName'] ."\n";
                        } else {
                            print "No departures found for " . $row['ZNAME'] . "\n";
                        }
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

function checkData($id)
{
    $url = "http://prod.ivtr-od.tpg.ch/v1/GetNextDepartures?key=21a25080-9bbc-11e4-bc99-0002a5d5c51b&stopCode=";
    $json = file_get_contents($url . $id);
    $r = json_decode($json, true);
    if (isset($r['departures']) && count($r['departures']) > 0) {
        return true;
    }
    return false;
}