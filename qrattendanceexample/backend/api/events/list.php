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

$sql = 'SELECT id, title, description, start_time, end_time, location, organizer, created_by, created_at, updated_at, is_active, thumbnail, target_department, target_course, target_year_level
        FROM events
        ORDER BY start_time DESC';
$stmt = $db->query($sql);
$rows = $stmt->fetchAll();

$events = [];
foreach ($rows as $row) {
    $startTimeIso = (new DateTime($row['start_time']))->format('Y-m-d H:i:s');
    $endTimeIso = (new DateTime($row['end_time']))->format('Y-m-d H:i:s');
    $createdIso = (new DateTime($row['created_at']))->format('Y-m-d H:i:s');
    $updatedIso = isset($row['updated_at']) ? (new DateTime($row['updated_at']))->format('Y-m-d H:i:s') : $createdIso;
    $events[] = [
        'id' => (string)$row['id'],
        'title' => $row['title'],
        'description' => $row['description'] ?? '',
        'start_time' => $startTimeIso,
        'end_time' => $endTimeIso,
        'location' => $row['location'] ?? '',
        'organizer' => $row['organizer'] ?? '',
        'created_by' => (string)$row['created_by'],
        'created_at' => $createdIso,
        'updated_at' => $updatedIso,
        'is_active' => (bool)$row['is_active'],
        'thumbnail' => $row['thumbnail'] ?? null,
        'target_department' => $row['target_department'] ?? null,
        'target_course' => $row['target_course'] ?? null,
        'target_year_level' => $row['target_year_level'] ?? null,
    ];
}

respond(200, ['success' => true, 'events' => $events]);
?>

