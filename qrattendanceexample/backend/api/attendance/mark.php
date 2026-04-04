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

$qrCodeData = (string)($data['qrCodeData'] ?? '');
$eventId = (int)($data['eventId'] ?? 0);
$studentIdInput = $data['studentId'] ?? '';

if ($qrCodeData === '' || $eventId <= 0 || empty($studentIdInput)) {
    respond(400, ['success' => false, 'message' => 'Missing required fields']);
}

// Handle both numeric ID and string student_id
// Try numeric ID first, then fall back to student_id lookup
$studentId = null;
$studentIdInt = (int)$studentIdInput;
$isNumeric = ($studentIdInt > 0 && (string)$studentIdInt === (string)$studentIdInput);

if ($isNumeric) {
    // Try as numeric ID first
    $stmtCheckId = $db->prepare('SELECT id FROM users WHERE id = ? LIMIT 1');
    $stmtCheckId->execute([$studentIdInt]);
    $idResult = $stmtCheckId->fetch();
    if ($idResult) {
        $studentId = $studentIdInt;
    } else {
        // Not found as ID, try as student_id string (convert to string for lookup)
        $stmtLookup = $db->prepare('SELECT id FROM users WHERE student_id = ? LIMIT 1');
        $stmtLookup->execute([(string)$studentIdInput]);
        $lookupResult = $stmtLookup->fetch();
        if (!$lookupResult) {
            respond(404, ['success' => false, 'message' => 'Student not found']);
        }
        $studentId = (int)$lookupResult['id'];
    }
} else {
    // It's a string, look up by student_id
    $stmtLookup = $db->prepare('SELECT id FROM users WHERE student_id = ? LIMIT 1');
    $stmtLookup->execute([(string)$studentIdInput]);
    $lookupResult = $stmtLookup->fetch();
    if (!$lookupResult) {
        respond(404, ['success' => false, 'message' => 'Student not found']);
    }
    $studentId = (int)$lookupResult['id'];
}

// Decode QR data (base64-encoded JSON)
try {
    $decodedJson = base64_decode($qrCodeData, true);
    if ($decodedJson === false) {
        respond(400, ['success' => false, 'message' => 'Invalid QR code data']);
    }
    $qr = json_decode($decodedJson, true, 512, JSON_THROW_ON_ERROR);
} catch (Throwable $e) {
    respond(400, ['success' => false, 'message' => 'Invalid QR code payload']);
}

// Validate payload consistency for offline mode
if (!isset($qr['studentId'])) {
    respond(400, ['success' => false, 'message' => 'Incomplete QR data - missing studentId']);
}

// Convert QR studentId to numeric ID - try as ID first, then as student_id
$qrStudentIdInput = $qr['studentId'];
$qrStudentId = null;
$qrStudentIdInt = (int)$qrStudentIdInput;
$qrIsNumeric = ($qrStudentIdInt > 0 && (string)$qrStudentIdInt === (string)$qrStudentIdInput);

if ($qrIsNumeric) {
    // Try as numeric ID first
    $stmtQrCheckId = $db->prepare('SELECT id FROM users WHERE id = ? LIMIT 1');
    $stmtQrCheckId->execute([$qrStudentIdInt]);
    $qrIdResult = $stmtQrCheckId->fetch();
    if ($qrIdResult) {
        $qrStudentId = $qrStudentIdInt;
    } else {
        // Not found as ID, try as student_id string (convert to string for lookup)
        $stmtQrLookup = $db->prepare('SELECT id FROM users WHERE student_id = ? LIMIT 1');
        $stmtQrLookup->execute([(string)$qrStudentIdInput]);
        $qrLookupResult = $stmtQrLookup->fetch();
        if (!$qrLookupResult) {
            respond(400, ['success' => false, 'message' => 'Invalid student ID in QR data']);
        }
        $qrStudentId = (int)$qrLookupResult['id'];
    }
} else {
    // QR contains string student_id, look it up
    $stmtQrLookup = $db->prepare('SELECT id FROM users WHERE student_id = ? LIMIT 1');
    $stmtQrLookup->execute([(string)$qrStudentIdInput]);
    $qrLookupResult = $stmtQrLookup->fetch();
    if (!$qrLookupResult) {
        respond(400, ['success' => false, 'message' => 'Invalid student ID in QR data']);
    }
    $qrStudentId = (int)$qrLookupResult['id'];
}

// For offline mode, QR codes only contain studentId, so we don't validate eventId
// For traditional mode, validate both eventId and studentId match
if (isset($qr['eventId'])) {
    // Traditional mode - validate both eventId and studentId match
    if ((int)$qr['eventId'] !== $eventId || $qrStudentId !== $studentId) {
        respond(400, ['success' => false, 'message' => 'QR data does not match request']);
    }
} else {
    // Offline mode - only validate studentId matches
    if ($qrStudentId !== $studentId) {
        respond(400, ['success' => false, 'message' => 'QR data does not match request']);
    }
}

