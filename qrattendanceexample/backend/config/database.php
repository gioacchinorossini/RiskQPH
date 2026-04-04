<?php
// Force PHP to use your server's local timezone
date_default_timezone_set('Asia/Manila'); // Replace with your actual timezone

class Database
{
    public static function connect(): PDO
    {
        // Adjust credentials for your XAMPP MySQL
        $host = '127.0.0.1';
        $db = 'qrattendance';
        $user = 'root';
        $pass = '';
        $charset = 'utf8mb4';

        $dsn = "mysql:host=$host;dbname=$db;charset=$charset";
        $options = [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ];
        return new PDO($dsn, $user, $pass, $options);
    }
}
?>

