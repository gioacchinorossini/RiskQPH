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

$eventId = (int)($data['event_id'] ?? 0);
$title = trim($data['title'] ?? '');
$description = trim($data['description'] ?? '');
$createdBy = (int)($data['created_by'] ?? 0);
$questions = $data['questions'] ?? [];

if ($eventId <= 0 || $title === '' || $createdBy <= 0) {
    respond(400, ['success' => false, 'message' => 'Missing required fields']);
}

if (!is_array($questions)) {
    $questions = [];
}

try {
    $db->beginTransaction();

    $stmt = $db->prepare('INSERT INTO surveys (event_id, title, description, is_active, created_by, created_at, updated_at) VALUES (?, ?, ?, 1, ?, NOW(), NOW())');
    $stmt->execute([$eventId, $title, $description !== '' ? $description : null, $createdBy]);
    $surveyId = (int)$db->lastInsertId();

    $qStmt = $db->prepare('INSERT INTO survey_questions (survey_id, question_text, question_type, sort_order) VALUES (?, ?, ?, ?)');
    $oStmt = $db->prepare('INSERT INTO survey_options (question_id, option_text, sort_order) VALUES (?, ?, ?)');

    $order = 0;
    foreach ($questions as $q) {
        $qText = trim((string)($q['text'] ?? ''));
        if ($qText === '') { continue; }
        $qType = (string)($q['type'] ?? 'single_choice');
        if (!in_array($qType, ['single_choice','multiple_choice','text'], true)) {
            $qType = 'single_choice';
        }
        $qStmt->execute([$surveyId, $qText, $qType, $order++]);
        $questionId = (int)$db->lastInsertId();

        if (isset($q['options']) && is_array($q['options'])) {
            $optOrder = 0;
            foreach ($q['options'] as $opt) {
                $optText = trim((string)$opt);
                if ($optText === '') { continue; }
                $oStmt->execute([$questionId, $optText, $optOrder++]);
            }
        }
    }

    $db->commit();
} catch (Throwable $e) {
    try { $db->rollBack(); } catch (Throwable $e2) {}
    respond(500, ['success' => false, 'message' => 'Failed to create survey']);
}

respond(201, [
    'success' => true,
    'survey' => [
        'id' => (string)$surveyId,
        'event_id' => (string)$eventId,
        'title' => $title,
        'description' => $description !== '' ? $description : null,
        'is_active' => true,
        'created_by' => (string)$createdBy,
    ]
]);
?>

