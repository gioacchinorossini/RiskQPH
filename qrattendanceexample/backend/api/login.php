<?php
// Login endpoint: POST JSON { email, password }

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

require_once __DIR__ . '/../config/database.php';

function respond($code, $payload)
{
    http_response_code($code);
    echo json_encode($payload);
    exit();
}

try {
    $db = Database::connect();
} catch (Throwable $e) {
    respond(500, [
        'success' => false,
        'message' => 'Database connection failed',
    ]);
}

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);
if (!is_array($data)) {
    $data = $_POST;
}

$email = trim($data['email'] ?? '');
$password = (string)($data['password'] ?? '');

if ($email === '' || $password === '') {
    respond(400, [
        'success' => false,
        'message' => 'Email and password are required',
    ]);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(400, [
        'success' => false,
        'message' => 'Invalid email address',
    ]);
}

$stmt = $db->prepare('SELECT id, name, email, password_hash, student_id, year_level, department, course, gender, birthdate, role, created_at, updated_at FROM users WHERE email = ? LIMIT 1');
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user || !password_verify($password, $user['password_hash'])) {
    respond(401, [
        'success' => false,
        'message' => 'Invalid credentials',
    ]);
}

$createdAt = null;
try {
    $dt = new DateTime($user['created_at']);
    $createdAt = $dt->format('Y-m-d H:i:s');
} catch (Throwable $e) {
    $createdAt = (new DateTime())->format('Y-m-d H:i:s');
}

respond(200, [
    'success' => true,
    'user' => [
        'id' => (string)$user['id'],
        'name' => $user['name'],
        'email' => $user['email'],
        'studentId' => $user['student_id'] ?? '',
        'yearLevel' => $user['year_level'] ?? '',
        'department' => $user['department'] ?? '',
        'course' => $user['course'] ?? '',
        'gender' => $user['gender'] ?? '',
        'birthdate' => isset($user['birthdate']) ? (new DateTime($user['birthdate']))->format('Y-m-d') : null,
        'role' => $user['role'],
        'createdAt' => $createdAt,
        'updatedAt' => isset($user['updated_at']) ? (new DateTime($user['updated_at']))->format('Y-m-d H:i:s') : $createdAt,
    ],
]);
?>

