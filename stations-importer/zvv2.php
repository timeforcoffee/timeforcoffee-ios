<?php

$handle = new SQLite3("../../tramboard-clj/stations.sqlite");


for ($i = 299000; $i < 299999; $i++) {

    $res = $handle->query("select * from zvv_to_sbb where  zvv_id = '$i'");
    if ($res->fetchArray() === false) {
        print $i . " ";
        $url = "http://online.fahrplan.zvv.ch/bin/stboard.exe/dny?dirInput=&maxJourneys=50&boardType=dep&start=1&tpl=stbResult2json&input=$i";
        //    print "$url\n";
        $json = @file_get_contents($url);
        if (!$json) {
            print $url . " could not be retrieved! \n";
            continue;
        }
        
        $json = json_decode($json, true);
        if (isset($json['connections'][0])) {
            foreach ($json['connections'] as $connection) {
                $zvvid = $connection['mainLocation']['location']['id'];
                if ($zvvid > 8500000) {
                    //  print " ! has zvv id: $zvvid != ". $row['ZID'];
                    //  if ($zvvid < 8500000 && $zvvid != $row['ZAPIID']) {
                        $res = $handle->query("select * from zvv_to_sbb where  zvv_id = '$i'");
                        if ($res->fetchArray() === false) {
                            
                            print " ! has zvv id: $zvvid != ". $i;
                            $handle->exec("insert INTO zvv_to_sbb (zvv_id, sbb_id) VALUES ( '$i', '$zvvid')");
                        }
                } else {
                    //  print " - no zvvid ";
                } 
            }

        }
                        print "\n";

    }
   // print ".";
    sleep(1);
}
$handle->exec("VACUUM FULL");


