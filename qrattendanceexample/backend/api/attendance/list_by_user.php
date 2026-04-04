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

$userId = isset($_GET['userId']) ? intval($_GET['userId']) : 0;
if ($userId <= 0) {
	respond(400, ['success' => false, 'message' => 'Invalid user id']);
}

$limit = isset($_GET['limit']) ? max(1, min(1000, intval($_GET['limit']))) : 500;

$stmt = $db->prepare('SELECT 
						 a.id,
						 a.user_id,
						 a.event_id,
						 a.check_in_time,
						 a.check_out_time,
						 a.status,
						 a.notes,
						 u.name AS student_name,
						 u.year_level,
						 u.department,
						 u.gender,
						 e.title AS event_title,
						 e.start_time AS event_start,
						 e.end_time AS event_end,
						 e.location AS event_location
				FROM attendance a
				JOIN users u ON u.id = a.user_id
				JOIN events e ON e.id = a.event_id
				WHERE a.user_id = ?
				ORDER BY COALESCE(a.check_in_time, e.start_time) DESC
				LIMIT ' . $limit);
$stmt->execute([$userId]);
$rows = $stmt->fetchAll();

$items = [];
foreach ($rows as $r) {
	$items[] = [
		'id' => (string)$r['id'],
		'eventId' => (string)$r['event_id'],
		'studentId' => (string)$r['user_id'],
		'studentName' => $r['student_name'],
		'yearLevel' => $r['year_level'],
		'department' => $r['department'],
		'gender' => $r['gender'],
		'eventTitle' => $r['event_title'],
		'eventStartTime' => $r['event_start'] ? (new DateTime($r['event_start']))->format('Y-m-d H:i:s') : null,
		'eventEndTime' => $r['event_end'] ? (new DateTime($r['event_end']))->format('Y-m-d H:i:s') : null,
		'location' => $r['event_location'],
		'checkInTime' => $r['check_in_time'] ? (new DateTime($r['check_in_time']))->format('Y-m-d H:i:s') : null,
		'checkOutTime' => $r['check_out_time'] ? (new DateTime($r['check_out_time']))->format('Y-m-d H:i:s') : null,
		'status' => $r['status'],
		'notes' => $r['notes'],
	];
}

respond(200, ['success' => true, 'attendances' => $items]);
?>

