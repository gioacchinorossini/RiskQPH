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

function respond($code, $payload) {
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

$eventId = (int)($data['eventId'] ?? 0);
if ($eventId <= 0) {
    respond(400, ['success' => false, 'message' => 'Missing or invalid eventId']);
}

// Fetch event and ensure it has ended
$stmtEvent = $db->prepare('SELECT id, end_time, target_department, target_course, target_year_level FROM events WHERE id = ? LIMIT 1');
$stmtEvent->execute([$eventId]);
$event = $stmtEvent->fetch();
if (!$event) {
    respond(404, ['success' => false, 'message' => 'Event not found']);
}

$now = new DateTime();
$endTime = new DateTime($event['end_time']);
if ($endTime > $now) {
    respond(409, ['success' => false, 'message' => 'Event has not ended yet']);
}

// Build audience filter based on event targeting
$conditions = ['u.role = \"student\"'];
$params = [':eventId' => $eventId];

if (!empty($event['target_department'])) {
    $conditions[] = 'u.department = :dept';
    $params[':dept'] = (string)$event['target_department'];
}
if (!empty($event['target_course'])) {
    $conditions[] = 'u.course = :course';
    $params[':course'] = (string)$event['target_course'];
}
if (!empty($event['target_year_level'])) {
    $conditions[] = 'u.year_level = :yearlvl';
    $params[':yearlvl'] = (string)$event['target_year_level'];
}

$where = implode(' AND ', $conditions);

// Insert ABSENT attendance for eligible students who do not have any attendance record for this event
$sql = "INSERT INTO attendance (user_id, event_id, status, notes)
        SELECT u.id, :eventId, 'absent', 'Auto-marked absent'
        FROM users u
        LEFT JOIN attendance a ON a.user_id = u.id AND a.event_id = :eventId
        WHERE $where AND a.id IS NULL";

$stmt = $db->prepare($sql);
$stmt->execute($params);
$inserted = $stmt->rowCount();

respond(200, [
    'success' => true,
    'eventId' => (string)$eventId,
    'inserted' => $inserted,
    'message' => $inserted > 0 ? 'Absent records created' : 'No new absences to mark',
]);
?>

