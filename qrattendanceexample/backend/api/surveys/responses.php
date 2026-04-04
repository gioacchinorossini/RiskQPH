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
if ($surveyId <= 0) {
    respond(400, ['success' => false, 'message' => 'Invalid survey id']);
}

// Load responses basic
$respStmt = $db->prepare('SELECT id, user_id, submitted_at FROM survey_responses WHERE survey_id = ? ORDER BY submitted_at DESC');
$ansStmt = $db->prepare('SELECT sa.question_id, sa.option_id, sa.answer_text, so.option_text FROM survey_answers sa LEFT JOIN survey_options so ON so.id = sa.option_id WHERE sa.response_id = ? ORDER BY sa.id ASC');

$responses = [];
try {
    $respStmt->execute([$surveyId]);
    while ($r = $respStmt->fetch()) {
        $responseId = (int)$r['id'];
        $answers = [];
        $ansStmt->execute([$responseId]);
        while ($a = $ansStmt->fetch()) {
            $answers[] = [
                'question_id' => (string)$a['question_id'],
                'option_id' => $a['option_id'] !== null ? (string)$a['option_id'] : null,
                'option_text' => $a['option_text'] ?? null,
                'answer_text' => $a['answer_text'] ?? null,
            ];
        }
        $responses[] = [
            'id' => (string)$responseId,
            'user_id' => (string)$r['user_id'],
            'submitted_at' => (new DateTime($r['submitted_at']))->format('Y-m-d H:i:s'),
            'answers' => $answers,
        ];
    }
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to load responses']);
}

respond(200, ['success' => true, 'survey_id' => (string)$surveyId, 'responses' => $responses]);
?>

