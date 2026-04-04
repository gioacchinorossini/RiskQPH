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

try {
    $db->beginTransaction();

    // Delete answers
    $db->prepare('DELETE sa FROM survey_answers sa JOIN survey_responses sr ON sa.response_id = sr.id WHERE sr.survey_id = ?')->execute([$id]);
    // Delete responses
    $db->prepare('DELETE FROM survey_responses WHERE survey_id = ?')->execute([$id]);
    // Delete options
    $db->prepare('DELETE so FROM survey_options so JOIN survey_questions sq ON so.question_id = sq.id WHERE sq.survey_id = ?')->execute([$id]);
    // Delete questions
    $db->prepare('DELETE FROM survey_questions WHERE survey_id = ?')->execute([$id]);
    // Delete survey
    $db->prepare('DELETE FROM surveys WHERE id = ?')->execute([$id]);

    $db->commit();
} catch (Throwable $e) {
    try { $db->rollBack(); } catch (Throwable $e2) {}
    respond(500, ['success' => false, 'message' => 'Failed to delete survey']);
}

respond(200, ['success' => true]);
?>

