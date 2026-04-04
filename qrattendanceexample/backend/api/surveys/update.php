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
if (!is_array($data)) { $data = $_POST; }

$id = (int)($data['id'] ?? 0);
if ($id <= 0) {
    respond(400, ['success' => false, 'message' => 'Invalid survey id']);
}

$title = isset($data['title']) ? trim((string)$data['title']) : null;
$description = array_key_exists('description', $data) ? (trim((string)$data['description']) === '' ? null : trim((string)$data['description'])) : null;
$isActive = null;
if (array_key_exists('is_active', $data)) { $isActive = (bool)$data['is_active']; }
elseif (array_key_exists('isActive', $data)) { $isActive = (bool)$data['isActive']; }

$fields = [];
$params = [];
if ($title !== null) { $fields[] = 'title = ?'; $params[] = $title; }
if ($description !== null) { $fields[] = 'description = ?'; $params[] = $description; }
if ($isActive !== null) { $fields[] = 'is_active = ?'; $params[] = $isActive ? 1 : 0; }

if (empty($fields)) {
    respond(400, ['success' => false, 'message' => 'No fields to update']);
}

$params[] = $id;
$sql = 'UPDATE surveys SET ' . implode(', ', $fields) . ', updated_at = NOW() WHERE id = ?';
$stmt = $db->prepare($sql);
try {
    $stmt->execute($params);
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to update survey']);
}

respond(200, ['success' => true]);
?>

