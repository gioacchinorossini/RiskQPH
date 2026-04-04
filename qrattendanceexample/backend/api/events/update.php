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

$id = (int)($data['id'] ?? 0);
if ($id <= 0) {
    respond(400, ['success' => false, 'message' => 'Invalid event id']);
}

$title = isset($data['title']) ? trim($data['title']) : null;
$description = isset($data['description']) ? trim($data['description']) : null;
$location = isset($data['location']) ? trim($data['location']) : null;
// Optional targeting updates (empty string clears)
$targetDepartment = array_key_exists('target_department', $data) ? trim((string)$data['target_department']) : null;
$targetCourse = array_key_exists('target_course', $data) ? trim((string)$data['target_course']) : null;
$targetYearLevel = array_key_exists('target_year_level', $data) ? trim((string)$data['target_year_level']) : null;
// Support multiple casing/keys from different clients
$isActive = null;
if (array_key_exists('is_active', $data)) { $isActive = (bool)$data['is_active']; }
elseif (array_key_exists('isActive', $data)) { $isActive = (bool)$data['isActive']; }

// Support both 'date' (legacy: maps to start_time), and explicit 'start_time'/'end_time'
$startTimeRaw = null;
if (isset($data['start_time'])) { $startTimeRaw = trim($data['start_time']); }
elseif (isset($data['date'])) { $startTimeRaw = trim($data['date']); }

$endTimeRaw = isset($data['end_time']) ? trim($data['end_time']) : null;

$fields = [];
$params = [];

if ($title !== null) { $fields[] = 'title = ?'; $params[] = $title; }
if ($description !== null) { $fields[] = 'description = ?'; $params[] = $description; }
if ($location !== null) { $fields[] = 'location = ?'; $params[] = $location; }
if ($targetDepartment !== null) { $fields[] = 'target_department = ?'; $params[] = ($targetDepartment === '' ? null : $targetDepartment); }
if ($targetCourse !== null) { $fields[] = 'target_course = ?'; $params[] = ($targetCourse === '' ? null : $targetCourse); }
if ($targetYearLevel !== null) { $fields[] = 'target_year_level = ?'; $params[] = ($targetYearLevel === '' ? null : $targetYearLevel); }
// Validate and set start_time if provided
if ($startTimeRaw !== null && $startTimeRaw !== '') {
    try {
        $dtStart = new DateTime($startTimeRaw);
        $fields[] = 'start_time = ?';
        $params[] = $dtStart->format('Y-m-d H:i:s');
    } catch (Throwable $e) {
        respond(400, ['success' => false, 'message' => 'Invalid start_time format']);
    }
}

// Validate and set end_time if provided
if ($endTimeRaw !== null && $endTimeRaw !== '') {
    try {
        $dtEnd = new DateTime($endTimeRaw);
        $fields[] = 'end_time = ?';
        $params[] = $dtEnd->format('Y-m-d H:i:s');
    } catch (Throwable $e) {
        respond(400, ['success' => false, 'message' => 'Invalid end_time format']);
    }
}
if ($isActive !== null) { $fields[] = 'is_active = ?'; $params[] = $isActive ? 1 : 0; }

// If both start and end are provided, ensure logical order
if (isset($dtStart) && isset($dtEnd) && $dtEnd <= $dtStart) {
    respond(400, ['success' => false, 'message' => 'End time must be after start time']);
}

if (empty($fields)) {
    respond(400, ['success' => false, 'message' => 'No fields to update']);
}

$params[] = $id;
$fields[] = 'updated_at = NOW()';
$sql = 'UPDATE events SET ' . implode(', ', $fields) . ' WHERE id = ?';
$stmt = $db->prepare($sql);

try {
    $stmt->execute($params);
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to update event']);
}

respond(200, ['success' => true]);
?>

