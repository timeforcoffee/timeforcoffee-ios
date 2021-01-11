<?php
$handle = new SQLite3("../../timeforcoffee-api/stations.sqlite");

$stations = getDataFromCSV();
$stops = getStopsFromCSV();
// dienststellen_actualdate.csv is from the DiDok -> https://opentransportdata.swiss/de/dataset/didok
// stops.txt is from the GTFS data, eg https://opentransportdata.swiss/de/dataset/timetable-2021-gtfs2020

// dienststellen may have some stations, which are not actually served anymore, but has info like County and GO

// if you import new data (when new timetable comes out) you better set ZUPDATE2020 and ZINGTFSSTOPS to NULL

foreach ($stations as $r) {
    //var_dump($r);
    $id = $r["BPUIC"];
    if ($r['LAND_ISO2_GEO'] !== 'CH') {
        continue;
    }
    if ($r['IS_HALTESTELLE'] !== "1") {
        continue;
    }
    $results = $handle->query("select * from ZTFCSTATIONMODEL where ZID = $id");


    print($id . " - " . $r['BEZEICHNUNG_OFFIZIELL'] . " - " . $r["GO_ABKUERZUNG_DE"]);
    $foo = $results->fetchArray();
    if ($foo == FALSE) {
        print " - DOES NOT EXIST";
        $update2020 = 1;
    }
    else {
        if ($foo['UPDATE2020'] === 1) {
            print " - already inserted\n";
            continue;
        }
        if ($foo['UPDATE2020'] === 2) {
            print " - already updated \n";
            continue;
        }
        $update2020 = 2;
    }
    $row = [
        'ZID' => $id,
        'UPDATE2020' => $update2020,
        'ZNAME' => $r['BEZEICHNUNG_OFFIZIELL'],
        'ZLATITUDE' => $r['N_WGS84'],
        'ZLONGITUDE' => $r['E_WGS84'],
        'ZCOUNTY' => $r['KANTONSNAME'],
        'ZCITY' => $r['GEMEINDENAME'],
        'ZGO' => $r['GO_ABKUERZUNG_DE'],
        'ZCOUNTRYISO' => 'CH',
        'Z_ENT' => 2,

    ];

    if ($update2020 === 1) {
        $row['Z_OPT'] = 8; // ????
    }

    $values = array_map(function ($value) {
        return "'" . SQLite3::escapeString($value) . "'";
    }, $row);
    if ($update2020 === 1) {
        $row['Z_OPT'] = 8; // ????
        $sql = "INSERT INTO ZTFCSTATIONMODEL (" .
            implode(", ", array_keys($row)) .
            ") VALUES (" .
            implode(", ", $values) .
            ")";
        print " - Insert";
    }
    else {
        $updates = array_map(function ($k, $v) {
            return "$k = '" . SQLite3::escapeString($v) . "'";
        }, array_keys($row),$row);
        $sql = "UPDATE ZTFCSTATIONMODEL SET " . join(",", $updates) . " WHERE ZID = " . $id;
        print  " - Update";
    }

    $handle->exec($sql);
    print " - Done";

    print "\n";
    //        $results = $handle->query("DELETE from ZTFCSTATIONMODEL where ZID = $id");


}

foreach ($stops as $r) {
    if (!isset($r["stop_id"])) {
        continue;
    }
    $id = explode(":",rtrim($r["stop_id"],"P"))[0];
    print $id ."\n";

    $results = $handle->query("select * from ZTFCSTATIONMODEL where ZID = '$id'");

    print($id . " - " . $r['stop_name'] );

    $foo = $results->fetchArray();
    if ($foo == FALSE) {
        print " - DOES NOT EXIST\n";
        continue;
    }

    $row = [
        'ZID' => $id,
        'ZINGTFSSTOPS' => 1,

    ];
    $updates = array_map(function ($k, $v) {
        return "$k = '" . SQLite3::escapeString($v) . "'";
    }, array_keys($row),$row);

    $sql = "UPDATE ZTFCSTATIONMODEL SET " . join(",", $updates) . " WHERE ZID = '" . $id. "'";
    $handle->exec($sql);

    print  " - Update";
    print " - Done";
    print "\n";


}

function getDataFromCSV() {
    $csv = array_map(function ($line) {
        return str_getcsv($line, ';', '"');
    }, file('dienststellen_actualdate.csv'));


    array_walk($csv, function (&$a) use ($csv) {
        $a = array_combine($csv[0], $a);
    });
    array_shift($csv);
    return $csv;
}

function getStopsFromCSV() {
    $csv = array_map(function ($line) {
        return str_getcsv(preg_replace("/[^[:print:]\w]/", "", $line), ',', '"');
    }, file('stops.txt'));


    array_walk($csv, function (&$a) use ($csv) {
        $a = array_combine($csv[0], $a);
    });
    array_shift($csv);


    return $csv;

}