// Check if auto status detection is enabled
$stmtSettings = $db->prepare('SELECT setting_value FROM system_settings WHERE setting_key = ? AND is_active = 1 LIMIT 1');
$stmtSettings->execute(['auto_status_detection']);
$autoDetectionSetting = $stmtSettings->fetch();
$autoDetectionEnabled = $autoDetectionSetting && $autoDetectionSetting['setting_value'] === 'true';

// Get late grace period setting
$stmtGracePeriod = $db->prepare('SELECT setting_value FROM system_settings WHERE setting_key = ? AND is_active = 1 LIMIT 1');
$stmtGracePeriod->execute(['late_grace_period']);
$gracePeriodSetting = $stmtGracePeriod->fetch();
$gracePeriodMinutes = $gracePeriodSetting ? (int)$gracePeriodSetting['setting_value'] : 15;

// Ensure event exists and get start/end times and targeting
$stmtEvent = $db->prepare('SELECT id, start_time, end_time, target_department, target_course, target_year_level FROM events WHERE id = ? LIMIT 1');
$stmtEvent->execute([$eventId]);
$event = $stmtEvent->fetch();
if (!$event) {
    respond(404, ['success' => false, 'message' => 'Event not found']);
}

// Ensure user exists and fetch info for eligibility
$stmtUser = $db->prepare('SELECT id, name, department, course, year_level FROM users WHERE id = ? LIMIT 1');
$stmtUser->execute([$studentId]);
$user = $stmtUser->fetch();
if (!$user) {
    respond(404, ['success' => false, 'message' => 'Student not found']);
}

// Enforce event audience restriction if specified
$eventDept = isset($event['target_department']) ? trim((string)$event['target_department']) : '';
$eventCourse = isset($event['target_course']) ? trim((string)$event['target_course']) : '';
$eventYear = isset($event['target_year_level']) ? trim((string)$event['target_year_level']) : '';
if ($eventDept !== '' && strcasecmp($eventDept, (string)$user['department']) !== 0) {
    respond(403, ['success' => false, 'message' => 'This event is restricted to department: ' . $eventDept]);
}
if ($eventCourse !== '' && strcasecmp($eventCourse, (string)$user['course']) !== 0) {
    respond(403, ['success' => false, 'message' => 'This event is restricted to course: ' . $eventCourse]);
}
if ($eventYear !== '' && strcasecmp($eventYear, (string)$user['year_level']) !== 0) {
    respond(403, ['success' => false, 'message' => 'This event is restricted to year level: ' . $eventYear]);
}

$now = new DateTime();
$startTime = new DateTime($event['start_time']);
$endTime = new DateTime($event['end_time']);

// Check if attendance record already exists
$stmtCheck = $db->prepare('SELECT id, check_in_time, check_out_time FROM attendance WHERE user_id = ? AND event_id = ? LIMIT 1');
$stmtCheck->execute([$studentId, $eventId]);
$existingAttendance = $stmtCheck->fetch();

if ($existingAttendance) {
    // Attendance record exists - handle check-out
    if ($existingAttendance['check_in_time'] && !$existingAttendance['check_out_time']) {
        // Student is checked in, perform check-out
        $status = 'present';
        
        // Early departure detection only if auto status detection is enabled
        if ($autoDetectionEnabled && $now < $endTime) {
            $status = 'left_early';
        }
        
        $stmtUpdate = $db->prepare('UPDATE attendance SET check_out_time = ?, status = ? WHERE id = ?');
        $stmtUpdate->execute([$now->format('Y-m-d H:i:s'), $status, $existingAttendance['id']]);
        
        respond(200, [
            'success' => true,
            'action' => 'check_out',
            'attendance' => [
                'id' => (string)$existingAttendance['id'],
                'eventId' => (string)$eventId,
                'studentId' => (string)$studentId,
                'studentName' => $user['name'],
                'checkInTime' => $existingAttendance['check_in_time'],
                'checkOutTime' => $now->format('Y-m-d H:i:s'),
                'status' => $status,
            ],
        ]);
    } else {
        // Student already checked out
        respond(409, ['success' => false, 'message' => 'Student already checked out']);
    }
} else {
    // No attendance record - perform check-in
    $status = 'present';
    
    // Late detection only if auto status detection is enabled
    if ($autoDetectionEnabled && $now > (clone $startTime)->modify("+{$gracePeriodMinutes} minutes")) {
        $status = 'late';
    }
    
    // Insert new attendance record
    $stmtIns = $db->prepare('INSERT INTO attendance (user_id, event_id, check_in_time, status) VALUES (?, ?, ?, ?)');
    try {
        $stmtIns->execute([$studentId, $eventId, $now->format('Y-m-d H:i:s'), $status]);
        
        respond(201, [
            'success' => true,
            'action' => 'check_in',
            'attendance' => [
                'id' => (string)$db->lastInsertId(),
                'eventId' => (string)$eventId,
                'studentId' => (string)$studentId,
                'studentName' => $user['name'],
                'checkInTime' => $now->format('Y-m-d H:i:s'),
                'status' => $status,
            ],
        ]);
    } catch (Throwable $e) {
        respond(500, ['success' => false, 'message' => 'Failed to create attendance record']);
    }
}
?>

