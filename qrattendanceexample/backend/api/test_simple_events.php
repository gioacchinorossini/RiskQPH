<?php
// Simple test for Events Analytics API
header('Content-Type: text/plain');

echo "=== Simple Events Analytics Test ===\n\n";

// Test database connection first
require_once __DIR__ . '/../config/database.php';

try {
    echo "Testing database connection...\n";
    $db = Database::connect();
    echo "✅ Database connection successful\n\n";
    
    // Test basic events query
    echo "Testing basic events query...\n";
    $sql = "SELECT COUNT(*) as count FROM events";
    $stmt = $db->query($sql);
    $result = $stmt->fetch();
    echo "Total events in database: " . $result['count'] . "\n\n";
    
    // Test basic attendance query
    echo "Testing basic attendance query...\n";
    $sql = "SELECT COUNT(*) as count FROM attendance";
    $stmt = $db->query($sql);
    $result = $stmt->fetch();
    echo "Total attendance records: " . $result['count'] . "\n\n";
    
    // Test the actual analytics query
    echo "Testing analytics query...\n";
    $sql = "
        SELECT 
            e.id,
            e.title,
            e.description,
            e.start_time,
            e.end_time,
            e.location,
            e.created_at,
            e.is_active,
            COUNT(DISTINCT a.user_id) as total_attendees,
            SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
            SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) as late_count,
            SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count,
            SUM(CASE WHEN a.status = 'left_early' THEN 1 ELSE 0 END) as left_early_count
        FROM events e
        LEFT JOIN attendance a ON e.id = a.event_id
        GROUP BY e.id
        LIMIT 5
    ";
    
    $stmt = $db->query($sql);
    $events = $stmt->fetchAll();
    
    echo "Found " . count($events) . " events with analytics:\n";
    foreach ($events as $event) {
        echo "- Event: " . $event['title'] . " (ID: " . $event['id'] . ")\n";
        echo "  Attendees: " . $event['total_attendees'] . "\n";
        echo "  Present: " . $event['present_count'] . "\n";
        echo "  Late: " . $event['late_count'] . "\n";
        echo "  Absent: " . $event['absent_count'] . "\n";
        echo "  Left Early: " . $event['left_early_count'] . "\n\n";
    }
    
} catch (Throwable $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
}

echo "=== Test Complete ===\n";
?> 