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

$eventId = isset($_GET['event_id']) ? (int)$_GET['event_id'] : 0;
$userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
if ($eventId <= 0) {
    respond(400, ['success' => false, 'message' => 'Invalid event id']);
}

$sql = 'SELECT s.id, s.title, s.description, s.is_active, s.created_by, s.created_at, s.updated_at
        FROM surveys s
        WHERE s.event_id = ?
        ORDER BY s.created_at DESC';

$stmt = $db->prepare($sql);
try {
    $stmt->execute([$eventId]);
    $surveys = [];
    while ($row = $stmt->fetch()) {
        $hasSubmitted = false;
        if ($userId > 0) {
            $chk = $db->prepare('SELECT id FROM survey_responses WHERE survey_id = ? AND user_id = ? LIMIT 1');
            $chk->execute([$row['id'], $userId]);
            $hasSubmitted = (bool)$chk->fetch();
        }
        $surveys[] = [
            'id' => (string)$row['id'],
            'event_id' => (string)$eventId,
            'title' => $row['title'],
            'description' => $row['description'] ?? null,
            'is_active' => (bool)$row['is_active'],
            'created_by' => (string)$row['created_by'],
            'created_at' => (new DateTime($row['created_at']))->format('Y-m-d H:i:s'),
            'updated_at' => (new DateTime($row['updated_at']))->format('Y-m-d H:i:s'),
            'has_submitted' => $hasSubmitted,
        ];
    }
    respond(200, ['success' => true, 'surveys' => $surveys]);
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to list surveys']);
}
?>

