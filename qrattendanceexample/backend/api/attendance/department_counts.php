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

// Support both eventId and event_id for convenience
$eventId = 0;
if (isset($_GET['eventId'])) {
    $eventId = intval($_GET['eventId']);
} elseif (isset($_GET['event_id'])) {
    $eventId = intval($_GET['event_id']);
}

if ($eventId <= 0) {
    respond(400, ['success' => false, 'message' => 'Invalid event id']);
}

// Count unique users per department that actually attended (exclude explicit 'absent')
// Joins users to read department metadata
$sql = "
    SELECT 
        COALESCE(NULLIF(TRIM(u.department), ''), 'Unknown') AS department,
        COUNT(DISTINCT a.user_id) AS attended
    FROM attendance a
    JOIN users u ON u.id = a.user_id
    WHERE a.event_id = ?
      AND (a.status IS NULL OR LOWER(a.status) <> 'absent')
    GROUP BY COALESCE(NULLIF(TRIM(u.department), ''), 'Unknown')
    ORDER BY attended DESC, department ASC
";

$stmt = $db->prepare($sql);
$stmt->execute([$eventId]);
$rows = $stmt->fetchAll();

$data = [];
foreach ($rows as $r) {
    $data[] = [
        'department' => (string)$r['department'],
        'attended' => intval($r['attended'])
    ];
}

respond(200, ['success' => true, 'data' => $data, 'eventId' => (string)$eventId]);
?>

