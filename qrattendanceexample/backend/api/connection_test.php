<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Test database connection
    require_once '../config/database.php';
    
    $response = [
        'status' => 'success',
        'message' => 'Connection successful',
        'timestamp' => date('Y-m-d H:i:s'),
        'server_time' => time(),
        'database_connected' => true
    ];
    
    http_response_code(200);
    echo json_encode($response);
    
} catch (Exception $e) {
    $response = [
        'status' => 'error',
        'message' => 'Connection failed: ' . $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s'),
        'server_time' => time(),
        'database_connected' => false
    ];
    
    http_response_code(500);
    echo json_encode($response);
}
?> 