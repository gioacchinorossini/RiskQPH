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

// Total submissions
$total = 0;
try {
    $r = $db->prepare('SELECT COUNT(*) AS c FROM survey_responses WHERE survey_id = ?');
    $r->execute([$surveyId]);
    $row = $r->fetch();
    $total = (int)$row['c'];
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to compute total']);
}

// Questions with options and counts
$qStmt = $db->prepare('SELECT id, question_text, question_type FROM survey_questions WHERE survey_id = ? ORDER BY sort_order ASC, id ASC');
$oStmt = $db->prepare('SELECT id, option_text FROM survey_options WHERE question_id = ? ORDER BY sort_order ASC, id ASC');
$countChoice = $db->prepare('SELECT option_id, COUNT(*) AS c FROM survey_answers WHERE question_id = ? AND option_id IS NOT NULL GROUP BY option_id');
$countText = $db->prepare('SELECT COUNT(*) AS c FROM survey_answers WHERE question_id = ? AND option_id IS NULL AND (answer_text IS NOT NULL AND answer_text <> "")');

$questions = [];
try {
    $qStmt->execute([$surveyId]);
    while ($q = $qStmt->fetch()) {
        $qid = (int)$q['id'];
        $type = $q['question_type'];
        $entry = [
            'id' => (string)$qid,
            'text' => $q['question_text'],
            'type' => $type,
        ];
        if ($type === 'text') {
            $countText->execute([$qid]);
            $row = $countText->fetch();
            $entry['text_answer_count'] = (int)($row['c'] ?? 0);
        } else {
            $oStmt->execute([$qid]);
            $options = [];
            $optMap = [];
            while ($o = $oStmt->fetch()) {
                $optId = (int)$o['id'];
                $optMap[$optId] = [
                    'id' => (string)$optId,
                    'text' => $o['option_text'],
                    'count' => 0,
                ];
            }
            $countChoice->execute([$qid]);
            while ($c = $countChoice->fetch()) {
                $oid = (int)$c['option_id'];
                if (isset($optMap[$oid])) {
                    $optMap[$oid]['count'] = (int)$c['c'];
                }
            }
            $options = array_values($optMap);
            $entry['options'] = $options;
        }
        $questions[] = $entry;
    }
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to compute stats']);
}

respond(200, [
    'success' => true,
    'survey_id' => (string)$surveyId,
    'total_submissions' => $total,
    'questions' => $questions,
]);
?>

