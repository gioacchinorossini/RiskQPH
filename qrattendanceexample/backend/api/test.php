<?php
// Create this file: backend/debug_timezone.php
echo "=== PHP Timezone Debug ===\n";
echo "date_default_timezone_get(): " . date_default_timezone_get() . "\n";
echo "Current PHP Time: " . date('Y-m-d H:i:s') . "\n";
echo "Current PHP Time (with timezone): " . date('Y-m-d H:i:s T') . "\n";

$dt = new DateTime();
echo "DateTime timezone: " . $dt->getTimezone()->getName() . "\n";
echo "DateTime formatted: " . $dt->format('Y-m-d H:i:s') . "\n";
echo "DateTime with timezone: " . $dt->format('Y-m-d H:i:s T') . "\n";

echo "\n=== Server Info ===\n";
echo "Server Time: " . $_SERVER['REQUEST_TIME'] . "\n";
echo "Server Time (formatted): " . date('Y-m-d H:i:s', $_SERVER['REQUEST_TIME']) . "\n";
?>