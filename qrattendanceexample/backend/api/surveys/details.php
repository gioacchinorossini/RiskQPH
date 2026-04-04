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

$surveyId = isset($_GET['survey_id']) ? (int)$_GET['survey_id'] : 0;
$userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
if ($surveyId <= 0) {
    respond(400, ['success' => false, 'message' => 'Invalid survey id']);
}

// Load survey
$stmt = $db->prepare('SELECT id, event_id, title, description, is_active, created_by, created_at, updated_at FROM surveys WHERE id = ?');
try {
    $stmt->execute([$surveyId]);
    $survey = $stmt->fetch();
    if (!$survey) {
        respond(404, ['success' => false, 'message' => 'Survey not found']);
    }
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to load survey']);
}

// Load questions
$qStmt = $db->prepare('SELECT id, question_text, question_type, sort_order FROM survey_questions WHERE survey_id = ? ORDER BY sort_order ASC, id ASC');
// Load options per question later
$oStmt = $db->prepare('SELECT id, option_text, sort_order FROM survey_options WHERE question_id = ? ORDER BY sort_order ASC, id ASC');

$questions = [];
try {
    $qStmt->execute([$surveyId]);
    while ($q = $qStmt->fetch()) {
        $questionId = (int)$q['id'];
        $options = [];
        $oStmt->execute([$questionId]);
        while ($o = $oStmt->fetch()) {
            $options[] = [
                'id' => (string)$o['id'],
                'option_text' => $o['option_text'],
                'sort_order' => (int)$o['sort_order'],
            ];
        }
        $questions[] = [
            'id' => (string)$questionId,
            'survey_id' => (string)$surveyId,
            'question_text' => $q['question_text'],
            'question_type' => $q['question_type'],
            'sort_order' => (int)$q['sort_order'],
            'options' => $options,
        ];
    }
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to load questions']);
}

$hasSubmitted = false;
if ($userId > 0) {
    try {
        $rs = $db->prepare('SELECT id FROM survey_responses WHERE survey_id = ? AND user_id = ? LIMIT 1');
        $rs->execute([$surveyId, $userId]);
        $hasSubmitted = (bool)$rs->fetch();
    } catch (Throwable $e) {}
}

respond(200, [
    'success' => true,
    'survey' => [
        'id' => (string)$survey['id'],
        'event_id' => (string)$survey['event_id'],
        'title' => $survey['title'],
        'description' => $survey['description'] ?? null,
        'is_active' => (bool)$survey['is_active'],
        'created_by' => (string)$survey['created_by'],
        'created_at' => (new DateTime($survey['created_at']))->format('Y-m-d H:i:s'),
        'updated_at' => (new DateTime($survey['updated_at']))->format('Y-m-d H:i:s'),
        'has_submitted' => $hasSubmitted,
        'questions' => $questions,
    ],
]);
?>

