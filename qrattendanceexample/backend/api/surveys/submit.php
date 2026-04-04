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

$surveyId = (int)($data['survey_id'] ?? 0);
$userId = (int)($data['user_id'] ?? 0);
$answers = $data['answers'] ?? [];

if ($surveyId <= 0 || $userId <= 0 || !is_array($answers) || empty($answers)) {
    respond(400, ['success' => false, 'message' => 'Missing required fields']);
}

try {
    $db->beginTransaction();

    // Ensure not already submitted
    $check = $db->prepare('SELECT id FROM survey_responses WHERE survey_id = ? AND user_id = ? LIMIT 1');
    $check->execute([$surveyId, $userId]);
    if ($check->fetch()) {
      $db->rollBack();
      respond(400, ['success' => false, 'message' => 'You already submitted this survey']);
    }

    // Create response record
    $stmt = $db->prepare('INSERT INTO survey_responses (survey_id, user_id, submitted_at) VALUES (?, ?, NOW())');
    $stmt->execute([$surveyId, $userId]);
    $responseId = (int)$db->lastInsertId();

    $ansStmt = $db->prepare('INSERT INTO survey_answers (response_id, question_id, option_id, answer_text) VALUES (?, ?, ?, ?)');

    foreach ($answers as $ans) {
        $questionId = (int)($ans['question_id'] ?? 0);
        if ($questionId <= 0) { continue; }
        $optionIds = $ans['option_ids'] ?? null; // array for choice type
        $answerText = isset($ans['answer_text']) ? trim((string)$ans['answer_text']) : null;

        if (is_array($optionIds) && !empty($optionIds)) {
            foreach ($optionIds as $oid) {
                $oidInt = (int)$oid;
                if ($oidInt <= 0) { continue; }
                $ansStmt->execute([$responseId, $questionId, $oidInt, null]);
            }
        } else {
            $ansStmt->execute([$responseId, $questionId, null, ($answerText !== '' ? $answerText : null)]);
        }
    }

    $db->commit();
} catch (Throwable $e) {
    try { $db->rollBack(); } catch (Throwable $e2) {}
    respond(500, ['success' => false, 'message' => 'Failed to submit survey']);
}

respond(201, ['success' => true]);
?>

