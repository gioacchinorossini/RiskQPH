# QR Attendance Admin Website

A comprehensive web-based admin dashboard for managing the QR Attendance system.

## 🎯 **Updated Structure**

The admin website has been restructured to properly integrate with your existing backend:

- **`index.html`** - Authentication check and redirect
- **`login.html`** - Admin login page
- **`dashboard.html`** - Main admin dashboard
- **`styles.css`** - Custom styling
- **`script.js`** - Dashboard functionality

## 🔧 **Backend Integration**

The admin website now correctly integrates with your existing backend APIs:

### **Database Schema Match**
- **Users table**: `id`, `name`, `email`, `student_id`, `role`, `created_at`, `updated_at`
- **Events table**: `id`, `title`, `description`, `start_time`, `end_time`, `location`, `created_by`, `created_at`, `is_active`, `qr_code`
- **Attendance table**: `id`, `user_id`, `event_id`, `check_in_time`, `check_out_time`, `status`, `notes`

### **API Endpoints**
- `GET /backend/api/events/list.php` - List all events
- `POST /backend/api/events/create.php` - Create new event (JSON format)
- `GET /backend/api/users/list.php` - List all users
- `POST /backend/api/register.php` - Register new user (JSON format)
- `GET /backend/api/attendance/list_recent.php` - Get recent attendance
- `POST /backend/api/login.php` - Admin authentication

### **Field Mappings**
- **Events**: `title`, `description`, `start_time`, `end_time`, `location`, `created_by`
- **Users**: `name`, `studentId` (backend expects), `email`, `password`, `role`
- **Attendance**: `studentId`, `eventId`, `checkInTime`, `checkOutTime`, `status`

## 🚀 **Features**

### **🏠 Dashboard**
- **Statistics Overview**: Total events, active events, users, today's attendance
- **Interactive Charts**: Attendance trends and patterns
- **Recent Activity**: Latest attendance activities

### **📅 Events Management**
- **Create Events**: Set up new attendance events
- **Event List**: View all events with status indicators
- **QR Code Management**: View generated QR codes

### **👥 User Management**
- **Add Users**: Register new students and administrators
- **User List**: Manage all registered users
- **Role-based Access**: Student and admin permissions

### **📊 Attendance Records**
- **View Records**: Comprehensive attendance data
- **Filter by Event**: Sort attendance by specific events
- **Export Data**: Download CSV reports
- **Status Tracking**: Present, late, absent, left early

### **📈 Reports & Analytics**
- **Attendance Charts**: Visual breakdown of patterns
- **Monthly Trends**: Track attendance over time
- **Report Generation**: PDF, Excel, and CSV formats

## 🔐 **Security Features**

- **Admin-only Access**: Role-based authentication
- **Session Management**: Secure localStorage tokens
- **Input Validation**: Form validation and sanitization
- **CORS Support**: Proper cross-origin configuration

## 📱 **Responsive Design**

- **Mobile-first**: Works on all device sizes
- **Modern UI**: Bootstrap 5 with custom styling
- **Smooth Animations**: Hover effects and transitions
- **Accessibility**: Screen reader friendly

## 🛠 **Setup Instructions**

1. **Database Setup**
   ```bash
   # Import your existing schema
   mysql -u root -p < ../backend/schema.sql
   ```

2. **File Placement**
   - Place the `admin/` folder in your web server directory
   - Ensure `backend/` folder is accessible

3. **Access the Admin Panel**
   - Navigate to `http://localhost/your-project/admin/`
   - Login with admin credentials
   - Redirects to dashboard automatically

## 🔍 **Usage Guide**

### **Creating an Event**
1. Navigate to Events section
2. Click "Create Event" button
3. Fill in event details (title, time, location, description)
4. Submit the form

### **Adding a User**
1. Go to Users section
2. Click "Add User" button
3. Enter user information (name, student ID, email, password, role)
4. Submit the form

### **Viewing Attendance**
1. Navigate to Attendance section
2. Use event filter to view specific event attendance
3. Export data using the export button

## 🐛 **Troubleshooting**

### **Common Issues**

1. **Database Connection Error**
   - Verify database credentials in `../backend/config/database.php`
   - Ensure MySQL service is running

2. **API Endpoints Not Found**
   - Check file paths and permissions
   - Verify backend folder structure

3. **Authentication Issues**
   - Clear browser localStorage
   - Check admin role in database
   - Verify login API response

4. **Field Mismatch Errors**
   - Ensure backend API field names match frontend
   - Check JSON format for POST requests

## 🔄 **API Data Flow**

1. **Login**: `login.html` → `login.php` → `dashboard.html`
2. **Dashboard**: Loads data from multiple APIs
3. **Create Event**: Form → JSON → `create.php`
4. **Create User**: Form → JSON → `register.php`
5. **View Data**: Fetches from respective list APIs

## 📊 **Data Formats**

### **Event Creation**
```json
{
  "title": "Event Title",
  "description": "Event Description",
  "start_time": "2024-01-01T10:00",
  "end_time": "2024-01-01T12:00",
  "location": "Event Location",
  "created_by": 1
}
```

### **User Creation**
```json
{
  "name": "User Name",
  "studentId": "STU001",
  "email": "user@example.com",
  "password": "password123",
  "role": "student"
}
```

## 🎨 **Customization**

- **Colors**: Modify CSS variables in `styles.css`
- **Layout**: Adjust Bootstrap grid classes
- **Charts**: Customize Chart.js configurations
- **Functionality**: Extend `script.js` methods

## 📈 **Performance**

- **Lazy Loading**: Data loaded on demand
- **Efficient Queries**: Optimized API calls
- **Caching**: Browser localStorage for session data
- **Responsive Images**: Optimized for different screen sizes

## 🔮 **Future Enhancements**

- **Real-time Updates**: WebSocket integration
- **Advanced Reports**: PDF generation
- **Bulk Operations**: Import/export functionality
- **Mobile App**: Progressive Web App features

---

**Version**: 2.0.0  
**Last Updated**: January 2024  
**Compatibility**: PHP 7.4+, MySQL 5.7+, Modern Browsers 