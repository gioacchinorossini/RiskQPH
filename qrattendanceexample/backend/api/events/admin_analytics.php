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
    
    // Get query parameters
    $dateFilter = $_GET['date_filter'] ?? 'all';
    $statusFilter = $_GET['status_filter'] ?? 'all';
    $sortBy = $_GET['sort_by'] ?? 'date';
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 100;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;
    
    // Build the base query for events with attendance statistics
    $baseQuery = "
        SELECT 
            e.id,
            e.title,
            e.description,
            e.start_time,
            e.end_time,
            e.location,
            e.created_at,
            e.is_active,
            COUNT(DISTINCT a.user_id) as total_attendees,
            SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
            SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) as late_count,
            SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count,
            SUM(CASE WHEN a.status = 'left_early' THEN 1 ELSE 0 END) as left_early_count
        FROM events e
        LEFT JOIN attendance a ON e.id = a.event_id
    ";
    
    $whereConditions = [];
    $params = [];
    
    // Apply date filter
    switch ($dateFilter) {
        case 'today':
            $whereConditions[] = "DATE(e.start_time) = CURDATE()";
            break;
        case 'week':
            $whereConditions[] = "YEARWEEK(e.start_time) = YEARWEEK(CURDATE())";
            break;
        case 'month':
            $whereConditions[] = "YEAR(e.start_time) = YEAR(CURDATE()) AND MONTH(e.start_time) = MONTH(CURDATE())";
            break;
        case 'quarter':
            $whereConditions[] = "YEAR(e.start_time) = YEAR(CURDATE()) AND QUARTER(e.start_time) = QUARTER(CURDATE())";
            break;
        case 'year':
            $whereConditions[] = "YEAR(e.start_time) = YEAR(CURDATE())";
            break;
        // 'all' case - no filter applied
    }
    
    // Apply status filter
    switch ($statusFilter) {
        case 'active':
            $whereConditions[] = "e.is_active = 1 AND e.start_time <= NOW() AND e.end_time >= NOW()";
            break;
        case 'completed':
            $whereConditions[] = "e.end_time < NOW()";
            break;
        case 'upcoming':
            $whereConditions[] = "e.start_time > NOW()";
            break;
        // 'all' case - no filter applied
    }
    
    // Add WHERE clause if conditions exist
    if (!empty($whereConditions)) {
        $baseQuery .= " WHERE " . implode(" AND ", $whereConditions);
    }
    
    // Group by event
    $baseQuery .= " GROUP BY e.id";
    
    // Apply sorting
    switch ($sortBy) {
        case 'attendance':
            $baseQuery .= " ORDER BY total_attendees DESC";
            break;
        case 'title':
            $baseQuery .= " ORDER BY e.title ASC";
            break;
        case 'location':
            $baseQuery .= " ORDER BY e.location ASC";
            break;
        case 'date':
        default:
            $baseQuery .= " ORDER BY e.start_time DESC";
            break;
    }
    
    // Add limit and offset
    $baseQuery .= " LIMIT :limit OFFSET :offset";
    
    $stmt = $db->prepare($baseQuery);
    
    // Bind parameters
    $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    
    $stmt->execute();
    $events = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Process the results to calculate attendance rates and format data
    $processedEvents = [];
    foreach ($events as $event) {
        $totalAttendees = (int)$event['total_attendees'];
        $presentCount = (int)$event['present_count'];
        $lateCount = (int)$event['late_count'];
        $absentCount = (int)$event['absent_count'];
        $leftEarlyCount = (int)$event['left_early_count'];
        
        // Calculate attendance rate
        $attendanceRate = $totalAttendees > 0 ? 
            round((($presentCount + $lateCount) / $totalAttendees) * 100, 1) : 0;
        
        // Determine event status
        $now = new DateTime();
        $startTime = new DateTime($event['start_time']);
        $endTime = new DateTime($event['end_time']);
        
        if ($now < $startTime) {
            $status = 'upcoming';
        } elseif ($now >= $startTime && $now <= $endTime) {
            $status = 'active';
        } else {
            $status = 'completed';
        }
        
        $processedEvents[] = [
            'id' => (int)$event['id'],
            'title' => $event['title'],
            'description' => $event['description'],
            'start_time' => $event['start_time'],
            'end_time' => $event['end_time'],
            'location' => $event['location'],
            'created_at' => $event['created_at'],
            'is_active' => (bool)$event['is_active'],
            'status' => $status,
            'total_attendees' => $totalAttendees,
            'present_count' => $presentCount,
            'late_count' => $lateCount,
            'absent_count' => $absentCount,
            'left_early_count' => $leftEarlyCount,
            'attendance_rate' => $attendanceRate
        ];
    }
    
    // Get summary statistics
    $summaryQuery = "
        SELECT 
            COUNT(*) as total_events,
            SUM(CASE WHEN e.start_time > NOW() THEN 1 ELSE 0 END) as upcoming_events,
            SUM(CASE WHEN e.start_time <= NOW() AND e.end_time >= NOW() THEN 1 ELSE 0 END) as active_events,
            SUM(CASE WHEN e.end_time < NOW() THEN 1 ELSE 0 END) as completed_events
        FROM events e
    ";
    
    $summaryStmt = $db->query($summaryQuery);
    $summary = $summaryStmt->fetch(PDO::FETCH_ASSOC);
    
    // Get total attendance statistics
    $attendanceQuery = "
        SELECT 
            COUNT(*) as total_attendance_records,
            SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as total_present,
            SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as total_late,
            SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as total_absent,
            SUM(CASE WHEN status = 'left_early' THEN 1 ELSE 0 END) as total_left_early
        FROM attendance
    ";
    
    $attendanceStmt = $db->query($attendanceQuery);
    $attendanceStats = $attendanceStmt->fetch(PDO::FETCH_ASSOC);
    
    respond(200, [
        'success' => true,
        'events' => $processedEvents,
        'summary' => [
            'total_events' => (int)$summary['total_events'],
            'upcoming_events' => (int)$summary['upcoming_events'],
            'active_events' => (int)$summary['active_events'],
            'completed_events' => (int)$summary['completed_events']
        ],
        'attendance_stats' => [
            'total_records' => (int)$attendanceStats['total_attendance_records'],
            'total_present' => (int)$attendanceStats['total_present'],
            'total_late' => (int)$attendanceStats['total_late'],
            'total_absent' => (int)$attendanceStats['total_absent'],
            'total_left_early' => (int)$attendanceStats['total_left_early']
        ],
        'filters_applied' => [
            'date_filter' => $dateFilter,
            'status_filter' => $statusFilter,
            'sort_by' => $sortBy,
            'limit' => $limit,
            'offset' => $offset
        ],
        'total_count' => count($processedEvents)
    ]);
    
} catch (Throwable $e) {
    respond(500, ['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
}
?> 