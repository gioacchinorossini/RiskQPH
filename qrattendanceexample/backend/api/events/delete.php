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
    respond(400, ['success' => false, 'message' => 'Invalid event id']);
}

$stmt = $db->prepare('DELETE FROM events WHERE id = ?');
try {
    $stmt->execute([$id]);
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to delete event']);
}

respond(200, ['success' => true]);
?>

