<?php
// Registration endpoint: POST JSON { name, email, password, studentId, yearLevel, department, gender, birthdate, role }

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

// Read input
$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

if (!is_array($data)) {
    // Support application/x-www-form-urlencoded fallback
    $data = $_POST;
}

$name = trim($data['name'] ?? '');
$email = trim($data['email'] ?? '');
$password = (string)($data['password'] ?? '');
$studentId = trim($data['studentId'] ?? '');
$yearLevel = trim($data['yearLevel'] ?? '');
$department = trim($data['department'] ?? '');
$course = trim($data['course'] ?? '');
$gender = trim($data['gender'] ?? '');
$birthdate = trim($data['birthdate'] ?? ''); // expected format: YYYY-MM-DD
// Do not accept role from client; default all signups to 'student'
$roleInput = 'student';

if ($name === '' || $email === '' || $password === '' || $studentId === '' || $yearLevel === '' || $department === '' || $course === '' || $gender === '' || $birthdate === '') {
    respond(400, [
        'success' => false,
        'message' => 'All fields are required',
    ]);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(400, [
        'success' => false,
        'message' => 'Invalid email address',
    ]);
}

// Enforce school email domain
if (!preg_match('/@csab\.edu\.ph$/i', $email)) {
    respond(400, [
        'success' => false,
        'message' => 'Email must be a csab.edu.ph address',
    ]);
}

if (mb_strlen($name) < 2 || mb_strlen($name) > 100) {
    respond(400, [
        'success' => false,
        'message' => 'Invalid name length',
    ]);
}

// Restrict name to safe characters (letters, spaces, hyphens, apostrophes, periods)
if (!preg_match('/^[A-Za-z][A-Za-z .\-\']*[A-Za-z]$/u', $name)) {
    respond(400, [
        'success' => false,
        'message' => 'Name contains invalid characters',
    ]);
}

// Enforce stronger password: min 8, at least one letter and one digit
if (strlen($password) < 8 || !preg_match('/[A-Za-z]/', $password) || !preg_match('/\d/', $password)) {
    respond(400, [
        'success' => false,
        'message' => 'Password must be 8+ chars with letters and numbers',
    ]);
}

// Enforce student ID format: NN-NNNN-NNN (numbers only)
if (!preg_match('/^\d{2}-\d{4}-\d{3}$/', $studentId)) {
    respond(400, [
        'success' => false,
        'message' => 'Invalid student ID format (expected NN-NNNN-NNN)',
    ]);
}

// Validate gender
$allowedGenders = ['male','female','other','prefer_not_to_say'];
if (!in_array(strtolower($gender), $allowedGenders, true)) {
    respond(400, [
        'success' => false,
        'message' => 'Invalid gender value',
    ]);
}

// Validate birthdate
try {
    $birthdateObj = new DateTime($birthdate);
    $birthdateFormatted = $birthdateObj->format('Y-m-d');
} catch (Throwable $e) {
    respond(400, [
        'success' => false,
        'message' => 'Invalid birthdate format (expected YYYY-MM-DD)',
    ]);
}

// Check duplicates
$checkStmt = $db->prepare('SELECT id FROM users WHERE email = ? OR student_id = ? LIMIT 1');
$checkStmt->execute([$email, $studentId]);
if ($checkStmt->fetch()) {
    respond(409, [
        'success' => false,
        'message' => 'Account already exists',
    ]);
}

$passwordHash = password_hash($password, PASSWORD_BCRYPT);

$insertStmt = $db->prepare('INSERT INTO users (name, email, password_hash, student_id, year_level, department, course, gender, birthdate, role, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())');
// Force role to 'student' regardless of input
$role = 'student';

try {
    $insertStmt->execute([$name, $email, $passwordHash, $studentId, $yearLevel, $department, $course, strtolower($gender), $birthdateFormatted, $role]);
    $id = $db->lastInsertId();
} catch (Throwable $e) {
    respond(500, [
        'success' => false,
        'message' => 'Failed to register user',
    ]);
}

$createdAt = (new DateTime())->format('Y-m-d H:i:s');
$updatedAt = $createdAt;

respond(201, [
    'success' => true,
    'user' => [
        'id' => (string)$id,
        'name' => $name,
        'email' => $email,
        'studentId' => $studentId,
        'yearLevel' => $yearLevel,
        'department' => $department,
        'course' => $course,
        'gender' => strtolower($gender),
        'birthdate' => $birthdateFormatted,
        'role' => $role,
        'createdAt' => $createdAt,
        'updatedAt' => $updatedAt,
    ],
]);
?>

