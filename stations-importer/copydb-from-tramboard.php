<?php

$handle = new SQLite3("../../timeforcoffee-api/stations.sqlite");
$handle2 = new SQLite3("../timeforcoffeeKit/SingleViewCoreData.sqlite");
$results = $handle->query("select Z_PK, Z_ENT, Z_OPT, ZLASTUPDATED, ZLATITUDE, ZLONGITUDE, ZCOUNTRYISO, ZID, ZNAME from ZTFCSTATIONMODEL  where ZINGTFSSTOPS IS NOT NULL");
$handle2->exec("drop TABLE zvv_to_sbb");
$handle2->exec("drop index ZAPIID");
$handle2->exec("drop index ZAPIKEY");

$handle2->exec("delete from ZTFCSTATIONMODEL");
$handle2->exec("delete from ZTFCDEPARTURE");
while ($row = $results->fetchArray(SQLITE3_ASSOC)) {

    
    $values = array_map( function($value) { return "'".SQLite3::escapeString($value)."'";}, $row);
    $sql = "INSERT INTO ZTFCSTATIONMODEL (" . implode(", ",array_keys($row)).") VALUES (" . implode(", ",$values) . ")";
    print ".";
    $handle2->exec($sql);
}

$f = $handle2->query("SELECT max(Z_PK) from ZTFCSTATIONMODEL");

$handle2->query("UPDATE Z_PRIMARYKEY set Z_MAX = " . ($f->fetchArray()[0] + 1) . " WHERE Z_ENT = 1");
$handle2->close();
$handle2 = new SQLite3("../timeforcoffeeKit/SingleViewCoreData.sqlite");

$handle2->exec("VACUUM");

