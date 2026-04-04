<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

require_once __DIR__ . '/../config/database.php';

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

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':
        getSettings();
        break;
    case 'POST':
    case 'PUT':
        updateSettings();
        break;
    default:
        respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

function getSettings() {
    global $db;
    
    try {
        $stmt = $db->prepare('SELECT setting_key, setting_value, setting_type, description FROM system_settings WHERE is_active = 1');
        $stmt->execute();
        $settings = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $formattedSettings = [];
        foreach ($settings as $setting) {
            $value = $setting['setting_value'];
            
            // Convert value based on type
            switch ($setting['setting_type']) {
                case 'boolean':
                    $value = $value === 'true';
                    break;
                case 'integer':
                    $value = (int)$value;
                    break;
                case 'json':
                    $value = json_decode($value, true);
                    break;
            }
            
            $formattedSettings[$setting['setting_key']] = [
                'value' => $value,
                'type' => $setting['setting_type'],
                'description' => $setting['description']
            ];
        }
        
        respond(200, [
            'success' => true,
            'settings' => $formattedSettings
        ]);
        
    } catch (Throwable $e) {
        respond(500, ['success' => false, 'message' => 'Failed to retrieve settings']);
    }
}

function updateSettings() {
    global $db;
    
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) { 
        $data = $_POST; 
    }
    
    if (!isset($data['settings']) || !is_array($data['settings'])) {
        respond(400, ['success' => false, 'message' => 'Invalid settings data']);
    }
    
    try {
        $db->beginTransaction();
        
        $updateStmt = $db->prepare('UPDATE system_settings SET setting_value = ?, updated_at = CURRENT_TIMESTAMP WHERE setting_key = ?');
        
        foreach ($data['settings'] as $key => $value) {
            // Validate setting exists
            $checkStmt = $db->prepare('SELECT id FROM system_settings WHERE setting_key = ? AND is_active = 1');
            $checkStmt->execute([$key]);
            
            if ($checkStmt->fetch()) {
                // Convert value to string for storage
                $stringValue = is_bool($value) ? ($value ? 'true' : 'false') : (string)$value;
                $updateStmt->execute([$stringValue, $key]);
            }
        }
        
        // Update last settings update timestamp
        $updateStmt->execute([date('Y-m-d H:i:s'), 'last_settings_update']);
        
        $db->commit();
        
        respond(200, [
            'success' => true,
            'message' => 'Settings updated successfully',
            'updated_at' => date('Y-m-d H:i:s')
        ]);
        
    } catch (Throwable $e) {
        $db->rollBack();
        respond(500, ['success' => false, 'message' => 'Failed to update settings']);
    }
}
?> 