<?php
// Test file for Events Analytics API
header('Content-Type: text/plain');

echo "=== Events Analytics API Test ===\n\n";

// Test the admin analytics endpoint
$url = 'http://localhost/qrattendancebyxiansqlstepbasefunctions/backend/api/events/admin_analytics.php';

echo "Testing URL: $url\n\n";

// Test with different filter combinations
$testCases = [
    'All events' => '?date_filter=all&status_filter=all&sort_by=date',
    'Today events' => '?date_filter=today&status_filter=all&sort_by=date',
    'Active events' => '?date_filter=all&status_filter=active&sort_by=date',
    'Sort by attendance' => '?date_filter=all&status_filter=all&sort_by=attendance'
];

foreach ($testCases as $description => $params) {
    echo "Testing: $description\n";
    echo "URL: $url$params\n";
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url . $params);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    if ($error) {
        echo "CURL Error: $error\n";
    } else {
        echo "HTTP Code: $httpCode\n";
        if ($httpCode === 200) {
            $data = json_decode($response, true);
            if ($data && isset($data['success'])) {
                echo "Success: " . ($data['success'] ? 'Yes' : 'No') . "\n";
                echo "Events Count: " . count($data['events']) . "\n";
                if (isset($data['summary'])) {
                    echo "Total Events: " . $data['summary']['total_events'] . "\n";
                    echo "Active Events: " . $data['summary']['active_events'] . "\n";
                    echo "Upcoming Events: " . $data['summary']['upcoming_events'] . "\n";
                    echo "Completed Events: " . $data['summary']['completed_events'] . "\n";
                }
            } else {
                echo "Response: $response\n";
            }
        } else {
            echo "Response: $response\n";
        }
    }
    echo "\n" . str_repeat('-', 50) . "\n\n";
}

echo "=== Test Complete ===\n";
?> 