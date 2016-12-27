<?php

$url = 'https://opentransportdata.swiss/api/action/datastore_search?resource_id=4af0359c-f136-41ea-8ffd-0308f7f68015';
$handle = new SQLite3("../../tramboard-clj/stations.sqlite");

$odp_companies_json = json_decode(file_get_contents($url), true);
$odp_companies = [];
foreach ($odp_companies_json['result']['records'] as $r) {
    if ($r['Company-GO-ID'] != 11) { //SBB, we let zvv handle that one
        if ($r['Company-GO-ID'] != 870) { //ASM Auto has no at all
            $odp_companies[] = $r['Company-GO-ID'];
        }
    }
}
//$stations = getDataFromAPI($odp_companies);
$stations = getDataFromCSV($odp_companies);
foreach ($stations as $r) {
    $id = $r['Dst-Nr.'] + 8500000;
    if ($r['VPP'] == "*") {
        print($id . " - " . $r['Dst-Bezeichnung-offiziell'] . " - " . $r["GO-Abk"]) ;
        $results = $handle->query("select * from ZTFCSTATIONMODEL where ZID = $id");
        $foo = $results->fetchArray();
        if ($foo == false) {
            print " - NOT FOUND in our DB\n";
            continue;
        }
        $apikey = $foo['ZAPIKEY'];
        print " - " . $apikey;
        if ($apikey != "odp") {

            $checkurl = "http://localhost:3000/api/odp/stationboard/" . $id;
            $odpdata = json_decode(file_get_contents($checkurl), true);
            $hasRealtime = 0;
            foreach ($odpdata['departures'] as $dept) {
                if ($dept['source'] == 'odp' && $dept['departure']['realtime']) {
                    //var_dump($dept);
                    $hasRealtime ++;
                }
            }
            if ($apikey != "") {
                $checkurl = "http://localhost:3000/api/ch/stationboard/" . $id;
                $otherdata = json_decode(file_get_contents($checkurl), true);
                $hasOtherRealtime = 0;
                $platformData = false;
                foreach ($otherdata['departures'] as $dept) {
                    if ($dept['source'] != 'odp' && $dept['source'] != 'zvv' && $dept['departure']['realtime']) {
                        //var_dump($dept);
                        if ($dept['platform']) {
                            $platformData = true;
                        }
                        $hasOtherRealtime++;
                    }
                }
                print " - ";
                if ($hasOtherRealtime > 0) {
                    print " Has $apikey Realtime";

                } else {
                    print " Has NO $apikey Realtime";
                }
                if ($hasRealtime > 0 && $hasOtherRealtime <= $hasRealtime) {
                    print " - odb count: $hasRealtime is bigger than $apikey count: $hasOtherRealtime";
                    if ($platformData) {
                        print " - Dont set APIKEY to odp due to Platform data";
                    } else {
                        print " - Set APIKEY to odp";
                        $handle->exec("update ZTFCSTATIONMODEL set  ZAPIKEY = 'odp' where ZID = '" . $id . "'");
                    }

                } else if ($hasOtherRealtime > 0 && $hasRealtime > 0) {
                    print " - odb count: $hasRealtime is smaller than $apikey count: $hasOtherRealtime";

                }
            }
            print " - ";

            if ($hasRealtime > 0) {
                print " Has odp Realtime";
                if ($apikey == "") {
                    print " - Set APIKEY to odp";
                    $handle->exec("update ZTFCSTATIONMODEL set  ZAPIKEY = 'odp' where ZID = '" . $id . "'");
                }

            } else {
                print " Has NO odp Realtime";
            }


        }
        print "\n";
        //var_dump($odpdata);
        //check if it has ODP realtime data (but isn't already marked as ODP), then update DB
    }
}


function getDataFromCSV($odp_companies) {
    $csv = array_map('str_getcsv', file('didok.csv'));
    array_walk($csv, function(&$a) use ($csv) {
        $a = array_combine($csv[0], $a);
    });
    array_shift($csv);

    $csv = array_filter($csv, function($a) use ($odp_companies) {
        if (in_array($a['GO-Nr'], $odp_companies) && $a['VPP'] == '*') {
            return true;
        }
        return false;
    });

    return $csv;

}


function getDataFromAPI($odp_companies)
{
    $limit = 10;
    $stations = [];
    $url = 'https://opentransportdata.swiss/api/action/datastore_search_sql?sql=';
    $select = 'SELECT * from "2dc21730-f7da-4e0b-b8d1-266848a8a61a" WHERE "GO-Nr" = ';
    $select .= join(' OR "GO-Nr" = ', $odp_companies) . " LIMIT $limit OFFSET ";
    $OFFSET = 0;
    $hasData = true;
    while ($hasData) {
        $odp_stations_json = json_decode(file_get_contents($url . urlencode($select . $OFFSET)), true);
        $hasData = false;
        $OFFSET += $limit;
        foreach ($odp_stations_json['result']['records'] as $r) {
            $hasData = true;
            $stations[] = $r;

        }
    }
    return $stations;

}
