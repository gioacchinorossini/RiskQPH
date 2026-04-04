<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

require_once __DIR__ . '/../../config/database.php';

function respond($code, $payload)
{
    http_response_code($code);
    echo json_encode($payload);
    exit();
}

try {
    $db = Database::connect();
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Database connection failed']);
}

try {
    $stmt = $db->prepare('SELECT id, name, description, is_active, created_at, updated_at FROM locations WHERE is_active = 1 ORDER BY name ASC');
    $stmt->execute();
    $rows = $stmt->fetchAll();
    $locations = array_map(function ($row) {
        return [
            'id' => (string)$row['id'],
            'name' => $row['name'],
            'description' => $row['description'],
            'is_active' => (bool)$row['is_active'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at'],
        ];
    }, $rows ?: []);

    respond(200, ['success' => true, 'locations' => $locations]);
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to list locations']);
}
?>

