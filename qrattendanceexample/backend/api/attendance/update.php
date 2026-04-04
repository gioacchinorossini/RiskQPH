<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../../config/database.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

try {
    $db = Database::connect();
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed: ' . $e->getMessage()]);
    exit();
}

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $requiredFields = ['id', 'status'];
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            throw new Exception("Missing required field: $field");
        }
    }
    
    $attendanceId = $input['id'];
    $newStatus = $input['status'];
    $notes = $input['notes'] ?? null;
    
    // Validate status
    $validStatuses = ['present', 'late', 'absent', 'left_early'];
    if (!in_array($newStatus, $validStatuses)) {
        throw new Exception('Invalid status value');
    }
    
    // Get current attendance record with user and event info
    $stmt = $db->prepare('
        SELECT a.*, u.name as student_name, e.title as event_title 
        FROM attendance a 
        JOIN users u ON a.user_id = u.id 
        JOIN events e ON a.event_id = e.id 
        WHERE a.id = ? 
        LIMIT 1
    ');
    $stmt->execute([$attendanceId]);
    $currentAttendance = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$currentAttendance) {
        throw new Exception('Attendance record not found');
    }
    
    // Update the attendance record
    $updateStmt = $db->prepare('
        UPDATE attendance 
        SET status = ?, notes = ? 
        WHERE id = ?
    ');
    
    $success = $updateStmt->execute([$newStatus, $notes, $attendanceId]);
    
    if (!$success) {
        throw new Exception('Failed to update attendance record');
    }
    
    // Get the updated record
    $stmt = $db->prepare('
        SELECT a.*, u.name as student_name, e.title as event_title 
        FROM attendance a 
        JOIN users u ON a.user_id = u.id 
        JOIN events e ON a.event_id = e.id 
        WHERE a.id = ? 
        LIMIT 1
    ');
    $stmt->execute([$attendanceId]);
    $updatedAttendance = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Try to log the status change (ignore if table doesn't exist yet)
    try {
        $logStmt = $db->prepare('
            INSERT INTO attendance_log (attendance_id, old_status, new_status, notes, changed_by, changed_at)
            VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ');
        $logStmt->execute([
            $attendanceId,
            $currentAttendance['status'],
            $newStatus,
            $notes,
            'mobile_admin'
        ]);
    } catch (Exception $e) {
        // Log table might not exist yet, ignore this error
    }
    
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Attendance status updated successfully',
        'attendance' => [
            'id' => $updatedAttendance['id'],
            'eventId' => $updatedAttendance['event_id'],
            'studentId' => $updatedAttendance['user_id'],
            'studentName' => $updatedAttendance['student_name'],
            'checkInTime' => $updatedAttendance['check_in_time'],
            'checkOutTime' => $updatedAttendance['check_out_time'],
            'status' => $updatedAttendance['status'],
            'notes' => $updatedAttendance['notes'],
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'error' => $e->getMessage()
    ]);
}
?> 