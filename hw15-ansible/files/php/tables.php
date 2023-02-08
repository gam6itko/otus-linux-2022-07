<?php

declare(strict_types=1);

ini_set('display_errors', '1');

$file = __DIR__.'/../mysql_host';
if (!file_exists($file)) {
    exit('file not found');
}

$mysqlHost = trim(file_get_contents($file));
if (empty($mysqlHost)) {
    exit('MYSQL_HOST is not set');
}

$pdo = new \PDO("mysql:host=$mysqlHost;dbname=otus", 'php_node', 'pass', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_TIMEOUT => 1, // in seconds
    PDO::ATTR_EMULATE_PREPARES => false,
    PDO::ATTR_STRINGIFY_FETCHES => false,
    PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8",
]);

$tables = $pdo->query('SHOW TABLES;')->fetchAll();

var_export($tables);


