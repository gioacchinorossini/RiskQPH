<?php
// Check if required tables exist and have data
header('Content-Type: text/plain');

echo "=== Database Tables Check ===\n\n";

require_once __DIR__ . '/../config/database.php';

try {
    $db = Database::connect();
    echo "✅ Database connection successful\n\n";
    
    // Check if events table exists
    echo "Checking events table...\n";
    $sql = "SHOW TABLES LIKE 'events'";
    $stmt = $db->query($sql);
    $result = $stmt->fetch();
    
    if ($result) {
        echo "✅ Events table exists\n";
        
        // Check events table structure
        $sql = "DESCRIBE events";
        $stmt = $db->query($sql);
        $columns = $stmt->fetchAll();
        echo "Events table columns:\n";
        foreach ($columns as $col) {
            echo "  - " . $col['Field'] . " (" . $col['Type'] . ")\n";
        }
        
        // Check events count
        $sql = "SELECT COUNT(*) as count FROM events";
        $stmt = $db->query($sql);
        $result = $stmt->fetch();
        echo "Events count: " . $result['count'] . "\n\n";
        
        // Show sample events
        if ($result['count'] > 0) {
            $sql = "SELECT id, title, start_time, end_time FROM events LIMIT 3";
            $stmt = $db->query($sql);
            $events = $stmt->fetchAll();
            echo "Sample events:\n";
            foreach ($events as $event) {
                echo "  - ID: " . $event['id'] . ", Title: " . $event['title'] . ", Start: " . $event['start_time'] . "\n";
            }
            echo "\n";
        }
    } else {
        echo "❌ Events table does not exist\n\n";
    }
    
    // Check if attendance table exists
    echo "Checking attendance table...\n";
    $sql = "SHOW TABLES LIKE 'attendance'";
    $stmt = $db->query($sql);
    $result = $stmt->fetch();
    
    if ($result) {
        echo "✅ Attendance table exists\n";
        
        // Check attendance table structure
        $sql = "DESCRIBE attendance";
        $stmt = $db->query($sql);
        $columns = $stmt->fetchAll();
        echo "Attendance table columns:\n";
        foreach ($columns as $col) {
            echo "  - " . $col['Field'] . " (" . $col['Type'] . ")\n";
        }
        
        // Check attendance count
        $sql = "SELECT COUNT(*) as count FROM attendance";
        $stmt = $db->query($sql);
        $result = $stmt->fetch();
        echo "Attendance count: " . $result['count'] . "\n\n";
    } else {
        echo "❌ Attendance table does not exist\n\n";
    }
    
    // Check if users table exists
    echo "Checking users table...\n";
    $sql = "SHOW TABLES LIKE 'users'";
    $stmt = $db->query($sql);
    $result = $stmt->fetch();
    
    if ($result) {
        echo "✅ Users table exists\n";
        
        // Check users count
        $sql = "SELECT COUNT(*) as count FROM users";
        $stmt = $db->query($sql);
        $result = $stmt->fetch();
        echo "Users count: " . $result['count'] . "\n\n";
    } else {
        echo "❌ Users table does not exist\n\n";
    }
    
} catch (Throwable $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
}

echo "=== Check Complete ===\n";
?> 