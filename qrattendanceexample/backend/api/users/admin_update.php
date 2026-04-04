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

// Read input
$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

if (!is_array($data)) {
    $data = $_POST;
}

$userId = (int)($data['id'] ?? 0);
$name = trim($data['name'] ?? '');
$email = trim($data['email'] ?? '');
$studentId = trim($data['student_id'] ?? '');
$yearLevel = trim($data['year_level'] ?? '');
$department = trim($data['department'] ?? '');
$course = trim($data['course'] ?? '');
$gender = trim($data['gender'] ?? '');
$birthdate = trim($data['birthdate'] ?? '');
$role = trim($data['role'] ?? '');

if ($userId <= 0) {
    respond(400, ['success' => false, 'message' => 'Invalid user ID']);
}

if ($name === '' || $email === '' || $studentId === '') {
    respond(400, ['success' => false, 'message' => 'Name, email, and student ID are required']);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(400, ['success' => false, 'message' => 'Invalid email address']);
}

// Validate gender
$allowedGenders = ['male', 'female', 'other', 'prefer_not_to_say'];
if ($gender !== '' && !in_array(strtolower($gender), $allowedGenders, true)) {
    respond(400, ['success' => false, 'message' => 'Invalid gender value']);
}

// Validate birthdate if provided
$birthdateFormatted = null;
if ($birthdate !== '') {
    try {
        $birthdateObj = new DateTime($birthdate);
        $birthdateFormatted = $birthdateObj->format('Y-m-d');
    } catch (Throwable $e) {
        respond(400, ['success' => false, 'message' => 'Invalid birthdate format (expected YYYY-MM-DD)']);
    }
}

// Check if email or student_id already exists for other users
$checkStmt = $db->prepare('SELECT id FROM users WHERE (email = ? OR student_id = ?) AND id != ? LIMIT 1');
$checkStmt->execute([$email, $studentId, $userId]);
if ($checkStmt->fetch()) {
    respond(409, ['success' => false, 'message' => 'Email or student ID already exists']);
}

// Update user
$updateStmt = $db->prepare('UPDATE users SET name = ?, email = ?, student_id = ?, year_level = ?, department = ?, course = ?, gender = ?, birthdate = ?, role = ?, updated_at = NOW() WHERE id = ?');

try {
    $updateStmt->execute([
        $name, 
        $email, 
        $studentId, 
        $yearLevel, 
        $department, 
        $course, 
        strtolower($gender), 
        $birthdateFormatted, 
        $role, 
        $userId
    ]);
    
    respond(200, [
        'success' => true,
        'message' => 'User updated successfully',
        'user' => [
            'id' => (string)$userId,
            'name' => $name,
            'email' => $email,
            'student_id' => $studentId,
            'year_level' => $yearLevel,
            'department' => $department,
            'course' => $course,
            'gender' => strtolower($gender),
            'birthdate' => $birthdateFormatted,
            'role' => $role,
            'updated_at' => (new DateTime())->format('Y-m-d H:i:s')
        ]
    ]);
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Failed to update user']);
}
?> 