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

$title = trim($data['title'] ?? '');
$description = trim($data['description'] ?? '');
$startTime = trim($data['start_time'] ?? ''); // ISO string
$endTime = trim($data['end_time'] ?? ''); // ISO string
$location = trim($data['location'] ?? '');
$organizer = trim($data['organizer'] ?? '');
$targetDepartment = trim($data['target_department'] ?? '');
$targetCourse = trim($data['target_course'] ?? '');
$targetYearLevel = trim($data['target_year_level'] ?? '');
$createdBy = (int)($data['created_by'] ?? 0);

if ($title === '' || $startTime === '' || $endTime === '' || $location === '' || $createdBy <= 0) {
    respond(400, ['success' => false, 'message' => 'Missing required fields']);
}

if (mb_strlen($title) > 200) {
    respond(400, ['success' => false, 'message' => 'Title too long']);
}

try {
    $startDateTime = new DateTime($startTime);
    $endDateTime = new DateTime($endTime);
    
    // Validate that end time is after start time
    if ($endDateTime <= $startDateTime) {
        respond(400, ['success' => false, 'message' => 'End time must be after start time']);
    }
} catch (Throwable $e) {
    respond(400, ['success' => false, 'message' => 'Invalid date format']);
}

$stmt = $db->prepare('INSERT INTO events (title, description, start_time, end_time, location, organizer, created_by, created_at, updated_at, is_active, thumbnail, target_department, target_course, target_year_level)
                      VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW(), 1, NULL, ?, ?, ?)');
try {
    $stmt->execute([$title, $description, $startDateTime->format('Y-m-d H:i:s'), $endDateTime->format('Y-m-d H:i:s'), $location, $organizer, $createdBy, ($targetDepartment !== '' ? $targetDepartment : null), ($targetCourse !== '' ? $targetCourse : null), ($targetYearLevel !== '' ? $targetYearLevel : null)]);
    $id = (int)$db->lastInsertId();
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to create event']);
}

$nowIso = (new DateTime())->format('Y-m-d H:i:s');

respond(201, [
  'success' => true,
  'event' => [
    'id' => (string)$id,
    'title' => $title,
    'description' => $description,
    'start_time' => $startDateTime->format('Y-m-d H:i:s'),
    'end_time' => $endDateTime->format('Y-m-d H:i:s'),
    'location' => $location,
    'organizer' => $organizer,
    'target_department' => $targetDepartment !== '' ? $targetDepartment : null,
    'target_course' => $targetCourse !== '' ? $targetCourse : null,
    'target_year_level' => $targetYearLevel !== '' ? $targetYearLevel : null,
    'created_by' => (string)$createdBy,
    'created_at' => $nowIso,
    'updated_at' => $nowIso,
    'is_active' => true,
    'thumbnail' => null,
  ]
]);
?>

