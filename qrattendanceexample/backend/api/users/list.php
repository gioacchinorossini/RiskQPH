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

$sql = 'SELECT id, name, email, student_id, role, created_at, updated_at
        FROM users
        ORDER BY created_at DESC';
$stmt = $db->query($sql);
$rows = $stmt->fetchAll();

$users = [];
foreach ($rows as $row) {
    $createdIso = (new DateTime($row['created_at']))->format('Y-m-d H:i:s');
    $updatedIso = $row['updated_at'] ? (new DateTime($row['updated_at']))->format('Y-m-d H:i:s') : null;
    
    $users[] = [
        'id' => (string)$row['id'],
        'name' => $row['name'],
        'email' => $row['email'],
        'student_id' => $row['student_id'],
        'role' => $row['role'],
        'created_at' => $createdIso,
        'updated_at' => $updatedIso,
    ];
}

respond(200, ['success' => true, 'users' => $users]);
?> 