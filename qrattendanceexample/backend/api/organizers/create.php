<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
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

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);
if (!is_array($data)) {
    $data = $_POST;
}

$name = trim($data['name'] ?? '');
$description = trim($data['description'] ?? '');

if ($name === '') {
    respond(400, ['success' => false, 'message' => 'Name is required']);
}

if (mb_strlen($name) > 200) {
    respond(400, ['success' => false, 'message' => 'Name too long']);
}

try {
    $stmt = $db->prepare('INSERT INTO organizers (name, description, is_active, created_at, updated_at) VALUES (?, ?, 1, NOW(), NOW())');
    $stmt->execute([$name, $description]);
    $id = (int)$db->lastInsertId();
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to create organizer']);
}

$nowIso = (new DateTime())->format('Y-m-d H:i:s');

respond(201, [
  'success' => true,
  'organizer' => [
    'id' => (string)$id,
    'name' => $name,
    'description' => $description,
    'is_active' => true,
    'created_at' => $nowIso,
    'updated_at' => $nowIso,
  ]
]);
?>

