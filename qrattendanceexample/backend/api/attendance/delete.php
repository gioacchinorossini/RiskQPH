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

$attendanceId = (int)($data['attendanceId'] ?? 0);
if ($attendanceId <= 0) {
    respond(400, ['success' => false, 'message' => 'Invalid attendance id']);
}

// First, verify the attendance record exists and get event info for logging
$stmt = $db->prepare('SELECT a.id, a.user_id, a.event_id, a.check_in_time, a.check_out_time, a.status, 
                      e.title as event_title, u.name as student_name
                      FROM attendance a
                      JOIN events e ON e.id = a.event_id
                      JOIN users u ON u.id = a.user_id
                      WHERE a.id = ?');
$stmt->execute([$attendanceId]);
$attendance = $stmt->fetch();

if (!$attendance) {
    respond(404, ['success' => false, 'message' => 'Attendance record not found']);
}

// Delete the attendance record
$stmt = $db->prepare('DELETE FROM attendance WHERE id = ?');
try {
    $stmt->execute([$attendanceId]);
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to delete attendance record']);
}

respond(200, [
    'success' => true, 
    'message' => 'Attendance record deleted successfully',
    'deletedRecord' => [
        'id' => $attendanceId,
        'eventTitle' => $attendance['event_title'],
        'studentName' => $attendance['student_name']
    ]
]);
?> 