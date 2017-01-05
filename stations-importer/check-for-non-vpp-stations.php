<?php

$handle = new SQLite3("../../tramboard-clj/stations.sqlite");


//$stations = getDataFromAPI($odp_companies);
$stations = getDataFromCSV();
foreach ($stations as $r) {
    $id = $r['Dst-Nr.'] + 8500000;
        $results = $handle->query("select * from ZTFCSTATIONMODEL where ZID = $id");
        $foo = $results->fetchArray();
        if ($foo == false) {
         #   print " - NOT FOUND in our DB\n";
            continue;
        }
    print($id . " - " . $r['Dst-Bezeichnung-offiziell'] . " - " . $r["GO-Abk"]) ;
    print " - FOUNT in our DB, delete";
    $results = $handle->query("DELETE from ZTFCSTATIONMODEL where ZID = $id");


    print "\n";
        //var_dump($odpdata);
        //check if it has ODP realtime data (but isn't already marked as ODP), then update DB

}


function getDataFromCSV() {
    $csv = array_map('str_getcsv', file('didok.csv'));
    array_walk($csv, function(&$a) use ($csv) {
        $a = array_combine($csv[0], $a);
    });
    array_shift($csv);

    $csv = array_filter($csv, function($a)  {
        if ( $a['VPP'] != '*') {
            return true;
        }
        return false;
    });

    return $csv;

}

