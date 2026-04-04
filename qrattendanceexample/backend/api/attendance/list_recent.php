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

$limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 200;

$sql = 'SELECT a.id, a.user_id, a.event_id, a.check_in_time, a.check_out_time, a.status, a.notes, u.name AS student_name
        FROM attendance a
        JOIN users u ON u.id = a.user_id
        ORDER BY a.check_in_time DESC
        LIMIT ' . $limit;

$rows = $db->query($sql)->fetchAll();

$items = [];
foreach ($rows as $r) {
    $items[] = [
        'id' => (string)$r['id'],
        'eventId' => (string)$r['event_id'],
        'studentId' => (string)$r['user_id'],
        'studentName' => $r['student_name'],
        'checkInTime' => $r['check_in_time'] ? (new DateTime($r['check_in_time']))->format('Y-m-d H:i:s') : null,
        'checkOutTime' => $r['check_out_time'] ? (new DateTime($r['check_out_time']))->format('Y-m-d H:i:s') : null,
        'status' => $r['status'],
        'notes' => $r['notes'],
      ];
}

respond(200, ['success' => true, 'attendances' => $items]);
?>

