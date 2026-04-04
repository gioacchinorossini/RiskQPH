// Admin Dashboard JavaScript
console.log('🚀 Admin Dashboard JavaScript loaded');

class AdminDashboard {
    constructor() {
        console.log('🏗️ AdminDashboard constructor called');
        this.apiBaseUrl = '../backend/api';
        this.currentSection = 'dashboard';
        this.events = [];
        this.locations = [];
        this.organizers = [];
        this.users = [];
        this.attendance = [];
        this.charts = {};
        
        this.init();
    }

    async init() {
        console.log('🚀 AdminDashboard init() called');
        
        // Check authentication first
        if (!this.checkAuth()) {
            console.log('❌ Authentication failed, stopping initialization');
            return;
        }
        
        console.log('✅ Authentication passed, continuing initialization');
        this.setupEventListeners();
        this.setupModalPersistenceListeners();
        
        // Restore the last visited section
        this.restoreLastSection();
        
        this.setupCharts();
        await this.initSettings();
        await this.initQRScanner();
        await this.initRFIDScanner();
        await this.restoreModalStateIfAny();
        console.log('✅ AdminDashboard initialization completed');
    }

    checkAuth() {
        console.log('🔐 Checking authentication...');
        const adminUser = localStorage.getItem('adminUser');
        const adminToken = localStorage.getItem('adminToken');
        
        console.log('👤 Admin user:', adminUser ? 'Found' : 'Not found');
        console.log('🔑 Admin token:', adminToken ? 'Found' : 'Not found');
        
        if (!adminUser || !adminToken) {
            console.log('❌ Authentication failed - redirecting to login');
            window.location.href = 'login.html';
            return false;
        }
        
        try {
            const user = JSON.parse(adminUser);
            if (user.role !== 'admin') {
                localStorage.removeItem('adminUser');
                localStorage.removeItem('adminToken');
                window.location.href = 'login.html';
                return false;
            }
            
            // Update user display
            const userDropdown = document.getElementById('userDropdown');
            if (userDropdown) {
                userDropdown.innerHTML = `<i class="fas fa-user"></i> ${user.name}`;
            }
            
            return true;
        } catch (error) {
            localStorage.removeItem('adminUser');
            localStorage.removeItem('adminToken');
            window.location.href = 'login.html';
            return false;
        }
    }

    restoreLastSection() {
        console.log('🔄 Restoring last visited section...');
        
        // Get the last visited section from localStorage
        const lastSection = localStorage.getItem('adminCurrentSection');
        
        if (lastSection) {
            console.log('📂 Restoring section:', lastSection);
            this.showSection(lastSection);
        } else {
            console.log('📂 No saved section found, showing dashboard');
            this.showSection('dashboard');
        }
    }

    setupEventListeners() {
        // Sidebar toggle
        document.getElementById('sidebarCollapse').addEventListener('click', () => {
            document.getElementById('sidebar').classList.toggle('collapsed');
            document.getElementById('content').classList.toggle('expanded');
        });

        // Navigation
        document.querySelectorAll('[data-section]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                this.showSection(link.dataset.section);
            });
        });

        // Surveys page handlers
        document.getElementById('refreshSurveysBtn')?.addEventListener('click', () => {
            this.loadSurveysForEvent();
        });
        document.getElementById('surveysEventSelect')?.addEventListener('change', () => {
            this.loadSurveysForEvent();
        });
        document.getElementById('openCreateSurveyModalBtn')?.addEventListener('click', () => {
            this.populateCreateSurveyEventSelect();
            this.resetCreateSurveyForm();
        });
        document.getElementById('addSurveyQuestionBtn')?.addEventListener('click', () => {
            this.addSurveyQuestionRow();
        });
        document.getElementById('submitCreateSurveyBtn')?.addEventListener('click', () => {
            this.createSurvey();
        });

        // Forms
        document.getElementById('createEventForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.createEvent();
        });

        document.getElementById('createUserForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.createUser();
        });

        // Create Location form
        document.getElementById('createLocationForm')?.addEventListener('submit', (e) => {
            e.preventDefault();
            this.createLocation();
        });

        // Create Organizer form
        document.getElementById('createOrganizerForm')?.addEventListener('submit', (e) => {
            e.preventDefault();
            this.createOrganizer();
        });

        // Export buttons
        document.getElementById('exportAttendance').addEventListener('click', () => {
            this.exportAttendanceData();
        });

        // Logout functionality
        document.addEventListener('click', (e) => {
            if (e.target.closest('[data-action="logout"]')) {
                this.logout();
            }
            if (e.target.closest('[data-action="delete-location"]')) {
                const btn = e.target.closest('[data-action="delete-location"]');
                const id = btn?.getAttribute('data-id');
                if (id) {
                    this.deleteLocation(id);
                }
            }
            if (e.target.closest('[data-action="delete-organizer"]')) {
                const btn = e.target.closest('[data-action="delete-organizer"]');
                const id = btn?.getAttribute('data-id');
                if (id) {
                    this.deleteOrganizer(id);
                }
            }
        });

        // Load locations when opening create event modal
        const createEventModal = document.getElementById('createEventModal');
        if (createEventModal) {
            createEventModal.addEventListener('show.bs.modal', () => {
                this.loadLocations();
                this.loadOrganizers();
            });
        }

        // Event filter
        document.getElementById('eventFilter').addEventListener('change', (e) => {
            this.filterAttendanceByEvent(e.target.value);
        });

        // Attendance filters
        document.getElementById('attendanceStatusFilter')?.addEventListener('change', (e) => {
            this.attendanceFilters = this.attendanceFilters || {};
            this.attendanceFilters.status = e.target.value || '';
            this.applyAttendanceFilters();
        });
        document.getElementById('attendanceFromDate')?.addEventListener('change', (e) => {
            this.attendanceFilters = this.attendanceFilters || {};
            this.attendanceFilters.fromDate = e.target.value || '';
            this.applyAttendanceFilters();
        });
        document.getElementById('attendanceToDate')?.addEventListener('change', (e) => {
            this.attendanceFilters = this.attendanceFilters || {};
            this.attendanceFilters.toDate = e.target.value || '';
            this.applyAttendanceFilters();
        });
        document.getElementById('attendanceSearchInput')?.addEventListener('input', (e) => {
            this.attendanceFilters = this.attendanceFilters || {};
            this.attendanceFilters.search = (e.target.value || '').trim();
            this.applyAttendanceFilters();
        });
        document.getElementById('attendanceSortBy')?.addEventListener('change', (e) => {
            this.attendanceFilters = this.attendanceFilters || {};
            this.attendanceFilters.sort = e.target.value || 'latest';
            this.applyAttendanceFilters();
        });

        // Events analytics filters
        document.getElementById('eventDateFilter')?.addEventListener('change', () => {
            this.loadEventsAnalytics();
        });
        document.getElementById('eventStatusFilter')?.addEventListener('change', () => {
            this.loadEventsAnalytics();
        });
        document.getElementById('eventSortBy')?.addEventListener('change', () => {
            this.loadEventsAnalytics();
        });

        // Events page filters
        document.getElementById('eventsStatusFilter')?.addEventListener('change', (e) => {
            this.eventFilters = this.eventFilters || {};
            this.eventFilters.status = e.target.value || '';
            this.applyEventFilters();
        });
        document.getElementById('eventsLocationFilter')?.addEventListener('change', (e) => {
            this.eventFilters = this.eventFilters || {};
            this.eventFilters.location = e.target.value || '';
            this.applyEventFilters();
        });
        document.getElementById('eventsOrganizerFilter')?.addEventListener('change', (e) => {
            this.eventFilters = this.eventFilters || {};
            this.eventFilters.organizer = e.target.value || '';
            this.applyEventFilters();
        });
        document.getElementById('eventsSearchInput')?.addEventListener('input', (e) => {
            this.eventFilters = this.eventFilters || {};
            this.eventFilters.search = (e.target.value || '').trim();
            this.applyEventFilters();
        });
        document.getElementById('eventsFromDate')?.addEventListener('change', (e) => {
            this.eventFilters = this.eventFilters || {};
            this.eventFilters.fromDate = e.target.value || '';
            this.applyEventFilters();
        });
        document.getElementById('eventsToDate')?.addEventListener('change', (e) => {
            this.eventFilters = this.eventFilters || {};
            this.eventFilters.toDate = e.target.value || '';
            this.applyEventFilters();
        });
        document.getElementById('eventsSortBy')?.addEventListener('change', (e) => {
            this.eventFilters = this.eventFilters || {};
            this.eventFilters.sort = e.target.value || 'latest';
            this.applyEventFilters();
        });

        // Column visibility toggles (reports analytics)
        document.getElementById('togglePresentColumn')?.addEventListener('change', (e) => {
            this.setAnalyticsColumnVisibility('present', e.target.checked);
        });
        document.getElementById('toggleLateColumn')?.addEventListener('change', (e) => {
            this.setAnalyticsColumnVisibility('late', e.target.checked);
        });
        document.getElementById('toggleAbsentColumn')?.addEventListener('change', (e) => {
            this.setAnalyticsColumnVisibility('absent', e.target.checked);
        });

        // User filters
        document.getElementById('userDepartmentFilter')?.addEventListener('change', () => {
            this.filterUsers();
        });
        document.getElementById('userYearLevelFilter')?.addEventListener('change', () => {
            this.filterUsers();
        });
        document.getElementById('userCourseFilter')?.addEventListener('change', () => {
            this.filterUsers();
        });
        document.getElementById('userGenderFilter')?.addEventListener('change', () => {
            this.filterUsers();
        });
        document.getElementById('userRoleFilter')?.addEventListener('change', () => {
            this.filterUsers();
        });
        document.getElementById('userSortBy')?.addEventListener('change', () => {
            this.sortUsers();
        });

        // Export users
        document.getElementById('exportUsers')?.addEventListener('click', () => {
            this.exportUsersData();
        });

        // Report generation
        document.getElementById('generateEventReport').addEventListener('click', () => {
            this.generateEventReport();
        });

        document.getElementById('generateUserReport').addEventListener('click', () => {
            this.generateUserReport();
        });

        document.getElementById('generateAttendanceReport').addEventListener('click', () => {
            this.generateAttendanceReport();
        });
    }

    // Persist and restore which modal is open across reloads
    setupModalPersistenceListeners() {
        const staticModalTypeById = {
            'createEventModal': 'createEvent',
            'createUserModal': 'createUser',
            'createLocationModal': 'createLocation',
            'createOrganizerModal': 'createOrganizer'
        };

        // Save on any modal show
        document.addEventListener('shown.bs.modal', (e) => {
            const modalEl = e.target;
            let type = staticModalTypeById[modalEl.id] || modalEl.dataset.modalType || '';
            let payload = modalEl.dataset.modalPayload || '';
            this.saveModalState(type, payload);
        });

        // Clear on any modal hide
        document.addEventListener('hidden.bs.modal', () => {
            this.clearModalState();
        });
    }

    saveModalState(type, payload) {
        if (!type) return;
        try {
            sessionStorage.setItem('adminDashboard:lastModal', JSON.stringify({ type, payload }));
        } catch (err) {
            console.warn('Failed to save modal state', err);
        }
    }

    getModalState() {
        try {
            const raw = sessionStorage.getItem('adminDashboard:lastModal');
            if (!raw) return null;
            return JSON.parse(raw);
        } catch (_) {
            return null;
        }
    }

    clearModalState() {
        try { sessionStorage.removeItem('adminDashboard:lastModal'); } catch (_) {}
    }

    async restoreModalStateIfAny() {
        const state = this.getModalState();
        if (!state || !state.type) return;

        const { type, payload } = state;

        // Ensure required data is loaded before restoring dynamic modals
        // loadDashboard already ran in init, which loads events/users/attendance

        try {
            switch (type) {
                case 'createEvent': {
                    const el = document.getElementById('createEventModal');
                    if (el) new bootstrap.Modal(el).show();
                    break;
                }
                case 'createUser': {
                    const el = document.getElementById('createUserModal');
                    if (el) new bootstrap.Modal(el).show();
                    break;
                }
                case 'createLocation': {
                    const el = document.getElementById('createLocationModal');
                    if (el) new bootstrap.Modal(el).show();
                    break;
                }
                case 'createOrganizer': {
                    const el = document.getElementById('createOrganizerModal');
                    if (el) new bootstrap.Modal(el).show();
                    break;
                }
                case 'eventDetails':
                    if (payload) this.showEventDetails(payload);
                    break;
                case 'editEvent':
                    if (payload) this.editEvent(payload);
                    break;
                case 'editUser':
                    if (payload) this.editUser(payload);
                    break;
                case 'userHistory':
                    if (payload) this.viewUserHistory(payload);
                    break;
                case 'qrCode':
                    if (payload) this.showQRCode(payload);
                    break;
            }
        } catch (err) {
            console.warn('Failed to restore modal state', err);
        }
    }

    showSection(sectionName) {
        console.log('📂 Showing section:', sectionName);
        
        // Hide all sections
        document.querySelectorAll('.content-section').forEach(section => {
            section.classList.remove('active');
        });

        // Remove active class from all nav items
        document.querySelectorAll('.sidebar .components li').forEach(item => {
            item.classList.remove('active');
        });

        // Show selected section
        const targetSection = document.getElementById(sectionName);
        if (targetSection) {
            targetSection.classList.add('active');
            console.log('✅ Section displayed:', sectionName);
        } else {
            console.error('❌ Section not found:', sectionName);
        }

        // Add active class to selected nav item
        const activeLink = document.querySelector(`[data-section="${sectionName}"]`);
        if (activeLink) {
            activeLink.parentElement.classList.add('active');
        }

        this.currentSection = sectionName;
        
        // Save current section to localStorage for persistence
        localStorage.setItem('adminCurrentSection', sectionName);

        // Load section-specific data
        switch(sectionName) {
            case 'dashboard':
                this.loadDashboard();
                break;
            case 'events':
                this.loadEvents();
                break;
            case 'attendance':
                this.loadAttendance();
                break;
            case 'users':
                this.loadUsers();
                break;
            case 'reports':
                this.loadReports();
                break;
            case 'settings':
                console.log('⚙️ Settings section activated - reinitializing settings');
                this.initSettings();
                break;
            case 'locations':
                this.loadLocations();
                break;
            case 'organizers':
                this.loadOrganizers();
                break;
            case 'surveys':
                this.prepareSurveysPage();
                break;
        }
    }

    async loadLocations() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/locations/list.php`);
            const data = await response.json();
            if (!data.success) throw new Error(data.message || 'Failed to load locations');
            this.locations = data.locations || [];
            this.updateLocationsTable();
            this.populateEventLocationSelect();
        } catch (error) {
            console.error('Error loading locations:', error);
            this.showNotification('Error loading locations', 'error');
        }
    }

    populateEventLocationSelect() {
        const select = document.getElementById('eventLocationSelect');
        if (!select) return;
        const current = select.value;
        select.innerHTML = '<option value="">Select location</option>' +
            (this.locations || [])
                .sort((a, b) => a.name.localeCompare(b.name))
                .map(loc => `<option value="${this.escapeHtml(loc.name)}">${this.escapeHtml(loc.name)}</option>`)
                .join('');
        if (current && [...select.options].some(o => o.value === current)) {
            select.value = current;
        }
    }

    updateLocationsTable() {
        const tbody = document.getElementById('locationsTableBody');
        if (!tbody) return;
        if (!this.locations || this.locations.length === 0) {
            tbody.innerHTML = '<tr><td colspan="3" class="text-center text-muted">No locations yet</td></tr>';
            return;
        }
        tbody.innerHTML = this.locations.map(loc => `
            <tr>
                <td>${this.escapeHtml(loc.name)}</td>
                <td>${this.escapeHtml(loc.description || '')}</td>
                <td>
                    <button type="button" class="btn btn-outline-danger btn-sm" data-action="delete-location" data-id="${loc.id}">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    }

    async createLocation() {
        const form = document.getElementById('createLocationForm');
        const formData = new FormData(form);
        const payload = {
            name: formData.get('name'),
            description: formData.get('description')
        };
        if (!payload.name || String(payload.name).trim() === '') {
            this.showNotification('Location name is required', 'error');
            return;
        }
        try {
            const res = await fetch(`${this.apiBaseUrl}/locations/create.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to create location');
            this.showNotification('Location added', 'success');
            form.reset();
            bootstrap.Modal.getInstance(document.getElementById('createLocationModal'))?.hide();
            await this.loadLocations();
        } catch (err) {
            console.error('Error creating location:', err);
            this.showNotification('Error creating location: ' + err.message, 'error');
        }
    }

    async deleteLocation(id) {
        if (!confirm('Delete this location?')) return;
        try {
            const res = await fetch(`${this.apiBaseUrl}/locations/delete.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id })
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to delete location');
            this.showNotification('Location deleted', 'success');
            await this.loadLocations();
        } catch (err) {
            console.error('Error deleting location:', err);
            this.showNotification('Error deleting location: ' + err.message, 'error');
        }
    }

    async loadOrganizers() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/organizers/list.php`);
            const data = await response.json();
            if (!data.success) throw new Error(data.message || 'Failed to load organizers');
            this.organizers = (data.organizers || []).map(o => ({ id: o.id, name: o.name, description: o.description }));
            this.updateOrganizersTable();
            this.populateEventOrganizerSelect();
        } catch (error) {
            console.error('Error loading organizers:', error);
            this.showNotification('Error loading organizers', 'error');
        }
    }

    populateEventOrganizerSelect() {
        const select = document.getElementById('eventOrganizerSelect');
        if (!select) return;
        const current = select.value;
        const organizers = (this.organizers || []).slice().sort((a, b) => a.name.localeCompare(b.name));
        select.innerHTML = '<option value="">Select organizer</option>' +
            organizers.map(o => `<option value="${this.escapeHtml(o.name)}">${this.escapeHtml(o.name)}</option>`).join('');
        if (current && [...select.options].some(o => o.value === current)) {
            select.value = current;
        }
    }

    updateOrganizersTable() {
        const tbody = document.getElementById('organizersTableBody');
        if (!tbody) return;
        const list = this.organizers || [];
        if (list.length === 0) {
            tbody.innerHTML = '<tr><td colspan="3" class="text-center text-muted">No organizers yet</td></tr>';
            return;
        }
        tbody.innerHTML = list.map(o => `
            <tr>
                <td>${this.escapeHtml(o.name)}</td>
                <td>${this.escapeHtml(o.description || '')}</td>
                <td>
                    <button type="button" class="btn btn-outline-danger btn-sm" data-action="delete-organizer" data-id="${o.id}">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    }

    async createOrganizer() {
        const form = document.getElementById('createOrganizerForm');
        const formData = new FormData(form);
        const payload = {
            name: formData.get('name'),
            description: formData.get('description')
        };
        if (!payload.name || String(payload.name).trim() === '') {
            this.showNotification('Organizer name is required', 'error');
            return;
        }
        try {
            const res = await fetch(`${this.apiBaseUrl}/organizers/create.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to create organizer');
            this.showNotification('Organizer added', 'success');
            form.reset();
            bootstrap.Modal.getInstance(document.getElementById('createOrganizerModal'))?.hide();
            await this.loadOrganizers();
        } catch (err) {
            console.error('Error creating organizer:', err);
            this.showNotification('Error creating organizer: ' + err.message, 'error');
        }
    }

    async deleteOrganizer(id) {
        if (!confirm('Delete this organizer?')) return;
        try {
            const res = await fetch(`${this.apiBaseUrl}/organizers/delete.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id })
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to delete organizer');
            this.showNotification('Organizer deleted', 'success');
            await this.loadOrganizers();
        } catch (err) {
            console.error('Error deleting organizer:', err);
            this.showNotification('Error deleting organizer: ' + err.message, 'error');
        }
    }

    async loadDashboard() {
        try {
            // Load dashboard statistics
            await Promise.all([
                this.loadEvents(),
                this.loadUsers(),
                this.loadAttendance()
            ]);

            this.updateDashboardStats();
            this.updateRecentActivity();
            this.updateUpcomingEvents();
            await this.updateRecentAttendanceSummary();
            this.updateDashboardBreakdownCharts();
        } catch (error) {
            console.error('Error loading dashboard:', error);
            this.showNotification('Error loading dashboard data', 'error');
        }
    }

    async loadEvents() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/events/list.php`);
            const data = await response.json();
            
            if (data.success) {
                this.events = data.events;
                this.populateEventsFilterOptions();
                this.applyEventFilters();
                this.updateEventFilter();
                // Populate surveys event selector if present
                this.populateSurveysEventSelect();
                this.updateDashboardStats();
            } else {
                throw new Error(data.message || 'Failed to load events');
            }
        } catch (error) {
            console.error('Error loading events:', error);
            this.showNotification('Error loading events', 'error');
        }
    }

    async loadUsers() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/users/admin_list.php`);
            const data = await response.json();
            
            if (data.success) {
                this.users = data.users;
                this.updateUsersTable();
                this.updateDashboardStats();
            } else {
                throw new Error(data.message || 'Failed to load users');
            }
        } catch (error) {
            console.error('Error loading users:', error);
            this.showNotification('Error loading users', 'error');
        }
    }

    async loadAttendance() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/attendance/list_recent.php`);
            const data = await response.json();
            
            if (data.success) {
                this.attendance = data.attendances; // Backend returns 'attendances' not 'attendance'
                this.applyAttendanceFilters();
                this.updateDashboardStats();
            } else {
                throw new Error(data.message || 'Failed to load attendance');
            }
        } catch (error) {
            console.error('Error loading attendance:', error);
            this.showNotification('Error loading attendance', 'error');
        }
    }

    updateDashboardStats() {
        // Update stats cards
        const elTotalEvents = document.getElementById('totalEvents');
        if (elTotalEvents) {
            elTotalEvents.textContent = (this.events || []).length;
        }
        const elActiveEvents = document.getElementById('activeEvents');
        if (elActiveEvents) {
            const now = new Date();
            const ongoingCount = (this.events || []).filter(e => {
                const start = new Date(e.start_time || e.startTime);
                const end = new Date(e.end_time || e.endTime);
                const isActive = e.is_active === true || e.isActive === true || e.is_active === 1;
                if (isNaN(start.getTime()) || isNaN(end.getTime())) return false;
                return isActive && start <= now && end >= now;
            }).length;
            elActiveEvents.textContent = ongoingCount;
        }
        const elTotalUsers = document.getElementById('totalUsers');
        if (elTotalUsers) {
            elTotalUsers.textContent = (this.users || []).length;
        }
        
        // Calculate today's attendance
        const today = new Date().toDateString();
        const todayAttendance = (this.attendance || []).filter(a => {
            const checkInDate = new Date(a.checkInTime).toDateString();
            return checkInDate === today;
        }).length;
        const elTodayAttendance = document.getElementById('todayAttendance');
        if (elTodayAttendance) {
            elTodayAttendance.textContent = todayAttendance;
        }
    }

    updateUpcomingEvents() {
        const container = document.getElementById('upcomingEventsList');
        if (!container) return;
        const now = new Date();
        const upcoming = (this.events || [])
            .filter(e => new Date(e.start_time) > now)
            .sort((a,b) => new Date(a.start_time) - new Date(b.start_time))
            .slice(0, 5);
        if (upcoming.length === 0) {
            container.innerHTML = '<div class="text-muted text-center">No upcoming events</div>';
            return;
        }
        container.innerHTML = upcoming.map(e => {
            const restrictionBadges = [];
            if (e.target_department) {
                restrictionBadges.push(`<span class="badge badge-warning badge-sm me-1" title="Department Restricted"><i class="fas fa-building"></i> ${e.target_department}</span>`);
            }
            if (e.target_course) {
                restrictionBadges.push(`<span class="badge badge-danger badge-sm me-1" title="Course Restricted"><i class="fas fa-book"></i> ${e.target_course}</span>`);
            }
            if (e.target_year_level) {
                restrictionBadges.push(`<span class="badge badge-info badge-sm me-1" title="Year Level Restricted"><i class="fas fa-graduation-cap"></i> ${e.target_year_level}</span>`);
            }
            const restrictionHtml = restrictionBadges.length > 0 ? 
                `<div class="mt-1">${restrictionBadges.join('')}</div>` : '';
            return `
            <div class="d-flex align-items-start mb-3">
                <div class="me-3"><i class="fas fa-calendar text-primary"></i></div>
                <div>
                    <div class="fw-semibold">${e.title}</div>
                    <div class="small text-muted">${this.formatDateTime(e.start_time)} <span class="text-muted">to</span> ${this.formatDateTime(e.end_time)}</div>
                    <div class="small">${e.location || 'N/A'}</div>
                    ${restrictionHtml}
                </div>
            </div>
        `;
        }).join('');
    }

    async updateRecentAttendanceSummary() {
        const container = document.getElementById('recentAttendanceSummary');
        if (!container) return;
        try {
            const qs = 'sort_by=date&limit=5';
            const [ongoingRes, completedRes] = await Promise.all([
                fetch(`${this.apiBaseUrl}/events/admin_analytics.php?status_filter=active&${qs}`),
                fetch(`${this.apiBaseUrl}/events/admin_analytics.php?status_filter=completed&${qs}`)
            ]);
            const [ongoingData, completedData] = await Promise.all([ongoingRes.json(), completedRes.json()]);
            if (!ongoingData.success && !completedData.success) {
                throw new Error((ongoingData.message || completedData.message) || 'Failed to load analytics');
            }
            const ongoing = (ongoingData.success ? (ongoingData.events || []) : []);
            const completed = (completedData.success ? (completedData.events || []) : []);

            const renderEvent = (ev, badgeClass, badgeText) => {
                const totalUsers = (this.users || []).length;
                const attended = (ev.present_count || 0) + (ev.late_count || 0);
                const rate = totalUsers > 0 ? Math.round((attended / totalUsers) * 100) : 0;
                return `
                <div class="mb-3">
                    <div class="d-flex justify-content-between align-items-center">
                        <div class="me-2">
                            <div class="fw-semibold">${ev.title} <span class="badge ${badgeClass} ms-1">${badgeText}</span></div>
                            <div class="small text-muted">${this.formatDateTime(ev.start_time)} <span class="text-muted">to</span> ${this.formatDateTime(ev.end_time)}</div>
                        </div>
                        <div class="text-end"><span class="fw-bold">${rate}%</span> <span class="text-muted small">(${attended}/${totalUsers})</span></div>
                    </div>
                    <div class="progress" style="height: 6px;">
                        <div class="progress-bar bg-success" role="progressbar" style="width: ${rate}%" aria-valuenow="${rate}" aria-valuemin="0" aria-valuemax="100"></div>
                    </div>
                </div>`;
            };

            if (ongoing.length === 0 && completed.length === 0) {
                container.innerHTML = '<div class="text-muted text-center">No ongoing or completed events</div>';
                return;
            }

            let html = '';
            if (ongoing.length > 0) {
                html += '<div class="mb-2 fw-semibold text-success">Ongoing</div>';
                html += ongoing.map(ev => renderEvent(ev, 'bg-success', 'Ongoing')).join('');
            }
            if (completed.length > 0) {
                if (html) html += '<hr class="my-2">';
                html += '<div class="mb-2 fw-semibold text-muted">Completed</div>';
                html += completed.map(ev => renderEvent(ev, 'bg-secondary', 'Completed')).join('');
            }
            container.innerHTML = html;
        } catch (err) {
            console.error('Failed to load recent attendance summary', err);
            container.innerHTML = '<div class="text-danger text-center">Failed to load</div>';
        }
    }

    updateDashboardBreakdownCharts() {
        const deptCtx = document.getElementById('deptBreakdownChartDashboard');
        const yearCtx = document.getElementById('yearBreakdownChartDashboard');
        if (!deptCtx && !yearCtx) return;
        // Build breakdowns from recent attendance list by joining user info
        const attended = (this.attendance || []).filter(a => a.status && a.status !== 'absent');
        const departmentCounts = {};
        const yearCounts = {};
        attended.forEach(a => {
            const user = this.users.find(u => String(u.id) === String(a.studentId));
            const dept = (a.department || (user ? user.department : '')) || 'Unknown';
            const year = (a.yearLevel || (user ? user.year_level : '')) || 'Unknown';
            departmentCounts[dept] = (departmentCounts[dept] || 0) + 1;
            yearCounts[year] = (yearCounts[year] || 0) + 1;
        });
        const deptLabels = Object.keys(departmentCounts).sort();
        const deptValues = deptLabels.map(k => departmentCounts[k]);
        const deptColorMap = {
            'BED': '#e74a3b',
            'CASE': '#1cc88a',
            'CABECS': '#f6c23e',
            'COE': '#ff8c00',
            'CHAP': '#ff6ea8'
        };
        const deptColors = deptLabels.map(l => deptColorMap[l] || '#4e73df');
        const yearLabels = Object.keys(yearCounts).sort();
        const yearValues = yearLabels.map(k => yearCounts[k]);
        if (deptCtx) {
            if (this.charts.deptBreakdownDashboard) this.charts.deptBreakdownDashboard.destroy();
            this.charts.deptBreakdownDashboard = new Chart(deptCtx, {
                type: 'bar',
                data: { labels: deptLabels, datasets: [{ label: 'Attended', data: deptValues, backgroundColor: deptColors }] },
                options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
            });
        }
        if (yearCtx) {
            if (this.charts.yearBreakdownDashboard) this.charts.yearBreakdownDashboard.destroy();
            this.charts.yearBreakdownDashboard = new Chart(yearCtx, {
                type: 'bar',
                data: { labels: yearLabels, datasets: [{ label: 'Attended', data: yearValues, backgroundColor: '#1cc88a' }] },
                options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } }
            });
        }
    }

    // Simple HTML escape utility to prevent injection in dynamic options/tables
    escapeHtml(str) {
        if (str === null || str === undefined) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    updateEventsTable() {
        const tbody = document.getElementById('eventsTableBody');
        const list = (this.filteredEvents && Array.isArray(this.filteredEvents)) ? this.filteredEvents : this.events;
        if (!list || list.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">No events found</td></tr>';
            return;
        }

        tbody.innerHTML = list.map(event => {
            const status = this.computeEventStatus(event);
            const statusBadgeClass = status === 'active' || status === 'ongoing' ? 'badge-success'
                : status === 'upcoming' ? 'badge-info'
                : status === 'completed' ? 'badge-secondary'
                : (event.is_active ? 'badge-success' : 'badge-secondary');
            const statusLabel = status === 'ongoing' ? 'Ongoing' : (status ? status.charAt(0).toUpperCase() + status.slice(1) : (event.is_active ? 'Active' : 'Inactive'));
            // Build restriction badges
            const restrictionBadges = [];
            if (event.target_department) {
                restrictionBadges.push(`<span class="badge badge-warning me-1" title="Department Restricted"><i class="fas fa-building"></i> ${event.target_department}</span>`);
            }
            if (event.target_course) {
                restrictionBadges.push(`<span class="badge badge-danger me-1" title="Course Restricted"><i class="fas fa-book"></i> ${event.target_course}</span>`);
            }
            if (event.target_year_level) {
                restrictionBadges.push(`<span class="badge badge-info me-1" title="Year Level Restricted"><i class="fas fa-graduation-cap"></i> ${event.target_year_level}</span>`);
            }
            const restrictionHtml = restrictionBadges.length > 0 ? 
                `<div class="mt-1">${restrictionBadges.join('')}</div>` : '';
            return `
            <tr>
                <td>
                    <div>${event.title}</div>
                    ${restrictionHtml}
                </td>
                <td>
                    <div>${this.formatDateTime(event.start_time)}</div>
                    <small class="text-muted">to ${this.formatDateTime(event.end_time)}</small>
                </td>
                <td>${event.location || 'N/A'}</td>
                <td>
                    <span class="badge ${statusBadgeClass}">
                        ${statusLabel}
                    </span>
                </td>
                <td>
                    <div class="btn-group btn-group-sm">
                        <button class="btn btn-outline-secondary" onclick="adminDashboard.showEventDetails(${event.id})">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn btn-outline-primary" onclick="adminDashboard.editEvent(${event.id})">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-outline-danger" onclick="adminDashboard.deleteEvent(${event.id})">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
            `;
        }).join('');
    }

    computeEventStatus(event) {
        try {
            const now = new Date();
            const start = new Date(String(event.start_time).replace(' ', 'T'));
            const end = new Date(String(event.end_time).replace(' ', 'T'));
            if (now < start) return 'upcoming';
            if (now >= start && now <= end) return 'ongoing';
            return 'completed';
        } catch (_) {
            return event.is_active ? 'active' : 'inactive';
        }
    }

    updateUsersTable() {
        const tbody = document.getElementById('usersTableBody');
        if (this.users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted">No users found</td></tr>';
            return;
        }

        tbody.innerHTML = this.users.map(user => `
            <tr data-department="${user.department || ''}" data-year-level="${user.year_level || ''}" data-course="${user.course || ''}" data-gender="${user.gender || ''}" data-role="${user.role}" data-created-at="${user.created_at}">
                <td>${user.name}</td>
                <td>${user.student_id}</td>
                <td>${user.email}</td>
                <td>${user.year_level || 'N/A'}</td>
                <td>${user.department || 'N/A'}</td>
                <td>${user.course || 'N/A'}</td>
                <td>${user.gender || 'N/A'}</td>
                <td>
                    <span class="badge ${user.role === 'admin' ? 'badge-danger' : 'badge-info'}">
                        ${user.role}
                    </span>
                </td>
                <td>${this.formatDateTime(user.created_at)}</td>
                <td>${user.updated_at ? this.formatDateTime(user.updated_at) : 'Never'}</td>
                <td>
                    <div class="btn-group btn-group-sm">
                        <button class="btn btn-outline-secondary" onclick="adminDashboard.viewUserHistory(${user.id})" title="View Attendance History">
                            <i class="fas fa-history"></i>
                        </button>
                        <button class="btn btn-outline-primary" onclick="adminDashboard.editUser(${user.id})">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-outline-danger" onclick="adminDashboard.deleteUser(${user.id})">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `).join('');
    }

    updateAttendanceTable() {
        const tbody = document.getElementById('attendanceTableBody');
        const list = (this.filteredAttendance && Array.isArray(this.filteredAttendance)) ? this.filteredAttendance : this.attendance;
        if (!list || list.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">No attendance records found</td></tr>';
            return;
        }

        tbody.innerHTML = list.map(record => {
            const user = this.users.find(u => u.id === record.studentId); // Backend uses 'studentId'
            const event = this.events.find(e => e.id === record.eventId); // Backend uses 'eventId'
            
            return `
                <tr>
                    <td>${record.studentName || (user ? user.name : 'Unknown User')}</td>
                    <td>${event ? event.title : 'Unknown Event'}</td>
                    <td>${record.checkInTime ? this.formatDateTime(record.checkInTime) : 'Not checked in'}</td>
                    <td>${record.checkOutTime ? this.formatDateTime(record.checkOutTime) : 'Not checked out'}</td>
                    <td>
                        <span class="badge badge-${this.getStatusBadgeClass(record.status)}">
                            ${record.status}
                        </span>
                    </td>
                    <td>
                        <div class="btn-group btn-group-sm">
                            <button class="btn btn-outline-primary" onclick="adminDashboard.viewAttendanceDetails(${record.id})">
                                <i class="fas fa-eye"></i>
                            </button>
                            <button class="btn btn-outline-warning" onclick="adminDashboard.editAttendance(${record.id})">
                                <i class="fas fa-edit"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            `;
        }).join('');
    }

    updateEventFilter() {
        const select = document.getElementById('eventFilter');
        select.innerHTML = '<option value="">All Events</option>';
        
        this.events.forEach(event => {
            const option = document.createElement('option');
            option.value = event.id;
            option.textContent = event.title;
            select.appendChild(option);
        });
    }

    updateRecentActivity() {
        const container = document.getElementById('recentActivity');
        if (!container) {
            return;
        }
        const recentAttendance = (this.attendance || []).slice(0, 5);
        
        if (recentAttendance.length === 0) {
            container.innerHTML = '<p class="text-muted text-center">No recent activity</p>';
            return;
        }

        container.innerHTML = recentAttendance.map(record => {
            const user = this.users.find(u => u.id === record.studentId);
            const event = this.events.find(e => e.id === record.eventId);
            
            return `
                <div class="d-flex align-items-center mb-3">
                    <div class="flex-shrink-0">
                        <i class="fas fa-user-check text-success"></i>
                    </div>
                    <div class="flex-grow-1 ms-3">
                        <div class="small text-gray-900">${record.studentName || (user ? user.name : 'Unknown User')}</div>
                        <div class="small text-gray-500">Checked in to ${event ? event.title : 'Unknown Event'}</div>
                        <div class="small text-gray-400">${this.formatDateTime(record.checkInTime)}</div>
                    </div>
                </div>
            `;
        }).join('');
    }

    populateEventsFilterOptions() {
        const locations = Array.from(new Set((this.events || []).map(e => (e.location || '').trim()).filter(Boolean))).sort((a, b) => a.localeCompare(b));
        const organizers = Array.from(new Set((this.events || []).map(e => (e.organizer || '').trim()).filter(Boolean))).sort((a, b) => a.localeCompare(b));

        const locSelect = document.getElementById('eventsLocationFilter');
        if (locSelect) {
            const current = locSelect.value;
            locSelect.innerHTML = '<option value="">All Locations</option>' + locations.map(l => `<option value="${this.escapeHtml(l)}">${this.escapeHtml(l)}</option>`).join('');
            if (current && [...locSelect.options].some(o => o.value === current)) locSelect.value = current;
        }
        const orgSelect = document.getElementById('eventsOrganizerFilter');
        if (orgSelect) {
            const current = orgSelect.value;
            orgSelect.innerHTML = '<option value="">All Organizers</option>' + organizers.map(o => `<option value="${this.escapeHtml(o)}">${this.escapeHtml(o)}</option>`).join('');
            if (current && [...orgSelect.options].some(o => o.value === current)) orgSelect.value = current;
        }
    }

    populateSurveysEventSelect() {
        const select = document.getElementById('surveysEventSelect');
        if (!select) return;
        const current = select.value;
        select.innerHTML = (this.events || []).map(e => `<option value="${this.escapeHtml(e.id)}">${this.escapeHtml(e.title)}</option>`).join('');
        if (current && [...select.options].some(o => o.value === current)) select.value = current;
        if (!select.value && this.events.length > 0) select.value = this.events[0].id;
        this.loadSurveysForEvent();
    }

    populateCreateSurveyEventSelect() {
        const select = document.getElementById('createSurveyEventSelect');
        if (!select) return;
        const current = select.value;
        select.innerHTML = (this.events || []).map(e => `<option value="${this.escapeHtml(e.id)}">${this.escapeHtml(e.title)}</option>`).join('');
        if (current && [...select.options].some(o => o.value === current)) select.value = current;
        if (!select.value && this.events.length > 0) select.value = this.events[0].id;
    }

    prepareSurveysPage() {
        // Ensure events loaded then populate selectors
        if (!this.events || this.events.length === 0) {
            this.loadEvents().then(() => this.populateSurveysEventSelect());
        } else {
            this.populateSurveysEventSelect();
        }
    }

    async loadSurveysForEvent() {
        const select = document.getElementById('surveysEventSelect');
        const eventId = select ? select.value : '';
        const tbody = document.getElementById('surveysTableBody');
        if (!tbody || !eventId) return;
        tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted"><i class="fas fa-spinner fa-spin"></i> Loading...</td></tr>';
        try {
            const res = await fetch(`${this.apiBaseUrl}/surveys/list_by_event.php?event_id=${encodeURIComponent(eventId)}`);
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to load surveys');
            const list = data.surveys || [];
            if (list.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">No surveys for this event</td></tr>';
                return;
            }
            tbody.innerHTML = list.map(s => `
                <tr>
                    <td>${this.escapeHtml(s.title)}</td>
                    <td>${this.escapeHtml(s.description || '')}</td>
                    <td><span class="badge ${s.is_active ? 'badge-success' : 'badge-secondary'}">${s.is_active ? 'Active' : 'Inactive'}</span></td>
                    <td>${this.formatDateTime(s.created_at)}</td>
                    <td>
                        <div class="btn-group btn-group-sm">
                            <button class="btn btn-outline-secondary" onclick="adminDashboard.viewSurveyDetails(${s.id})"><i class="fas fa-eye"></i></button>
                            <button class="btn btn-outline-danger" onclick="adminDashboard.deleteSurvey(${s.id})"><i class="fas fa-trash"></i></button>
                        </div>
                    </td>
                </tr>
            `).join('');
        } catch (err) {
            console.error('Failed to load surveys', err);
            tbody.innerHTML = '<tr><td colspan="5" class="text-danger text-center">Failed to load</td></tr>';
        }
    }

    resetCreateSurveyForm() {
        const form = document.getElementById('createSurveyForm');
        if (!form) return;
        form.reset();
        const container = document.getElementById('surveyQuestionsContainer');
        if (container) container.innerHTML = '';
        this.addSurveyQuestionRow();
    }

    addSurveyQuestionRow() {
        const container = document.getElementById('surveyQuestionsContainer');
        if (!container) return;
        const idx = container.children.length;
        const row = document.createElement('div');
        row.className = 'card mb-2';
        row.innerHTML = `
            <div class="card-body">
                <div class="row g-2 align-items-center">
                    <div class="col-md-7">
                        <input type="text" class="form-control" placeholder="Question text" name="q_${idx}_text" required />
                    </div>
                    <div class="col-md-3">
                        <select class="form-select" name="q_${idx}_type">
                            <option value="single_choice">Single choice</option>
                            <option value="multiple_choice">Multiple choice</option>
                            <option value="text">Text</option>
                        </select>
                    </div>
                    <div class="col-md-2 text-end">
                        <button type="button" class="btn btn-outline-danger btn-sm" onclick="this.closest('.card').remove()"><i class="fas fa-trash"></i></button>
                    </div>
                </div>
                <div class="mt-2" data-options-container>
                    <div class="small text-muted">Options (for choice types)</div>
                    <div class="d-flex gap-2 mt-1">
                        <input type="text" class="form-control" placeholder="Option 1" name="q_${idx}_opt_0" />
                        <input type="text" class="form-control" placeholder="Option 2" name="q_${idx}_opt_1" />
                        <button type="button" class="btn btn-outline-secondary btn-sm" onclick="adminDashboard.addOptionField(this, '${idx}')"><i class="fas fa-plus"></i></button>
                    </div>
                </div>
            </div>`;
        container.appendChild(row);
    }

    addOptionField(btn, idx) {
        const row = btn.closest('.card');
        if (!row) return;
        const optionsContainer = row.querySelector('[data-options-container]');
        const count = optionsContainer.querySelectorAll('input[type="text"]').length;
        const input = document.createElement('input');
        input.type = 'text';
        input.className = 'form-control';
        input.placeholder = `Option ${count + 1}`;
        input.name = `q_${idx}_opt_${count}`;
        btn.parentElement.insertBefore(input, btn);
    }

    async createSurvey() {
        const form = document.getElementById('createSurveyForm');
        const fd = new FormData(form);
        const eventId = fd.get('event_id');
        const title = (fd.get('title') || '').toString().trim();
        const description = (fd.get('description') || '').toString().trim();
        if (!eventId || !title) {
            this.showNotification('Event and title are required', 'error');
            return;
        }
        // Build questions
        const container = document.getElementById('surveyQuestionsContainer');
        const cards = container.querySelectorAll('.card');
        const questions = [];
        cards.forEach((card, i) => {
            const text = card.querySelector(`input[name^="q_${i}_text"]`)?.value?.trim() || '';
            const type = card.querySelector(`select[name^="q_${i}_type"]`)?.value || 'single_choice';
            if (!text) return;
            const optionsInputs = card.querySelectorAll(`[name^="q_${i}_opt_"]`);
            const options = Array.from(optionsInputs).map(inp => inp.value.trim()).filter(Boolean);
            if (type !== 'text' && options.length < 2) {
                // need at least two options
                return;
            }
            questions.push({ text, type, ...(type !== 'text' ? { options } : {}) });
        });
        if (questions.length === 0) {
            this.showNotification('Add at least one question', 'error');
            return;
        }

        const payload = {
            event_id: String(eventId),
            title,
            description: description || undefined,
            created_by: 1,
            questions
        };

        try {
            const res = await fetch(`${this.apiBaseUrl}/surveys/create.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to create survey');
            this.showNotification('Survey created', 'success');
            bootstrap.Modal.getInstance(document.getElementById('createSurveyModal'))?.hide();
            this.loadSurveysForEvent();
        } catch (err) {
            console.error('Failed to create survey', err);
            this.showNotification('Failed to create survey: ' + err.message, 'error');
        }
    }

    async deleteSurvey(id) {
        if (!confirm('Delete this survey? This will remove all responses.')) return;
        try {
            const res = await fetch(`${this.apiBaseUrl}/surveys/delete.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id })
            });
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to delete survey');
            this.showNotification('Survey deleted', 'success');
            this.loadSurveysForEvent();
        } catch (err) {
            console.error('Failed to delete survey', err);
            this.showNotification('Failed to delete survey: ' + err.message, 'error');
        }
    }

    async viewSurveyDetails(id) {
        try {
            const res = await fetch(`${this.apiBaseUrl}/surveys/details.php?survey_id=${encodeURIComponent(id)}`);
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to load survey');
            const s = data.survey;
            // Build simple modal with questions & actions
            const modal = document.createElement('div');
            modal.className = 'modal fade';
            modal.innerHTML = `
              <div class="modal-dialog modal-lg">
                <div class="modal-content">
                  <div class="modal-header">
                    <h5 class="modal-title"><i class="fas fa-clipboard-list"></i> ${this.escapeHtml(s.title)}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                  </div>
                  <div class="modal-body">
                    <div class="mb-2 text-muted">Event #${s.event_id} • Created by ${s.created_by} • ${this.formatDateTime(s.created_at)}</div>
                    ${s.description ? `<p>${this.escapeHtml(s.description)}</p>` : ''}
                    <h6>Questions</h6>
                    ${(s.questions || []).map((q, idx) => `
                      <div class="mb-2">
                        <div class="fw-semibold">${idx+1}. ${this.escapeHtml(q.question_text)}</div>
                        <div class="small text-muted">Type: ${q.question_type}</div>
                        ${(q.options || []).length ? `<ul class="mb-0">${q.options.map(o => `<li>${this.escapeHtml(o.option_text)}</li>`).join('')}</ul>` : ''}
                      </div>
                    `).join('')}
                  </div>
                  <div class="modal-footer">
                    <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Close</button>
                    <button type="button" class="btn btn-outline-info" id="viewSurveyStatsBtn"><i class="fas fa-chart-bar"></i> Statistics</button>
                    <button type="button" class="btn btn-outline-primary" id="viewSurveyResponsesBtn"><i class="fas fa-list"></i> Responses</button>
                  </div>
                </div>
              </div>`;
            document.body.appendChild(modal);
            const m = new bootstrap.Modal(modal);
            m.show();
            modal.addEventListener('hidden.bs.modal', () => document.body.removeChild(modal));
            modal.querySelector('#viewSurveyStatsBtn')?.addEventListener('click', async () => {
              await this.showSurveyStats(id);
            });
            modal.querySelector('#viewSurveyResponsesBtn')?.addEventListener('click', async () => {
              await this.showSurveyResponses(id);
            });
        } catch (err) {
            console.error('Failed to load survey', err);
            this.showNotification('Failed to load survey: ' + err.message, 'error');
        }
    }

    async showSurveyStats(id) {
        try {
            const res = await fetch(`${this.apiBaseUrl}/surveys/stats.php?survey_id=${encodeURIComponent(id)}`);
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to load stats');
            const questions = data.questions || [];
            const modal = document.createElement('div');
            modal.className = 'modal fade';
            modal.innerHTML = `
              <div class="modal-dialog modal-lg">
                <div class="modal-content">
                  <div class="modal-header">
                    <h5 class="modal-title"><i class="fas fa-chart-bar"></i> Survey Statistics</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                  </div>
                  <div class="modal-body">
                    <div class="mb-3">Total submissions: <strong>${data.total_submissions || 0}</strong></div>
                    ${questions.map((q, idx) => `
                      <div class="mb-3">
                        <div class="fw-semibold">${idx+1}. ${this.escapeHtml(q.text)}</div>
                        ${q.type === 'text' ? `<div class="text-muted">Text answers: ${q.text_answer_count || 0}</div>` : `
                        ${(q.options || []).map(o => `
                          <div class="d-flex align-items-center gap-2 my-1">
                            <div class="flex-grow-1">
                              <div class="progress" style="height: 14px;">
                                <div class="progress-bar" role="progressbar" style="width: ${(data.total_submissions>0?Math.round((o.count||0)/data.total_submissions*100):0)}%"></div>
                              </div>
                            </div>
                            <div style="width: 160px;" class="text-end small">${this.escapeHtml(o.text)} (${o.count||0})</div>
                          </div>
                        `).join('')}
                        `}
                      </div>
                    `).join('')}
                  </div>
                </div>
              </div>`;
            document.body.appendChild(modal);
            const m = new bootstrap.Modal(modal);
            m.show();
            modal.addEventListener('hidden.bs.modal', () => document.body.removeChild(modal));
        } catch (err) {
            console.error('Failed to load stats', err);
            this.showNotification('Failed to load stats: ' + err.message, 'error');
        }
    }

    async showSurveyResponses(id) {
        try {
            const res = await fetch(`${this.apiBaseUrl}/surveys/responses.php?survey_id=${encodeURIComponent(id)}`);
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to load responses');
            const responses = data.responses || [];
            const modal = document.createElement('div');
            modal.className = 'modal fade';
            modal.innerHTML = `
              <div class="modal-dialog modal-lg">
                <div class="modal-content">
                  <div class="modal-header">
                    <h5 class="modal-title"><i class="fas fa-list"></i> Survey Responses</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                  </div>
                  <div class="modal-body">
                    ${responses.length === 0 ? '<div class="text-muted">No responses</div>' : responses.map(r => `
                      <div class="mb-3 p-2 border rounded">
                        <div class="small text-muted">User ${r.user_id} • ${r.submitted_at}</div>
                        ${(r.answers||[]).map(a => `
                          <div class="small">Q${a.question_id}: ${this.escapeHtml(a.option_text || a.answer_text || '-')}</div>
                        `).join('')}
                      </div>
                    `).join('')}
                  </div>
                </div>
              </div>`;
            document.body.appendChild(modal);
            const m = new bootstrap.Modal(modal);
            m.show();
            modal.addEventListener('hidden.bs.modal', () => document.body.removeChild(modal));
        } catch (err) {
            console.error('Failed to load responses', err);
            this.showNotification('Failed to load responses: ' + err.message, 'error');
        }
    }

    applyEventFilters() {
        const filters = this.eventFilters || {};
        const searchLower = (filters.search || '').toLowerCase();
        const fromDate = filters.fromDate ? new Date(filters.fromDate) : null;
        const toDate = filters.toDate ? new Date(filters.toDate) : null;
        const statusFilter = (filters.status || '').toLowerCase();
        const locationFilter = (filters.location || '').toLowerCase();
        const organizerFilter = (filters.organizer || '').toLowerCase();

        let list = (this.events || []).filter(ev => {
            if (statusFilter) {
                const st = this.computeEventStatus(ev);
                if (String(st).toLowerCase() !== statusFilter) return false;
            }
            if (locationFilter) {
                if (String(ev.location || '').toLowerCase() !== locationFilter) return false;
            }
            if (organizerFilter) {
                if (String(ev.organizer || '').toLowerCase() !== organizerFilter) return false;
            }
            if (searchLower) {
                const hay = `${ev.title || ''} ${ev.description || ''}`.toLowerCase();
                if (!hay.includes(searchLower)) return false;
            }
            if (fromDate) {
                const start = new Date(String(ev.start_time).replace(' ', 'T'));
                if (isNaN(start.getTime()) || start < fromDate) return false;
            }
            if (toDate) {
                const start = new Date(String(ev.start_time).replace(' ', 'T'));
                const toDateEnd = new Date(toDate);
                toDateEnd.setHours(23, 59, 59, 999);
                if (isNaN(start.getTime()) || start > toDateEnd) return false;
            }
            return true;
        });

        // Sorting
        const sort = filters.sort || 'latest';
        const compareByDate = (a, b) => new Date(String(a.start_time).replace(' ', 'T')) - new Date(String(b.start_time).replace(' ', 'T'));
        const compareByCreated = (a, b) => new Date(String(a.created_at).replace(' ', 'T')) - new Date(String(b.created_at).replace(' ', 'T'));
        const compareIgnoreCase = (get) => (a, b) => String(get(a) || '').toLowerCase().localeCompare(String(get(b) || '').toLowerCase());
        const statusRank = (ev) => {
            const st = String(this.computeEventStatus(ev)).toLowerCase();
            if (st === 'ongoing') return 0;
            if (st === 'upcoming') return 1;
            if (st === 'completed') return 2;
            return 3;
        };

        list = list.slice();
        switch (sort) {
            case 'oldest':
                list.sort((a, b) => compareByDate(a, b));
                break;
            case 'title_asc':
                list.sort(compareIgnoreCase(e => e.title));
                break;
            case 'title_desc':
                list.sort((a, b) => compareIgnoreCase(e => e.title)(b, a));
                break;
            case 'location_asc':
                list.sort(compareIgnoreCase(e => e.location));
                break;
            case 'location_desc':
                list.sort((a, b) => compareIgnoreCase(e => e.location)(b, a));
                break;
            case 'status':
                list.sort((a, b) => statusRank(a) - statusRank(b));
                break;
            case 'created_newest':
                list.sort((a, b) => compareByCreated(b, a));
                break;
            case 'created_oldest':
                list.sort((a, b) => compareByCreated(a, b));
                break;
            case 'latest':
            default:
                list.sort((a, b) => compareByDate(b, a));
                break;
        }

        this.filteredEvents = list;
        this.updateEventsTable();
    }

    clearEventFilters() {
        this.eventFilters = { status: '', location: '', organizer: '', search: '', fromDate: '', toDate: '', sort: 'latest' };
        const ids = ['eventsStatusFilter', 'eventsLocationFilter', 'eventsOrganizerFilter', 'eventsSearchInput', 'eventsFromDate', 'eventsToDate', 'eventsSortBy'];
        ids.forEach(id => {
            const el = document.getElementById(id);
            if (!el) return;
            if (el.tagName === 'SELECT') el.value = '';
            if (el.tagName === 'INPUT') el.value = '';
        });
        const sortEl = document.getElementById('eventsSortBy');
        if (sortEl) sortEl.value = 'latest';
        this.filteredEvents = null;
        this.applyEventFilters();
    }
    setupCharts() {
        // Attendance Overview Chart
        const attendanceCtx = document.getElementById('attendanceChart');
        if (attendanceCtx) {
            this.charts.attendance = new Chart(attendanceCtx, {
                type: 'line',
                data: {
                    labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                    datasets: [{
                        label: 'Attendance',
                        data: [65, 59, 80, 81, 56, 55],
                        borderColor: '#4e73df',
                        backgroundColor: 'rgba(78, 115, 223, 0.1)',
                        tension: 0.4
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true
                        }
                    }
                }
            });
        }

        // Event Attendance Chart
        const eventAttendanceCtx = document.getElementById('eventAttendanceChart');
        if (eventAttendanceCtx) {
            this.charts.eventAttendance = new Chart(eventAttendanceCtx, {
                type: 'doughnut',
                data: {
                    labels: ['Present', 'Late', 'Absent'],
                    datasets: [{
                        data: [70, 20, 10],
                        backgroundColor: ['#1cc88a', '#f6c23e', '#e74a3b']
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false
                }
            });
        }

        // Monthly Trends Chart
        const monthlyTrendsCtx = document.getElementById('monthlyTrendsChart');
        if (monthlyTrendsCtx) {
            this.charts.monthlyTrends = new Chart(monthlyTrendsCtx, {
                type: 'bar',
                data: {
                    labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                    datasets: [{
                        label: 'Events',
                        data: [12, 19, 3, 5, 2, 3],
                        backgroundColor: '#36b9cc'
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true
                        }
                    }
                }
            });
        }
    }

    async createEvent() {
        const form = document.getElementById('createEventForm');
        const formData = new FormData(form);
        
        // Convert form data to JSON format that backend expects
        const eventData = {
            title: formData.get('title'),
            description: formData.get('description'),
            start_time: formData.get('start_time'),
            end_time: formData.get('end_time'),
            location: formData.get('location'),
            organizer: formData.get('organizer') || '',
            target_department: formData.get('target_department') || '',
            target_course: formData.get('target_course') || '',
            target_year_level: formData.get('target_year_level') || '',
            created_by: 1 // Default admin user ID - you may want to get this from the logged-in user
        };
        
        try {
            const response = await fetch(`${this.apiBaseUrl}/events/create.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(eventData)
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.showNotification('Event created successfully!', 'success');
                form.reset();
                bootstrap.Modal.getInstance(document.getElementById('createEventModal')).hide();
                this.loadEvents();
            } else {
                throw new Error(data.message || 'Failed to create event');
            }
        } catch (error) {
            console.error('Error creating event:', error);
            this.showNotification('Error creating event: ' + error.message, 'error');
        }
    }

    async createUser() {
        const form = document.getElementById('createUserForm');
        const formData = new FormData(form);
        
        // Convert form data to JSON format that backend expects
        const userData = {
            name: formData.get('name'),
            studentId: formData.get('student_id'), // Backend expects 'studentId'
            email: formData.get('email'),
            password: formData.get('password'),
            role: formData.get('role')
        };
        
        try {
            const response = await fetch(`${this.apiBaseUrl}/register.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(userData)
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.showNotification('User created successfully!', 'success');
                form.reset();
                bootstrap.Modal.getInstance(document.getElementById('createUserModal')).hide();
                this.loadUsers();
            } else {
                throw new Error(data.message || 'Failed to create user');
            }
        } catch (error) {
            console.error('Error creating user:', error);
            this.showNotification('Error creating user: ' + error.message, 'error');
        }
    }

    filterAttendanceByEvent(eventId) {
        this.attendanceFilters = this.attendanceFilters || {};
        this.attendanceFilters.eventId = eventId || '';
        this.applyAttendanceFilters();
    }

    exportAttendanceData() {
        const csvContent = this.convertToCSV(this.attendance);
        const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = 'attendance_data.csv';
        link.click();
    }

    convertToCSV(data) {
        if (data.length === 0) return '';
        
        const headers = Object.keys(data[0]);
        const csvRows = [headers.join(',')];
        
        for (const row of data) {
            const values = headers.map(header => {
                const value = row[header];
                return `"${value}"`;
            });
            csvRows.push(values.join(','));
        }
        
        return csvRows.join('\n');
    }

    applyAttendanceFilters() {
        const filters = this.attendanceFilters || {};
        const status = (filters.status || '').toLowerCase();
        const eventId = filters.eventId ? String(filters.eventId) : '';
        const fromDate = filters.fromDate ? new Date(filters.fromDate) : null;
        const toDate = filters.toDate ? new Date(filters.toDate) : null;
        const searchLower = (filters.search || '').toLowerCase();

        let list = (this.attendance || []).filter(rec => {
            if (status && String(rec.status || '').toLowerCase() !== status) return false;
            if (eventId && String(rec.eventId) !== eventId) return false;
            if (fromDate) {
                const checkIn = rec.checkInTime ? new Date(rec.checkInTime) : null;
                if (!checkIn || checkIn < fromDate) return false;
            }
            if (toDate) {
                const endOfTo = new Date(toDate);
                endOfTo.setHours(23, 59, 59, 999);
                const checkIn = rec.checkInTime ? new Date(rec.checkInTime) : null;
                if (!checkIn || checkIn > endOfTo) return false;
            }
            if (searchLower) {
                const user = this.users.find(u => String(u.id) === String(rec.studentId));
                const hay = `${rec.studentName || (user ? user.name : '')}`.toLowerCase();
                if (!hay.includes(searchLower)) return false;
            }
            return true;
        });

        // Sorting
        const sort = filters.sort || 'latest';
        const getUserName = (rec) => {
            const user = this.users.find(u => String(u.id) === String(rec.studentId));
            return (rec.studentName || (user ? user.name : '') || '').toLowerCase();
        };
        const getEventTitle = (rec) => {
            const ev = this.events.find(e => String(e.id) === String(rec.eventId));
            return (ev ? ev.title : '') || '';
        };
        const statusOrder = { present: 0, late: 1, absent: 2 };
        list = list.slice();
        switch (sort) {
            case 'oldest':
                list.sort((a, b) => new Date(a.checkInTime || 0) - new Date(b.checkInTime || 0));
                break;
            case 'name_asc':
                list.sort((a, b) => getUserName(a).localeCompare(getUserName(b)));
                break;
            case 'name_desc':
                list.sort((a, b) => getUserName(b).localeCompare(getUserName(a)));
                break;
            case 'event_asc':
                list.sort((a, b) => getEventTitle(a).toLowerCase().localeCompare(getEventTitle(b).toLowerCase()));
                break;
            case 'event_desc':
                list.sort((a, b) => getEventTitle(b).toLowerCase().localeCompare(getEventTitle(a).toLowerCase()));
                break;
            case 'status':
                list.sort((a, b) => (statusOrder[String(a.status || '').toLowerCase()] ?? 99) - (statusOrder[String(b.status || '').toLowerCase()] ?? 99));
                break;
            case 'latest':
            default:
                list.sort((a, b) => new Date(b.checkInTime || 0) - new Date(a.checkInTime || 0));
                break;
        }

        this.filteredAttendance = list;
        this.updateAttendanceTable();
    }

    clearAttendanceFilters() {
        this.attendanceFilters = { status: '', eventId: '', fromDate: '', toDate: '', search: '', sort: 'latest' };
        const ids = ['attendanceStatusFilter', 'attendanceFromDate', 'attendanceToDate', 'attendanceSearchInput', 'eventFilter', 'attendanceSortBy'];
        ids.forEach(id => {
            const el = document.getElementById(id);
            if (!el) return;
            if (el.tagName === 'SELECT') el.value = '';
            if (el.tagName === 'INPUT') el.value = '';
        });
        const sortEl = document.getElementById('attendanceSortBy');
        if (sortEl) sortEl.value = 'latest';
        this.filteredAttendance = null;
        this.applyAttendanceFilters();
    }

    generateEventReport() {
        this.showNotification('Event report generation started...', 'info');
        // Implementation for PDF generation would go here
    }

    generateUserReport() {
        this.showNotification('User report generation started...', 'info');
        // Implementation for Excel generation would go here
    }

    generateAttendanceReport() {
        this.showNotification('Attendance report generation started...', 'info');
        // Implementation for CSV generation would go here
    }

    showQRCode(qrCode) {
        // Create modal to show QR code
        const modal = document.createElement('div');
        modal.className = 'modal fade';
        modal.dataset.modalType = 'qrCode';
        modal.dataset.modalPayload = String(qrCode || '');
        modal.innerHTML = `
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">QR Code</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body text-center">
                        <img src="${qrCode}" alt="QR Code" class="img-fluid" style="max-width: 300px;">
                    </div>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
        const bootstrapModal = new bootstrap.Modal(modal);
        bootstrapModal.show();
        
        modal.addEventListener('hidden.bs.modal', () => {
            document.body.removeChild(modal);
        });
    }

    async showEventDetails(eventId) {
        const event = this.events.find(e => String(e.id) === String(eventId));
        if (!event) {
            this.showNotification('Event not found', 'danger');
            return;
        }

        // Fetch attendees for the event
        let attendances = [];
        try {
            const response = await fetch(`${this.apiBaseUrl}/attendance/list_by_event.php?eventId=${encodeURIComponent(eventId)}`);
            const data = await response.json();
            if (data.success) {
                attendances = data.attendances || [];
            } else {
                throw new Error(data.message || 'Failed to load event attendees');
            }
        } catch (err) {
            console.error('Error loading event attendees:', err);
            this.showNotification('Error loading event attendees', 'danger');
            return;
        }

        // Compute breakdowns (only those who actually attended: exclude 'absent').
        // Include known fields even when count is 0.
        const attendedForBreakdown = attendances.filter(a => (a.status && a.status !== 'absent'));
        const knownDepartments = ['BED','CASE','CABECS','COE','CHAP'];
        const deptColorMap = {
            'BED': '#e74a3b',
            'CASE': '#1cc88a',
            'CABECS': '#f6c23e',
            'COE': '#ff8c00',
            'CHAP': '#ff6ea8'
        };
        const knownYearLevels = ['1st Year','2nd Year','3rd Year','4th Year'];

        const departmentToCount = {};
        const yearLevelToCount = {};
        // Seed with zeros for known fields
        knownDepartments.forEach(d => { departmentToCount[d] = 0; });
        knownYearLevels.forEach(y => { yearLevelToCount[y] = 0; });
        // Count actual attendees
        attendedForBreakdown.forEach(a => {
            const dept = a.department || 'Unknown';
            const year = a.yearLevel || 'Unknown';
            departmentToCount[dept] = (departmentToCount[dept] || 0) + 1;
            yearLevelToCount[year] = (yearLevelToCount[year] || 0) + 1;
        });
        // Build full ordered lists: known first, then any extra discovered fields
        const deptsInData = Array.from(new Set(attendances.map(a => a.department).filter(Boolean)));
        const extraDepts = deptsInData.filter(d => !knownDepartments.includes(d)).sort();
        const deptOrder = [...knownDepartments, ...extraDepts];

        const yearsInData = Array.from(new Set(attendances.map(a => a.yearLevel).filter(Boolean)));
        const extraYears = yearsInData.filter(y => !knownYearLevels.includes(y)).sort();
        const yearOrder = [...knownYearLevels, ...extraYears];

        const deptPairs = deptOrder.map(d => [d, departmentToCount[d] || 0]);
        const yearPairs = yearOrder.map(y => [y, yearLevelToCount[y] || 0]);

        const deptBreakdownHtml = deptPairs.length ? deptPairs.map(([dept,count]) => `
            <div class="d-flex justify-content-between align-items-center py-1 border-bottom">
                <span>${dept}</span>
                <span class="badge bg-primary">${count}</span>
            </div>
        `).join('') : '<div class="text-muted">No attendees yet</div>';

        const yearBreakdownHtml = yearPairs.length ? yearPairs.map(([year,count]) => `
            <div class="d-flex justify-content-between align-items-center py-1 border-bottom">
                <span>${year}</span>
                <span class="badge bg-primary">${count}</span>
            </div>
        `).join('') : '<div class="text-muted">No attendees yet</div>';

        const deptLabels = deptOrder;
        const deptValues = deptOrder.map(d => departmentToCount[d] || 0);
        const yearLabels = yearOrder;
        const yearValues = yearOrder.map(y => yearLevelToCount[y] || 0);

        // Build attendees rows with user details
        const attendeeRows = attendances.map(a => {
            const user = this.users.find(u => String(u.id) === String(a.studentId));
            const name = a.studentName || (user ? user.name : 'Unknown');
            const studentId = user ? user.student_id : a.studentId;
            const email = user ? user.email : 'N/A';
            const yearLevel = a.yearLevel || 'N/A';
            const department = a.department || 'N/A';
            const gender = a.gender || 'N/A';
            const checkIn = a.checkInTime ? this.formatDateTime(a.checkInTime) : 'Not checked in';
            const checkOut = a.checkOutTime ? this.formatDateTime(a.checkOutTime) : 'Not checked out';
            const statusBadge = `<span class="badge badge-${this.getStatusBadgeClass(a.status)}">${a.status}</span>`;
            return `
                <tr data-year-level="${yearLevel}" data-department="${department}" data-attendance-id="${a.id}">
                    <td>${name}</td>
                    <td>${studentId}</td>
                    <td>${email}</td>
                    <td>${yearLevel}</td>
                    <td>${department}</td>
                    <td>${gender}</td>
                    <td>${checkIn}</td>
                    <td>${checkOut}</td>
                    <td>${statusBadge}</td>
                    <td>
                        <button class="btn btn-danger btn-sm" onclick="adminDashboard.deleteAttendance(${a.id}, '${name}', ${eventId})" title="Delete attendance">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                </tr>
            `;
        }).join('');

        // Create modal with event details and attendees
        const modal = document.createElement('div');
        modal.className = 'modal fade';
        modal.dataset.modalType = 'eventDetails';
        modal.dataset.modalPayload = String(eventId);
        modal.innerHTML = `
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-calendar-alt"></i> ${event.title}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row mb-3">
                            <div class="col-md-8">
                                <p class="mb-1"><strong>Date & Time:</strong> ${this.formatDateTime(event.start_time)} <span class="text-muted">to</span> ${this.formatDateTime(event.end_time)}</p>
                                <p class="mb-1"><strong>Location:</strong> ${event.location || 'N/A'}</p>
                                <p class="mb-1"><strong>Description:</strong> ${event.description || 'No description'}</p>
                                <p class="mb-1 text-muted small"><strong>Created:</strong> ${this.formatDateTime(event.created_at)}${event.updated_at ? ` • <strong>Updated:</strong> ${this.formatDateTime(event.updated_at)}` : ''}</p>
                                ${event.target_department || event.target_year_level ? `
                                <p class="mb-1"><strong>Audience Restrictions:</strong> 
                                    ${event.target_department ? `<span class="badge badge-warning me-1"><i class="fas fa-building"></i> ${event.target_department}</span>` : ''}
                                    ${event.target_year_level ? `<span class="badge badge-info me-1"><i class="fas fa-graduation-cap"></i> ${event.target_year_level}</span>` : ''}
                                </p>` : ''}
                            </div>
                            <div class="col-md-4 text-end">
                                <span class="badge ${event.is_active ? 'badge-success' : 'badge-secondary'}">${event.is_active ? 'Active' : 'Inactive'}</span>
                                <div class="mt-2 text-muted">Attendees: ${attendances.length}</div>
                            </div>
                        </div>

                        <!-- Breakdown: Department and Year Level -->
                        <div class="row mb-3">
                            <div class="col-md-6">
                                <div class="card shadow-sm analytics-card">
                                    <div class="card-header py-2">
                                        <h6 class="m-0">By Department (Attended)</h6>
                                    </div>
                                    <div class="card-body p-2">
                                        ${deptBreakdownHtml}
                                        <div class="mt-3">
                                            <canvas id="deptChart-${event.id}" style="max-height:260px"></canvas>
                                        </div>
                                        <div class="mt-2 small" id="deptLegend-${event.id}"></div>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="card shadow-sm analytics-card">
                                    <div class="card-header py-2">
                                        <h6 class="m-0">By Year Level (Attended)</h6>
                                    </div>
                                    <div class="card-body p-2">
                                        ${yearBreakdownHtml}
                                        <div class="mt-3">
                                            <canvas id="yearChart-${event.id}" style="max-height:260px"></canvas>
                                        </div>
                                        <div class="mt-2 small" id="yearLegend-${event.id}"></div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Filters -->
                        <div class="row mb-3">
                            <div class="col-md-4">
                                <label class="form-label">Filter by Department:</label>
                                <select class="form-select" id="departmentFilter">
                                    <option value="">All Departments</option>
                                    ${[...new Set(attendances.map(a => a.department).filter(d => d))].map(dept => 
                                        `<option value="${dept}">${dept}</option>`
                                    ).join('')}
                                </select>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">Filter by Year Level:</label>
                                <select class="form-select" id="yearLevelFilter">
                                    <option value="">All Year Levels</option>
                                    ${[...new Set(attendances.map(a => a.yearLevel).filter(y => y))].map(year => 
                                        `<option value="${year}">${year}</option>`
                                    ).join('')}
                                </select>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">Actions:</label>
                                <div class="d-grid">
                                    <button class="btn btn-outline-secondary btn-sm" onclick="adminDashboard.clearFilters()">
                                        <i class="fas fa-times"></i> Clear Filters
                                    </button>
                                </div>
                            </div>
                        </div>

                        <div class="table-responsive">
                            <table class="table table-bordered" id="attendeesTable">
                                <thead>
                                    <tr>
                                        <th>Name</th>
                                        <th>Student ID</th>
                                        <th>Email</th>
                                        <th>Year Level</th>
                                        <th>Department</th>
                                        <th>Gender</th>
                                        <th>Check In</th>
                                        <th>Check Out</th>
                                        <th>Status</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${attendeeRows || '<tr><td colspan="10" class="text-center text-muted">No attendees yet</td></tr>'}
                                </tbody>
                            </table>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                    </div>
                </div>
            </div>`;

        document.body.appendChild(modal);
        const bootstrapModal = new bootstrap.Modal(modal);
        bootstrapModal.show();

        modal.addEventListener('hidden.bs.modal', () => {
            document.body.removeChild(modal);
        });

        // Setup filter event listeners after modal is shown
        setTimeout(() => {
            const deptFilter = document.getElementById('departmentFilter');
            const yearFilter = document.getElementById('yearLevelFilter');
            
            if (deptFilter) {
                deptFilter.addEventListener('change', () => this.filterAttendees());
            }
            if (yearFilter) {
                yearFilter.addEventListener('change', () => this.filterAttendees());
            }
        }, 100);

        // Initialize bar charts shortly after DOM insert
        setTimeout(() => {
            try {
                const deptCanvas = document.getElementById(`deptChart-${event.id}`);
                const yearCanvas = document.getElementById(`yearChart-${event.id}`);
                if (deptCanvas && window.Chart) {
                    const deptColors = deptLabels.map(l => deptColorMap[l] || '#4e73df');
                    const deptChart = new Chart(deptCanvas.getContext('2d'), {
                        type: 'bar',
                        data: {
                            labels: deptLabels,
                            datasets: [{
                                label: 'Attendees',
                                data: deptValues,
                                backgroundColor: deptColors
                            }]
                        },
                        options: {
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: { legend: { display: true } },
                            scales: { y: { beginAtZero: true, ticks: { precision: 0 } } }
                        }
                    });
                    // Build legend
                    const deptLegend = document.getElementById(`deptLegend-${event.id}`);
                    if (deptLegend) {
                        deptLegend.innerHTML = deptLabels.map((l, idx) => `
                            <span style="display:inline-flex;align-items:center;margin-right:8px;">
                                <span style="display:inline-block;width:10px;height:10px;background:${deptColors[idx]};border-radius:2px;margin-right:6px;"></span>${l}
                            </span>
                        `).join('');
                    }
                }
                if (yearCanvas && window.Chart) {
                    new Chart(yearCanvas.getContext('2d'), {
                        type: 'bar',
                        data: {
                            labels: yearLabels,
                            datasets: [{
                                label: 'Attendees',
                                data: yearValues,
                                backgroundColor: '#36b9cc'
                            }]
                        },
                        options: {
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: { legend: { display: true } },
                            scales: { y: { beginAtZero: true, ticks: { precision: 0 } } }
                        }
                    });
                    const yearLegend = document.getElementById(`yearLegend-${event.id}`);
                    if (yearLegend) {
                        yearLegend.innerHTML = yearLabels.map((l) => `
                            <span style="display:inline-flex;align-items:center;margin-right:8px;">
                                <span style="display:inline-block;width:10px;height:10px;background:#36b9cc;border-radius:2px;margin-right:6px;"></span>${l}
                            </span>
                        `).join('');
                    }
                }
            } catch (err) {
                console.error('Failed to initialize event detail charts', err);
            }
        }, 150);
    }

    filterAttendees() {
        const deptFilter = document.getElementById('departmentFilter');
        const yearFilter = document.getElementById('yearLevelFilter');
        const tbody = document.getElementById('attendeesTable');
        
        if (!deptFilter || !yearFilter || !tbody) return;
        
        const selectedDept = deptFilter.value;
        const selectedYear = yearFilter.value;
        
        const rows = tbody.querySelectorAll('tbody tr');
        let visibleCount = 0;
        
        rows.forEach(row => {
            const rowDept = row.getAttribute('data-department');
            const rowYear = row.getAttribute('data-year-level');
            
            const deptMatch = !selectedDept || rowDept === selectedDept;
            const yearMatch = !selectedYear || rowYear === selectedYear;
            
            if (deptMatch && yearMatch) {
                row.style.display = '';
                visibleCount++;
            } else {
                row.style.display = 'none';
            }
        });
        
        // Update empty message if needed
        const emptyRow = tbody.querySelector('tr[data-year-level=""]');
        if (emptyRow) {
            emptyRow.style.display = visibleCount === 0 ? '' : 'none';
        }
    }

    clearFilters() {
        const deptFilter = document.getElementById('departmentFilter');
        const yearFilter = document.getElementById('yearLevelFilter');
        
        if (deptFilter) deptFilter.value = '';
        if (yearFilter) yearFilter.value = '';
        
        this.filterAttendees();
    }

    async deleteAttendance(attendanceId, studentName, eventId) {
        // Show confirmation dialog
        const confirmed = confirm(`Are you sure you want to delete the attendance record for ${studentName}? This action cannot be undone.`);
        
        if (!confirmed) {
            return;
        }

        try {
            const response = await fetch(`${this.apiBaseUrl}/attendance/delete.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    attendanceId: attendanceId
                })
            });

            const data = await response.json();
            
            if (data.success) {
                this.showNotification(`Attendance record for ${studentName} has been deleted successfully`, 'success');
                
                // Remove the row from the table
                const row = document.querySelector(`tr[data-attendance-id="${attendanceId}"]`);
                if (row) {
                    row.remove();
                }
                
                // Update the attendee count
                const attendeeCountElement = document.querySelector('.modal-body .text-muted');
                if (attendeeCountElement && attendeeCountElement.textContent.includes('Attendees:')) {
                    const currentCount = parseInt(attendeeCountElement.textContent.match(/Attendees: (\d+)/)[1]);
                    attendeeCountElement.textContent = attendeeCountElement.textContent.replace(
                        `Attendees: ${currentCount}`, 
                        `Attendees: ${currentCount - 1}`
                    );
                }
                
                // If no attendees left, show empty message
                const tbody = document.getElementById('attendeesTable');
                if (tbody && tbody.querySelectorAll('tbody tr').length === 0) {
                    tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted">No attendees yet</td></tr>';
                }
                
            } else {
                throw new Error(data.message || 'Failed to delete attendance record');
            }
        } catch (error) {
            console.error('Error deleting attendance:', error);
            this.showNotification(`Error deleting attendance record: ${error.message}`, 'danger');
        }
    }

    filterUsers() {
        const deptFilter = document.getElementById('userDepartmentFilter');
        const yearFilter = document.getElementById('userYearLevelFilter');
        const courseFilter = document.getElementById('userCourseFilter');
        const genderFilter = document.getElementById('userGenderFilter');
        const roleFilter = document.getElementById('userRoleFilter');
        const tbody = document.getElementById('usersTable');
        
        if (!deptFilter || !yearFilter || !courseFilter || !genderFilter || !roleFilter || !tbody) return;
        
        const selectedDept = deptFilter.value;
        const selectedYear = yearFilter.value;
        const selectedCourse = courseFilter.value;
        const selectedGender = genderFilter.value;
        const selectedRole = roleFilter.value;
        
        const rows = tbody.querySelectorAll('tbody tr');
        let visibleCount = 0;
        
        rows.forEach(row => {
            const rowDept = row.getAttribute('data-department');
            const rowYear = row.getAttribute('data-year-level');
            const rowCourse = row.getAttribute('data-course');
            const rowGender = row.getAttribute('data-gender');
            const rowRole = row.getAttribute('data-role');
            
            const deptMatch = !selectedDept || rowDept === selectedDept;
            const yearMatch = !selectedYear || rowYear === selectedYear;
            const courseMatch = !selectedCourse || rowCourse === selectedCourse;
            const genderMatch = !selectedGender || rowGender === selectedGender;
            const roleMatch = !selectedRole || rowRole === selectedRole;
            
            if (deptMatch && yearMatch && courseMatch && genderMatch && roleMatch) {
                row.style.display = '';
                visibleCount++;
            } else {
                row.style.display = 'none';
            }
        });
        
        // Update empty message if needed
        const emptyRow = tbody.querySelector('tr[data-year-level=""]');
        if (emptyRow) {
            emptyRow.style.display = visibleCount === 0 ? '' : 'none';
        }

        // After filtering, ensure current sort is applied
        this.sortUsers();
    }

    clearUserFilters() {
        const deptFilter = document.getElementById('userDepartmentFilter');
        const yearFilter = document.getElementById('userYearLevelFilter');
        const courseFilter = document.getElementById('userCourseFilter');
        const genderFilter = document.getElementById('userGenderFilter');
        const roleFilter = document.getElementById('userRoleFilter');
        const sortSelect = document.getElementById('userSortBy');
        
        if (deptFilter) deptFilter.value = '';
        if (yearFilter) yearFilter.value = '';
        if (courseFilter) courseFilter.value = '';
        if (genderFilter) genderFilter.value = '';
        if (roleFilter) roleFilter.value = '';
        if (sortSelect) sortSelect.value = 'name_asc';
        
        this.filterUsers();
    }

    sortUsers() {
        const tbody = document.querySelector('#usersTable tbody');
        const sortSelect = document.getElementById('userSortBy');
        if (!tbody || !sortSelect) return;

        const rows = Array.from(tbody.querySelectorAll('tr'))
            .filter(r => r.style.display !== 'none');

        const getText = (el, selector) => (el.querySelector(selector)?.textContent || '').trim();
        const getRowDate = (el) => {
            const raw = el.getAttribute('data-created-at');
            // Backend returns 'Y-m-d H:i:s'. Interpret as local time safely.
            const isoLike = raw ? raw.replace(' ', 'T') : '';
            const d = isoLike ? new Date(isoLike) : null;
            return d && !isNaN(d) ? d : new Date(0);
        };
        const getYearLevelRank = (txt) => {
            const map = {
                '1st Year': 1,
                '2nd Year': 2,
                '3rd Year': 3,
                '4th Year': 4,
                '5th Year': 5,
                'Graduate': 6
            };
            return map[txt] ?? 999;
        };

        const mode = sortSelect.value || 'name_asc';
        const collator = new Intl.Collator(undefined, { sensitivity: 'base' });

        const compare = {
            'name_asc': (a, b) => collator.compare(getText(a, 'td:nth-child(1)'), getText(b, 'td:nth-child(1)')),
            'name_desc': (a, b) => collator.compare(getText(b, 'td:nth-child(1)'), getText(a, 'td:nth-child(1)')),
            'created_newest': (a, b) => getRowDate(b) - getRowDate(a),
            'created_oldest': (a, b) => getRowDate(a) - getRowDate(b),
            'year_asc': (a, b) => getYearLevelRank(getText(a, 'td:nth-child(4)')) - getYearLevelRank(getText(b, 'td:nth-child(4)')),
            'year_desc': (a, b) => getYearLevelRank(getText(b, 'td:nth-child(4)')) - getYearLevelRank(getText(a, 'td:nth-child(4)')),
            'dept_asc': (a, b) => collator.compare(getText(a, 'td:nth-child(5)'), getText(b, 'td:nth-child(5)')),
            'dept_desc': (a, b) => collator.compare(getText(b, 'td:nth-child(5)'), getText(a, 'td:nth-child(5)')),
            'course_asc': (a, b) => collator.compare(getText(a, 'td:nth-child(6)'), getText(b, 'td:nth-child(6)')),
            'course_desc': (a, b) => collator.compare(getText(b, 'td:nth-child(6)'), getText(a, 'td:nth-child(6)')),
            'role_asc': (a, b) => collator.compare(getText(a, 'td:nth-child(8)'), getText(b, 'td:nth-child(8)')),
            'role_desc': (a, b) => collator.compare(getText(b, 'td:nth-child(8)'), getText(a, 'td:nth-child(8)')),
        }[mode] || ((a, b) => 0);

        // Stable sort: attach index
        const decorated = rows.map((row, idx) => ({ row, idx }));
        decorated.sort((a, b) => {
            const res = compare(a.row, b.row);
            return res !== 0 ? res : a.idx - b.idx;
        });

        // Re-append in new order, keeping hidden rows in place
        decorated.forEach(d => tbody.appendChild(d.row));
    }

    exportUsersData() {
        const visibleUsers = this.getVisibleUsers();
        const csvContent = this.convertUsersToCSV(visibleUsers);
        const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = 'users_data.csv';
        link.click();
    }

    getVisibleUsers() {
        const tbody = document.getElementById('usersTable');
        if (!tbody) return [];
        
        const visibleRows = tbody.querySelectorAll('tbody tr:not([style*="display: none"])');
        const visibleUsers = [];
        
        visibleRows.forEach(row => {
            const userId = row.querySelector('button[onclick*="editUser"]')?.getAttribute('onclick')?.match(/\d+/)?.[0];
            if (userId) {
                const user = this.users.find(u => String(u.id) === String(userId));
                if (user) {
                    visibleUsers.push(user);
                }
            }
        });
        
        return visibleUsers;
    }

    convertUsersToCSV(users) {
        if (users.length === 0) return '';
        
        const headers = ['Name', 'Student ID', 'Email', 'Year Level', 'Department', 'Gender', 'Role', 'Created At', 'Updated At'];
        const csvRows = [headers.join(',')];
        
        for (const user of users) {
            const values = [
                `"${user.name}"`,
                `"${user.student_id}"`,
                `"${user.email}"`,
                `"${user.year_level || 'N/A'}"`,
                `"${user.department || 'N/A'}"`,
                `"${user.gender || 'N/A'}"`,
                `"${user.role}"`,
                `"${user.created_at}"`,
                `"${user.updated_at || 'Never'}"`
            ];
            csvRows.push(values.join(','));
        }
        
        return csvRows.join('\n');
    }

    editEvent(eventId) {
        const event = this.events.find(e => String(e.id) === String(eventId));
        if (!event) {
            this.showNotification('Event not found', 'danger');
            return;
        }

        // Build edit modal dynamically (mirrors create modal)
        const modal = document.createElement('div');
        modal.className = 'modal fade';
        modal.dataset.modalType = 'editEvent';
        modal.dataset.modalPayload = String(event.id);
        const startLocal = this.toLocalInputDateTime(event.start_time);
        const endLocal = this.toLocalInputDateTime(event.end_time);
        modal.innerHTML = `
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title"><i class="fas fa-edit"></i> Edit Event</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="editEventForm">
                            <input type="hidden" name="id" value="${event.id}">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Event Title *</label>
                                        <input type="text" class="form-control" name="title" value="${event.title}" required>
                                    </div>
                                </div>
                                                            <div class="col-md-6">
                                <div class="mb-3">
                                    <label class="form-label">Location</label>
                                    <input type="text" class="form-control" name="location" value="${event.location || ''}">
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="mb-3">
                                    <label class="form-label">Organizer</label>
                                    <input type="text" class="form-control" name="organizer" value="${event.organizer || ''}">
                                </div>
                            </div>
                            </div>
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Start Date & Time *</label>
                                        <input type="datetime-local" class="form-control" name="start_time" value="${startLocal}" required>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">End Date & Time *</label>
                                        <input type="datetime-local" class="form-control" name="end_time" value="${endLocal}" required>
                                    </div>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Restrict to Department (optional)</label>
                                        <select class="form-select" name="target_department">
                                            <option value="">All Departments</option>
                                            <option value="BED" ${String(event.target_department||'')==='BED'?'selected':''}>BED</option>
                                            <option value="CASE" ${String(event.target_department||'')==='CASE'?'selected':''}>CASE</option>
                                            <option value="CABECS" ${String(event.target_department||'')==='CABECS'?'selected':''}>CABECS</option>
                                            <option value="COE" ${String(event.target_department||'')==='COE'?'selected':''}>COE</option>
                                            <option value="CHAP" ${String(event.target_department||'')==='CHAP'?'selected':''}>CHAP</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Restrict to Year Level (optional)</label>
                                        <select class="form-select" name="target_year_level">
                                            <option value="">All Year Levels</option>
                                            <option value="1st Year" ${String(event.target_year_level||'')==='1st Year'?'selected':''}>1st Year</option>
                                            <option value="2nd Year" ${String(event.target_year_level||'')==='2nd Year'?'selected':''}>2nd Year</option>
                                            <option value="3rd Year" ${String(event.target_year_level||'')==='3rd Year'?'selected':''}>3rd Year</option>
                                            <option value="4th Year" ${String(event.target_year_level||'')==='4th Year'?'selected':''}>4th Year</option>
                                            <option value="5th Year" ${String(event.target_year_level||'')==='5th Year'?'selected':''}>5th Year</option>
                                            <option value="Graduate" ${String(event.target_year_level||'')==='Graduate'?'selected':''}>Graduate</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-12">
                                    <div class="mb-3">
                                        <label class="form-label">Restrict to Course (optional)</label>
                                        <select class="form-select" name="target_course">
                                            <option value="">All Courses</option>
                                            <option value="BSA" ${String(event.target_course||'')==='BSA'?'selected':''}>BSA - Bachelor of Science in Accountancy</option>
                                            <option value="BSAIS" ${String(event.target_course||'')==='BSAIS'?'selected':''}>BSAIS - Bachelor of Science in Accounting Information System</option>
                                            <option value="BSBA-MM" ${String(event.target_course||'')==='BSBA-MM'?'selected':''}>BSBA-MM - Bachelor of Science in Business Administration – Marketing Management</option>
                                            <option value="BSIT" ${String(event.target_course||'')==='BSIT'?'selected':''}>BSIT - Bachelor of Science in Information Technology</option>
                                            <option value="BSTMG" ${String(event.target_course||'')==='BSTMG'?'selected':''}>BSTMG - Bachelor of Science in Tourism Management</option>
                                            <option value="BSHM" ${String(event.target_course||'')==='BSHM'?'selected':''}>BSHM - Bachelor of Science in Hospitality Management</option>
                                            <option value="BSPsych" ${String(event.target_course||'')==='BSPsych'?'selected':''}>BSPsych - Bachelor of Science in Psychology</option>
                                            <option value="BEEd" ${String(event.target_course||'')==='BEEd'?'selected':''}>BEEd - Bachelor of Elementary Education (General Education)</option>
                                            <option value="BSEd" ${String(event.target_course||'')==='BSEd'?'selected':''}>BSEd - Bachelor of Secondary Education (English, Math, Filipino)</option>
                                            <option value="BCAEd" ${String(event.target_course||'')==='BCAEd'?'selected':''}>BCAEd - Bachelor of Culture and Arts Education</option>
                                            <option value="BPEd" ${String(event.target_course||'')==='BPEd'?'selected':''}>BPEd - Bachelor of Physical Education</option>
                                            <option value="TCP" ${String(event.target_course||'')==='TCP'?'selected':''}>TCP - Teacher Certificate Program</option>
                                            <option value="BSCE" ${String(event.target_course||'')==='BSCE'?'selected':''}>BSCE - Bachelor of Science in Civil Engineering</option>
                                            <option value="BSCHE" ${String(event.target_course||'')==='BSCHE'?'selected':''}>BSCHE - Bachelor of Science in Chemical Engineering</option>
                                            <option value="BSME" ${String(event.target_course||'')==='BSME'?'selected':''}>BSME - Bachelor of Science in Mechanical Engineering</option>
                                            <option value="BSN" ${String(event.target_course||'')==='BSN'?'selected':''}>BSN - Bachelor of Science in Nursing</option>
                                            <option value="BSMT" ${String(event.target_course||'')==='BSMT'?'selected':''}>BSMT - Bachelor of Science in Medical Technology</option>
                                            <option value="BSP" ${String(event.target_course||'')==='BSP'?'selected':''}>BSP - Bachelor of Science in Pharmacy</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">Description</label>
                                <textarea class="form-control" name="description" rows="3">${event.description || ''}</textarea>
                            </div>
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Status</label>
                                        <select class="form-select" name="status" id="editEventStatus">
                                            <option value="upcoming">Upcoming</option>
                                            <option value="ongoing">Ongoing</option>
                                            <option value="completed">Completed</option>
                                            <option value="active">Active (manual)</option>
                                        </select>
                                        <small class="form-text text-muted">Changing status may adjust start/end time.</small>
                                    </div>
                                </div>
                                <div class="col-md-6 d-flex align-items-center">
                                    <div class="form-check mt-4">
                                        <input class="form-check-input" type="checkbox" id="editEventActive" name="is_active" ${event.is_active ? 'checked' : ''}>
                                        <label class="form-check-label" for="editEventActive">Enabled</label>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" form="editEventForm" class="btn btn-primary">Update Event</button>
                    </div>
                </div>
            </div>`;

        document.body.appendChild(modal);
        const bootstrapModal = new bootstrap.Modal(modal);
        bootstrapModal.show();

        const form = modal.querySelector('#editEventForm');
        // Initialize status value based on current times
        const statusSelect = modal.querySelector('#editEventStatus');
        const currentStatus = this.computeEventStatus(event);
        if (statusSelect) statusSelect.value = currentStatus === 'active' ? 'ongoing' : currentStatus;

        // When status changes, adjust times relative to now (non-destructive for manual override)
        statusSelect?.addEventListener('change', () => {
            const startInput = form.querySelector('input[name="start_time"]');
            const endInput = form.querySelector('input[name="end_time"]');
            const sel = statusSelect.value;
            const now = new Date();
            const fmt = (d) => {
                const yyyy = d.getFullYear();
                const mm = String(d.getMonth() + 1).padStart(2, '0');
                const dd = String(d.getDate()).padStart(2, '0');
                const HH = String(d.getHours()).padStart(2, '0');
                const MM = String(d.getMinutes()).padStart(2, '0');
                return `${yyyy}-${mm}-${dd}T${HH}:${MM}`;
            };
            if (sel === 'upcoming') {
                const start = new Date(now.getTime() + 60 * 60 * 1000);
                const end = new Date(start.getTime() + 60 * 60 * 1000);
                startInput.value = fmt(start);
                endInput.value = fmt(end);
            } else if (sel === 'ongoing' || sel === 'active') {
                const start = new Date(now.getTime() - 15 * 60 * 1000);
                const end = new Date(now.getTime() + 60 * 60 * 1000);
                startInput.value = fmt(start);
                endInput.value = fmt(end);
            } else if (sel === 'completed') {
                const end = new Date(now.getTime() - 30 * 60 * 1000);
                const start = new Date(end.getTime() - 60 * 60 * 1000);
                startInput.value = fmt(start);
                endInput.value = fmt(end);
            }
        });
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.updateEvent(form);
            bootstrapModal.hide();
        });

        modal.addEventListener('hidden.bs.modal', () => {
            document.body.removeChild(modal);
        });
    }

    async updateEvent(form) {
        const formData = new FormData(form);
        // Convert datetime-local to ISO string acceptable by backend
        const toIso = (value) => {
            if (!value) return '';
            try {
                const d = new Date(value);
                const yyyy = d.getFullYear();
                const mm = String(d.getMonth() + 1).padStart(2, '0');
                const dd = String(d.getDate()).padStart(2, '0');
                const HH = String(d.getHours()).padStart(2, '0');
                const MM = String(d.getMinutes()).padStart(2, '0');
                const SS = String(d.getSeconds()).padStart(2, '0');
                return `${yyyy}-${mm}-${dd} ${HH}:${MM}:${SS}`;
            } catch (_) { return ''; }
        };

        const payload = {
            id: formData.get('id'),
            title: formData.get('title'),
            description: formData.get('description') || '',
            start_time: toIso(formData.get('start_time')),
            end_time: toIso(formData.get('end_time')),
            location: formData.get('location') || '',
            organizer: formData.get('organizer') || '',
            target_department: formData.get('target_department') || '',
            target_course: formData.get('target_course') || '',
            target_year_level: formData.get('target_year_level') || '',
            is_active: formData.get('is_active') ? true : false,
        };

        try {
            const response = await fetch(`${this.apiBaseUrl}/events/update.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            const data = await response.json();
            if (data.success) {
                this.showNotification('Event updated successfully!', 'success');
                await this.loadEvents();
            } else {
                throw new Error(data.message || 'Failed to update event');
            }
        } catch (error) {
            console.error('Error updating event:', error);
            this.showNotification('Error updating event: ' + error.message, 'error');
        }
    }

    toLocalInputDateTime(serverDateTime) {
        // serverDateTime like 'YYYY-MM-DD HH:MM:SS' -> 'YYYY-MM-DDTHH:MM'
        if (!serverDateTime) return '';
        try {
            const d = new Date(serverDateTime.replace(' ', 'T'));
            const yyyy = d.getFullYear();
            const mm = String(d.getMonth() + 1).padStart(2, '0');
            const dd = String(d.getDate()).padStart(2, '0');
            const HH = String(d.getHours()).padStart(2, '0');
            const MM = String(d.getMinutes()).padStart(2, '0');
            return `${yyyy}-${mm}-${dd}T${HH}:${MM}`;
        } catch (_) {
            return '';
        }
    }

    deleteEvent(eventId) {
        if (!confirm('Are you sure you want to delete this event?')) return;
        (async () => {
            try {
                const response = await fetch(`${this.apiBaseUrl}/events/delete.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ id: eventId })
                });
                const data = await response.json();
                if (data.success) {
                    this.showNotification('Event deleted successfully!', 'success');
                    await this.loadEvents();
                } else {
                    throw new Error(data.message || 'Failed to delete event');
                }
            } catch (error) {
                console.error('Error deleting event:', error);
                this.showNotification('Error deleting event: ' + error.message, 'error');
            }
        })();
    }

    editUser(userId) {
        const user = this.users.find(u => String(u.id) === String(userId));
        if (!user) {
            this.showNotification('User not found', 'danger');
            return;
        }

        // Create edit user modal
        const modal = document.createElement('div');
        modal.className = 'modal fade';
        modal.dataset.modalType = 'editUser';
        modal.dataset.modalPayload = String(user.id);
        modal.innerHTML = `
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-user-edit"></i> Edit User: ${user.name}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="editUserForm">
                            <input type="hidden" name="id" value="${user.id}">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Full Name *</label>
                                        <input type="text" class="form-control" name="name" value="${user.name}" required>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Student ID *</label>
                                        <input type="text" class="form-control" name="student_id" value="${user.student_id}" required>
                                    </div>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Email *</label>
                                        <input type="email" class="form-control" name="email" value="${user.email}" required>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="mb-3">
                                        <label class="form-label">Role</label>
                                        <select class="form-select" name="role">
                                            <option value="student" ${user.role === 'student' ? 'selected' : ''}>Student</option>
                                            <option value="officer" ${user.role === 'officer' ? 'selected' : ''}>Officer</option>
                                            <option value="admin" ${user.role === 'admin' ? 'selected' : ''}>Administrator</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            <div class="row">
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Year Level</label>
                                        <select class="form-select" name="year_level">
                                            <option value="">Select Year Level</option>
                                            <option value="1st Year" ${user.year_level === '1st Year' ? 'selected' : ''}>1st Year</option>
                                            <option value="2nd Year" ${user.year_level === '2nd Year' ? 'selected' : ''}>2nd Year</option>
                                            <option value="3rd Year" ${user.year_level === '3rd Year' ? 'selected' : ''}>3rd Year</option>
                                            <option value="4th Year" ${user.year_level === '4th Year' ? 'selected' : ''}>4th Year</option>
                                            <option value="5th Year" ${user.year_level === '5th Year' ? 'selected' : ''}>5th Year</option>
                                            <option value="Graduate" ${user.year_level === 'Graduate' ? 'selected' : ''}>Graduate</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Department</label>
                                        <select class="form-select" name="department">
                                            <option value="">Select Department</option>
                                            <option value="BED" ${user.department === 'BED' ? 'selected' : ''}>BED</option>
                                            <option value="CASE" ${user.department === 'CASE' ? 'selected' : ''}>CASE</option>
                                            <option value="CABECS" ${user.department === 'CABECS' ? 'selected' : ''}>CABECS</option>
                                            <option value="COE" ${user.department === 'COE' ? 'selected' : ''}>COE</option>
                                            <option value="CHAP" ${user.department === 'CHAP' ? 'selected' : ''}>CHAP</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Course</label>
                                        <select class="form-select" name="course">
                                            <option value="">Select Course</option>
                                            <option value="BSA" ${user.course === 'BSA' ? 'selected' : ''}>BSA - Bachelor of Science in Accountancy</option>
                                            <option value="BSAIS" ${user.course === 'BSAIS' ? 'selected' : ''}>BSAIS - Bachelor of Science in Accounting Information System</option>
                                            <option value="BSBA-MM" ${user.course === 'BSBA-MM' ? 'selected' : ''}>BSBA-MM - Bachelor of Science in Business Administration – Marketing Management</option>
                                            <option value="BSIT" ${user.course === 'BSIT' ? 'selected' : ''}>BSIT - Bachelor of Science in Information Technology</option>
                                            <option value="BSTMG" ${user.course === 'BSTMG' ? 'selected' : ''}>BSTMG - Bachelor of Science in Tourism Management</option>
                                            <option value="BSHM" ${user.course === 'BSHM' ? 'selected' : ''}>BSHM - Bachelor of Science in Hospitality Management</option>
                                            <option value="BSPsych" ${user.course === 'BSPsych' ? 'selected' : ''}>BSPsych - Bachelor of Science in Psychology</option>
                                            <option value="BEEd" ${user.course === 'BEEd' ? 'selected' : ''}>BEEd - Bachelor of Elementary Education (General Education)</option>
                                            <option value="BSEd" ${user.course === 'BSEd' ? 'selected' : ''}>BSEd - Bachelor of Secondary Education (English, Math, Filipino)</option>
                                            <option value="BCAEd" ${user.course === 'BCAEd' ? 'selected' : ''}>BCAEd - Bachelor of Culture and Arts Education</option>
                                            <option value="BPEd" ${user.course === 'BPEd' ? 'selected' : ''}>BPEd - Bachelor of Physical Education</option>
                                            <option value="TCP" ${user.course === 'TCP' ? 'selected' : ''}>TCP - Teacher Certificate Program</option>
                                            <option value="BSCE" ${user.course === 'BSCE' ? 'selected' : ''}>BSCE - Bachelor of Science in Civil Engineering</option>
                                            <option value="BSCHE" ${user.course === 'BSCHE' ? 'selected' : ''}>BSCHE - Bachelor of Science in Chemical Engineering</option>
                                            <option value="BSME" ${user.course === 'BSME' ? 'selected' : ''}>BSME - Bachelor of Science in Mechanical Engineering</option>
                                            <option value="BSN" ${user.course === 'BSN' ? 'selected' : ''}>BSN - Bachelor of Science in Nursing</option>
                                            <option value="BSMT" ${user.course === 'BSMT' ? 'selected' : ''}>BSMT - Bachelor of Science in Medical Technology</option>
                                            <option value="BSP" ${user.course === 'BSP' ? 'selected' : ''}>BSP - Bachelor of Science in Pharmacy</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-md-4">
                                    <div class="mb-3">
                                        <label class="form-label">Gender</label>
                                        <select class="form-select" name="gender">
                                            <option value="">Select Gender</option>
                                            <option value="male" ${user.gender === 'male' ? 'selected' : ''}>Male</option>
                                            <option value="female" ${user.gender === 'female' ? 'selected' : ''}>Female</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">Birthdate</label>
                                <input type="date" class="form-control" name="birthdate" value="${user.birthdate || ''}">
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" form="editUserForm" class="btn btn-primary">Update User</button>
                    </div>
                </div>
            </div>`;

        document.body.appendChild(modal);
        const bootstrapModal = new bootstrap.Modal(modal);
        bootstrapModal.show();

        // Setup form submission
        const form = modal.querySelector('#editUserForm');
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.updateUser(form);
            bootstrapModal.hide();
        });

        modal.addEventListener('hidden.bs.modal', () => {
            document.body.removeChild(modal);
        });
    }

    async updateUser(form) {
        const formData = new FormData(form);
        const userData = {
            id: formData.get('id'),
            name: formData.get('name'),
            email: formData.get('email'),
            student_id: formData.get('student_id'),
            year_level: formData.get('year_level'),
            department: formData.get('department'),
            course: formData.get('course'),
            gender: formData.get('gender'),
            birthdate: formData.get('birthdate'),
            role: formData.get('role')
        };

        try {
            const response = await fetch(`${this.apiBaseUrl}/users/admin_update.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(userData)
            });

            const data = await response.json();

            if (data.success) {
                this.showNotification('User updated successfully!', 'success');
                // Refresh users list
                await this.loadUsers();
            } else {
                throw new Error(data.message || 'Failed to update user');
            }
        } catch (error) {
            console.error('Error updating user:', error);
            this.showNotification('Error updating user: ' + error.message, 'error');
        }
    }

    deleteUser(userId) {
        if (confirm('Are you sure you want to delete this user?')) {
            this.showNotification('Delete user functionality coming soon...', 'info');
        }
    }

    async viewUserHistory(userId) {
        const user = this.users.find(u => String(u.id) === String(userId));
        if (!user) {
            this.showNotification('User not found', 'danger');
            return;
        }

        // Fetch attendance history for the user
        let attendances = [];
        try {
            const url = `${this.apiBaseUrl}/attendance/list_by_user.php?userId=${encodeURIComponent(userId)}`;
            const res = await fetch(url);
            const data = await res.json();
            if (!data.success) throw new Error(data.message || 'Failed to load history');
            attendances = data.attendances || [];
        } catch (err) {
            console.error('Failed to load user history', err);
            this.showNotification('Error loading attendance history', 'danger');
            return;
        }

        // Build rows
        const rowsHtml = attendances.length ? attendances.map(a => {
            const eventTitle = a.eventTitle || (this.events.find(e => String(e.id) === String(a.eventId))?.title || 'Unknown Event');
            const dateRange = a.eventStartTime && a.eventEndTime
                ? `${this.formatDateTime(a.eventStartTime)} to ${this.formatDateTime(a.eventEndTime)}`
                : (a.checkInTime ? this.formatDateTime(a.checkInTime) : 'N/A');
            const checkIn = a.checkInTime ? this.formatDateTime(a.checkInTime) : '—';
            const checkOut = a.checkOutTime ? this.formatDateTime(a.checkOutTime) : '—';
            const statusBadge = `<span class="badge badge-${this.getStatusBadgeClass(a.status)}">${a.status}</span>`;
            return `
                <tr>
                    <td>${eventTitle}</td>
                    <td>${dateRange}</td>
                    <td>${checkIn}</td>
                    <td>${checkOut}</td>
                    <td>${statusBadge}</td>
                    <td>${a.location || 'N/A'}</td>
                </tr>
            `;
        }).join('') : '<tr><td colspan="6" class="text-center text-muted">No attendance records</td></tr>';

        // Modal HTML
        const modal = document.createElement('div');
        modal.className = 'modal fade';
        modal.dataset.modalType = 'userHistory';
        modal.dataset.modalPayload = String(user.id);
        modal.innerHTML = `
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title"><i class="fas fa-history"></i> Attendance History — ${user.name}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row mb-3">
                            <div class="col-md-8">
                                <div><strong>Student ID:</strong> ${user.student_id}</div>
                                <div class="small text-muted">${user.email}</div>
                            </div>
                            <div class="col-md-4 text-md-end">
                                <div><strong>Department:</strong> ${user.department || 'N/A'}</div>
                                <div><strong>Year Level:</strong> ${user.year_level || 'N/A'}</div>
                            </div>
                        </div>
                        <div class="table-responsive">
                            <table class="table table-bordered">
                                <thead>
                                    <tr>
                                        <th>Event</th>
                                        <th>Event Date</th>
                                        <th>Check In</th>
                                        <th>Check Out</th>
                                        <th>Status</th>
                                        <th>Location</th>
                                    </tr>
                                </thead>
                                <tbody>${rowsHtml}</tbody>
                            </table>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-outline-success btn-sm" id="exportUserHistory">
                            <i class="fas fa-download"></i> Export CSV
                        </button>
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                    </div>
                </div>
            </div>`;

        document.body.appendChild(modal);
        const bsModal = new bootstrap.Modal(modal);
        bsModal.show();

        // Export handler
        modal.querySelector('#exportUserHistory')?.addEventListener('click', () => {
            try {
                const mapped = attendances.map(a => ({
                    eventTitle: a.eventTitle || (this.events.find(e => String(e.id) === String(a.eventId))?.title || ''),
                    eventStartTime: a.eventStartTime || '',
                    eventEndTime: a.eventEndTime || '',
                    checkInTime: a.checkInTime || '',
                    checkOutTime: a.checkOutTime || '',
                    status: a.status || '',
                    location: a.location || ''
                }));
                const csv = this.convertToCSV(mapped);
                const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
                const link = document.createElement('a');
                link.href = URL.createObjectURL(blob);
                const dateStr = new Date().toISOString().split('T')[0];
                link.download = `attendance_history_${user.student_id || user.id}_${dateStr}.csv`;
                link.click();
            } catch (e) {
                console.error('Export failed', e);
                this.showNotification('Failed to export CSV', 'danger');
            }
        });

        modal.addEventListener('hidden.bs.modal', () => {
            document.body.removeChild(modal);
        });
    }

    viewAttendanceDetails(attendanceId) {
        this.showNotification('View attendance details functionality coming soon...', 'info');
    }

    editAttendance(attendanceId) {
        this.showNotification('Edit attendance functionality coming soon...', 'info');
    }

    getStatusBadgeClass(status) {
        switch(status) {
            case 'present': return 'success';
            case 'late': return 'warning';
            case 'absent': return 'danger';
            case 'left_early': return 'info';
            default: return 'secondary';
        }
    }

    formatDateTime(dateTimeString) {
        if (!dateTimeString) return 'N/A';
        
        const date = new Date(dateTimeString);
        return date.toLocaleString();
    }

    showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
        notification.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
        notification.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        document.body.appendChild(notification);
        
        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (notification.parentNode) {
                notification.remove();
            }
        }, 5000);
    }

    loadReports() {
        // Update charts with real data
        if (this.charts.eventAttendance) {
            const presentCount = this.attendance.filter(a => a.status === 'present').length;
            const lateCount = this.attendance.filter(a => a.status === 'late').length;
            const absentCount = this.attendance.filter(a => a.status === 'absent').length;
            
            this.charts.eventAttendance.data.datasets[0].data = [presentCount, lateCount, absentCount];
            this.charts.eventAttendance.update();
        }
        
        // Load events analytics
        this.loadEventsAnalytics();

        // Apply saved column visibility
        this.applySavedAnalyticsColumnVisibility();
    }

    async loadEventsAnalytics() {
        try {
            const dateFilter = document.getElementById('eventDateFilter')?.value || 'all';
            const statusFilter = document.getElementById('eventStatusFilter')?.value || 'all';
            const sortBy = document.getElementById('eventSortBy')?.value || 'date';
            
            const url = `${this.apiBaseUrl}/events/admin_analytics.php?date_filter=${encodeURIComponent(dateFilter)}&status_filter=${encodeURIComponent(statusFilter)}&sort_by=${encodeURIComponent(sortBy)}`;
            console.log('🔍 Loading events analytics from:', url);
            
            const response = await fetch(url);
            console.log('📡 Response status:', response.status);
            console.log('📡 Response headers:', response.headers);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            console.log('📋 Response data:', data);
            
            if (data.success) {
                console.log('✅ Events analytics loaded successfully, events count:', data.events?.length || 0);
                this.updateEventsAnalyticsTable(data.events);
                this.updateEventsAnalyticsCharts(data);
            } else {
                throw new Error(data.message || 'Failed to load events analytics');
            }
        } catch (error) {
            console.error('❌ Error loading events analytics:', error);
            this.showNotification('Error loading events analytics: ' + error.message, 'error');
        }
    }

    updateEventsAnalyticsTable(events) {
        console.log('🎯 Updating events analytics table with events:', events);
        
        const tbody = document.getElementById('eventsAnalyticsTableBody');
        if (!tbody) {
            console.error('❌ Events analytics table body not found');
            return;
        }
        
        if (!events || events.length === 0) {
            console.log('📭 No events to display');
            tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted">No events found with the selected filters</td></tr>';
            return;
        }

        tbody.innerHTML = events.map(event => {
            // Build restriction badges
            const restrictionBadges = [];
            if (event.target_department) {
                restrictionBadges.push(`<span class="badge badge-warning badge-sm me-1" title="Department Restricted"><i class="fas fa-building"></i> ${event.target_department}</span>`);
            }
            if (event.target_course) {
                restrictionBadges.push(`<span class="badge badge-danger badge-sm me-1" title="Course Restricted"><i class="fas fa-book"></i> ${event.target_course}</span>`);
            }
            if (event.target_year_level) {
                restrictionBadges.push(`<span class="badge badge-info badge-sm me-1" title="Year Level Restricted"><i class="fas fa-graduation-cap"></i> ${event.target_year_level}</span>`);
            }
            const restrictionHtml = restrictionBadges.length > 0 ? 
                `<div class="mt-1">${restrictionBadges.join('')}</div>` : '';
            return `
            <tr>
                <td>
                    <strong>${event.title}</strong>
                    ${event.description ? `<br><small class="text-muted">${event.description}</small>` : ''}
                    ${restrictionHtml}
                </td>
                <td>
                    <div>${this.formatDateTime(event.start_time)}</div>
                    <small class="text-muted">to ${this.formatDateTime(event.end_time)}</small>
                </td>
                <td>${event.location || 'N/A'}</td>
                <td>
                    <span class="badge ${this.getEventStatusBadgeClass(event.status)}">
                        ${event.status.charAt(0).toUpperCase() + event.status.slice(1)}
                    </span>
                </td>
                <td>
                    <span class="badge bg-primary">${event.total_attendees}</span>
                </td>
                <td class="col-present">
                    <span class="badge bg-success">${event.present_count}</span>
                </td>
                <td class="col-late">
                    <span class="badge bg-warning">${event.late_count}</span>
                </td>
                <td class="col-absent">
                    <span class="badge bg-danger">${event.absent_count}</span>
                </td>
                <td>
                    <div class="progress" style="height: 20px;">
                        <div class="progress-bar ${this.getAttendanceRateColor(event.attendance_rate)}" 
                             role="progressbar" 
                             style="width: ${event.attendance_rate}%"
                             aria-valuenow="${event.attendance_rate}" 
                             aria-valuemin="0" 
                             aria-valuemax="100">
                            ${event.attendance_rate}%
                        </div>
                    </div>
                </td>
                <td>
                    <div class="btn-group btn-group-sm">
                        <button class="btn btn-outline-secondary" onclick="adminDashboard.showEventDetails(${event.id})">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn btn-outline-primary" onclick="adminDashboard.editEvent(${event.id})">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-outline-info" onclick="adminDashboard.exportEventReport(${event.id})">
                            <i class="fas fa-download"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
        }).join('');

        // Apply column visibility after table render
        this.applySavedAnalyticsColumnVisibility();
    }

    setAnalyticsColumnVisibility(columnKey, isVisible) {
        try {
            const table = document.getElementById('eventsAnalyticsTable');
            if (!table) return;

            const classMap = {
                present: 'col-present',
                late: 'col-late',
                absent: 'col-absent'
            };
            const cls = classMap[columnKey];
            if (!cls) return;

            // Toggle header cells
            table.querySelectorAll(`thead .${cls}`).forEach(th => {
                th.style.display = isVisible ? '' : 'none';
            });
            // Toggle body cells
            table.querySelectorAll(`tbody .${cls}`).forEach(td => {
                td.style.display = isVisible ? '' : 'none';
            });

            // Persist preference
            const prefs = this.getAnalyticsColumnPrefs();
            prefs[columnKey] = !!isVisible;
            localStorage.setItem('analyticsColumnPrefs', JSON.stringify(prefs));
        } catch (err) {
            console.error('Failed to toggle column visibility', err);
        }
    }

    getAnalyticsColumnPrefs() {
        try {
            const raw = localStorage.getItem('analyticsColumnPrefs');
            const parsed = raw ? JSON.parse(raw) : null;
            return parsed || { present: true, late: true, absent: true };
        } catch (e) {
            return { present: true, late: true, absent: true };
        }
    }

    applySavedAnalyticsColumnVisibility() {
        const prefs = this.getAnalyticsColumnPrefs();
        // Sync checkboxes if present
        const presentCb = document.getElementById('togglePresentColumn');
        const lateCb = document.getElementById('toggleLateColumn');
        const absentCb = document.getElementById('toggleAbsentColumn');
        if (presentCb) presentCb.checked = !!prefs.present;
        if (lateCb) lateCb.checked = !!prefs.late;
        if (absentCb) absentCb.checked = !!prefs.absent;

        this.setAnalyticsColumnVisibility('present', !!prefs.present);
        this.setAnalyticsColumnVisibility('late', !!prefs.late);
        this.setAnalyticsColumnVisibility('absent', !!prefs.absent);
    }

    updateEventsAnalyticsCharts(data) {
        // Update charts with real analytics data
        if (this.charts.eventAttendance && data.events.length > 0) {
            const totalPresent = data.attendance_stats.total_present;
            const totalLate = data.attendance_stats.total_late;
            const totalAbsent = data.attendance_stats.total_absent;
            
            this.charts.eventAttendance.data.datasets[0].data = [totalPresent, totalLate, totalAbsent];
            this.charts.eventAttendance.update();
        }

        // Update monthly trends chart with event data
        if (this.charts.monthlyTrends) {
            const monthlyEventCounts = this.calculateMonthlyEventCounts(data.events);
            this.charts.monthlyTrends.data.datasets[0].data = monthlyEventCounts;
            this.charts.monthlyTrends.update();
        }

        // Update summary statistics
        this.updateEventsAnalyticsSummary(data);
    }

    updateEventsAnalyticsSummary(data) {
        // Update summary cards
        const totalEvents = document.getElementById('totalEventsAnalytics');
        const activeEvents = document.getElementById('activeEventsAnalytics');
        const totalAttendees = document.getElementById('totalAttendeesAnalytics');
        const avgAttendanceRate = document.getElementById('avgAttendanceRateAnalytics');

        if (totalEvents) totalEvents.textContent = data.summary.total_events;
        if (activeEvents) activeEvents.textContent = data.summary.active_events;
        if (totalAttendees) totalAttendees.textContent = data.attendance_stats.total_records;

        // Calculate average attendance rate
        if (avgAttendanceRate && data.events.length > 0) {
            const totalRate = data.events.reduce((sum, event) => sum + event.attendance_rate, 0);
            const averageRate = Math.round(totalRate / data.events.length);
            avgAttendanceRate.textContent = averageRate + '%';
        }
    }

    calculateMonthlyEventCounts(events) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const currentYear = new Date().getFullYear();
        const monthlyCounts = new Array(12).fill(0);
        
        events.forEach(event => {
            const eventDate = new Date(event.start_time);
            if (eventDate.getFullYear() === currentYear) {
                monthlyCounts[eventDate.getMonth()]++;
            }
        });
        
        return monthlyCounts;
    }

    getEventStatusBadgeClass(status) {
        switch(status) {
            case 'active': return 'bg-success';
            case 'completed': return 'bg-secondary';
            case 'upcoming': return 'bg-info';
            default: return 'bg-secondary';
        }
    }

    getAttendanceRateColor(rate) {
        if (rate >= 80) return 'bg-success';
        if (rate >= 60) return 'bg-warning';
        return 'bg-danger';
    }

    clearEventFilters() {
        const dateFilter = document.getElementById('eventDateFilter');
        const statusFilter = document.getElementById('eventStatusFilter');
        const sortBy = document.getElementById('eventSortBy');
        
        if (dateFilter) dateFilter.value = 'all';
        if (statusFilter) statusFilter.value = 'all';
        if (sortBy) sortBy.value = 'date';
        
        this.loadEventsAnalytics();
    }

    exportEventReport(eventId) {
        this.showNotification('Event report export functionality coming soon...', 'info');
        // Implementation for exporting individual event reports would go here
    }

    exportEventsAnalytics() {
        try {
            const table = document.getElementById('eventsAnalyticsTable');
            if (!table) {
                this.showNotification('Events analytics table not found', 'error');
                return;
            }

            const rows = table.querySelectorAll('tbody tr');
            if (rows.length === 0) {
                this.showNotification('No data to export', 'warning');
                return;
            }

            // Get current filter values
            const dateFilter = document.getElementById('eventDateFilter')?.value || 'all';
            const statusFilter = document.getElementById('eventStatusFilter')?.value || 'all';
            const sortBy = document.getElementById('eventSortBy')?.value || 'date';

            // Column visibility prefs
            const prefs = this.getAnalyticsColumnPrefs();

            // Create CSV content
            const headers = [
                'Event Title', 'Description', 'Start Time', 'End Time', 'Location', 'Status',
                'Total Attendees'
            ];
            if (prefs.present) headers.push('Present');
            if (prefs.late) headers.push('Late');
            if (prefs.absent) headers.push('Absent');
            headers.push('Left Early');
            headers.push('Attendance Rate (%)');

            const csvRows = [headers.join(',')];

            rows.forEach(row => {
                const titleCell = row.querySelector('td:nth-child(1)');
                const dateCell = row.querySelector('td:nth-child(2)');
                const locationCell = row.querySelector('td:nth-child(3)');
                const statusCell = row.querySelector('td:nth-child(4)');
                const totalCell = row.querySelector('td:nth-child(5)');
                const presentCell = row.querySelector('td.col-present');
                const lateCell = row.querySelector('td.col-late');
                const absentCell = row.querySelector('td.col-absent');
                const rateBar = row.querySelector('.progress-bar');

                const rowData = [
                    this.cleanCSVValue((titleCell?.childNodes[0]?.textContent || titleCell?.textContent || '').trim()),
                    this.cleanCSVValue(titleCell?.querySelector('small')?.textContent || ''),
                    this.cleanCSVValue((dateCell?.childNodes[0]?.textContent || dateCell?.textContent || '').trim()),
                    this.cleanCSVValue(dateCell?.querySelector('small')?.textContent?.replace(/^to\s*/i, '') || ''),
                    this.cleanCSVValue(locationCell?.textContent?.trim() || ''),
                    this.cleanCSVValue(statusCell?.textContent?.trim() || ''),
                    this.cleanCSVValue(totalCell?.textContent?.trim() || '')
                ];
                if (prefs.present) rowData.push(this.cleanCSVValue(presentCell?.textContent?.trim() || ''));
                if (prefs.late) rowData.push(this.cleanCSVValue(lateCell?.textContent?.trim() || ''));
                if (prefs.absent) rowData.push(this.cleanCSVValue(absentCell?.textContent?.trim() || ''));
                rowData.push('0'); // Left early not displayed in table yet
                rowData.push(this.cleanCSVValue(rateBar?.textContent?.trim()?.replace('%','') || ''));

                csvRows.push(rowData.join(','));
            });

            const csvContent = csvRows.join('\n');
            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            const link = document.createElement('a');
            link.href = URL.createObjectURL(blob);
            
            // Create filename with current date and filters
            const now = new Date();
            const dateStr = now.toISOString().split('T')[0];
            const filename = `events_analytics_${dateStr}_${dateFilter}_${statusFilter}.csv`;
            link.download = filename;
            
            link.click();
            this.showNotification('Events analytics data exported successfully!', 'success');
        } catch (error) {
            console.error('Error exporting events analytics:', error);
            this.showNotification('Error exporting data: ' + error.message, 'error');
        }
    }

    cleanCSVValue(value) {
        if (!value) return '';
        // Remove HTML tags and clean the value for CSV
        const cleanValue = value.replace(/<[^>]*>/g, '').trim();
        // Escape quotes and wrap in quotes if contains comma or newline
        if (cleanValue.includes(',') || cleanValue.includes('\n') || cleanValue.includes('"')) {
            return '"' + cleanValue.replace(/"/g, '""') + '"';
        }
        return cleanValue;
    }

    logout() {
        if (confirm('Are you sure you want to logout?')) {
            localStorage.removeItem('adminUser');
            localStorage.removeItem('adminToken');
            window.location.href = 'login.html';
        }
    }

    // Settings Management
    async initSettings() {
        console.log('🔧 Initializing settings...');
        
        // Check if settings section exists
        const settingsSection = document.getElementById('settings');
        if (settingsSection) {
            console.log('✅ Settings section found in DOM');
        } else {
            console.error('❌ Settings section NOT found in DOM');
            return;
        }
        
        await this.loadSettings();
        this.setupSettingsEventListeners();
        this.updateSettingsUI();
        console.log('✅ Settings initialized successfully');
    }

    setupSettingsEventListeners() {
        console.log('🔗 Setting up settings event listeners...');
        
        // Auto status toggle
        const autoStatusToggle = document.getElementById('autoStatusToggle');
        if (autoStatusToggle) {
            console.log('✅ Auto status toggle found and configured');
            autoStatusToggle.addEventListener('change', (e) => {
                console.log('🔄 Auto status toggle changed:', e.target.checked);
                this.toggleAutoStatus(e.target.checked);
                this.enableSaveButton(); // Enable save button when toggle changes
            });
        } else {
            console.warn('⚠️ Auto status toggle not found');
        }

        // Save settings button
        const saveSettings = document.getElementById('saveSettings');
        if (saveSettings) {
            console.log('✅ Save settings button found and configured');
            saveSettings.addEventListener('click', () => {
                console.log('💾 Save settings button clicked');
                this.saveSettings();
            });
        } else {
            console.warn('⚠️ Save settings button not found');
        }

        // Reset settings button
        const resetSettings = document.getElementById('resetSettings');
        if (resetSettings) {
            console.log('✅ Reset settings button found and configured');
            resetSettings.addEventListener('click', () => {
                console.log('🔄 Reset settings button clicked');
                this.resetSettings();
            });
        } else {
            console.warn('⚠️ Reset settings button not found');
        }

        // Test detection button
        const testDetection = document.getElementById('testDetection');
        if (testDetection) {
            console.log('✅ Test detection button found and configured');
            testDetection.addEventListener('click', () => {
                console.log('🧪 Test detection button clicked');
                this.testDetection();
            });
        } else {
            console.warn('⚠️ Test detection button not found');
        }

        // Emergency disable button
        const emergencyDisable = document.getElementById('emergencyDisable');
        if (emergencyDisable) {
            console.log('✅ Emergency disable button found and configured');
            emergencyDisable.addEventListener('click', () => {
                console.log('🚨 Emergency disable button clicked');
                this.emergencyDisable();
            });
        } else {
            console.warn('⚠️ Emergency disable button not found');
        }
        
        // Add change listeners to form controls to enable save button
        const lateGracePeriod = document.getElementById('lateGracePeriod');
        if (lateGracePeriod) {
            lateGracePeriod.addEventListener('input', () => {
                console.log('🔄 Grace period changed');
                this.enableSaveButton();
            });
        }
        
        const updateFrequency = document.getElementById('updateFrequency');
        if (updateFrequency) {
            updateFrequency.addEventListener('change', () => {
                console.log('🔄 Update frequency changed');
                this.enableSaveButton();
            });
        }
    }

    toggleAutoStatus(enabled) {
        console.log('🔄 Toggling auto status detection:', enabled);
        
        const lateGracePeriod = document.getElementById('lateGracePeriod');
        const updateFrequency = document.getElementById('updateFrequency');
        const saveSettings = document.getElementById('saveSettings');
        const statusIndicator = document.getElementById('statusIndicator');
        const statusText = document.getElementById('statusText');
        const detectionStatus = document.getElementById('detectionStatus');

        if (enabled) {
            console.log('✅ Enabling auto status detection');
            // Enable form controls
            lateGracePeriod.disabled = false;
            updateFrequency.disabled = false;
            saveSettings.disabled = false;
            
            // Update UI
            statusIndicator.className = 'status-indicator active';
            statusIndicator.innerHTML = '<i class="fas fa-toggle-on fa-3x text-success"></i>';
            statusText.textContent = 'Enabled';
            statusText.className = 'mt-2 text-success';
            detectionStatus.className = 'badge bg-success';
            detectionStatus.textContent = 'Enabled';
        } else {
            console.log('❌ Disabling auto status detection');
            // Disable form controls but keep save button enabled
            lateGracePeriod.disabled = true;
            updateFrequency.disabled = true;
            saveSettings.disabled = false; // Keep save button enabled
            
            // Update UI
            statusIndicator.className = 'status-indicator inactive';
            statusIndicator.innerHTML = '<i class="fas fa-toggle-off fa-3x text-muted"></i>';
            statusText.textContent = 'Disabled';
            statusText.className = 'mt-2 text-muted';
            detectionStatus.className = 'badge bg-secondary';
            detectionStatus.textContent = 'Disabled';
        }

        // Save to localStorage
        localStorage.setItem('autoStatusEnabled', enabled);
        console.log('💾 Auto status setting saved to localStorage:', enabled);
    }

    enableSaveButton() {
        console.log('🔓 Enabling save button');
        const saveSettings = document.getElementById('saveSettings');
        if (saveSettings) {
            saveSettings.disabled = false;
            console.log('✅ Save button enabled');
        } else {
            console.warn('⚠️ Save button not found');
        }
    }

    async loadSettings() {
        console.log('📥 Loading settings from API...');
        try {
            const response = await fetch(`${this.apiBaseUrl}/settings.php`);
            console.log('📡 API Response status:', response.status);
            
            if (response.ok) {
                const data = await response.json();
                console.log('📋 API Response data:', data);
                
                if (data.success && data.settings) {
                    const settings = data.settings;
                    console.log('⚙️ Settings loaded:', settings);
                    
                    // Update form values
                    const toggle = document.getElementById('autoStatusToggle');
                    if (toggle) {
                        toggle.checked = settings.auto_status_detection?.value || false;
                    }
                    
                    const gracePeriod = document.getElementById('lateGracePeriod');
                    if (gracePeriod) {
                        gracePeriod.value = settings.late_grace_period?.value || 15;
                    }
                    
                    const frequency = document.getElementById('updateFrequency');
                    if (frequency) {
                        frequency.value = settings.update_frequency?.value || 'realtime';
                    }
                    
                    // Update UI based on settings
                    this.toggleAutoStatus(settings.auto_status_detection?.value || false);
                    
                    // Update last updated time
                    const lastUpdated = document.getElementById('lastUpdated');
                    if (lastUpdated && settings.last_settings_update?.value) {
                        lastUpdated.textContent = new Date(settings.last_settings_update.value).toLocaleString();
                    }
                }
            }
        } catch (error) {
            console.error('❌ Failed to load settings from API:', error);
            console.log('🔄 Falling back to localStorage...');
            // Fallback to localStorage
            const enabled = localStorage.getItem('autoStatusEnabled') === 'true';
            console.log('📦 localStorage value:', enabled);
            const toggle = document.getElementById('autoStatusToggle');
            if (toggle) {
                toggle.checked = enabled;
                console.log('✅ Toggle updated from localStorage');
            }
            this.toggleAutoStatus(enabled);
        }
    }

    async saveSettings() {
        console.log('💾 Saving settings...');
        const enabled = document.getElementById('autoStatusToggle').checked;
        const gracePeriod = document.getElementById('lateGracePeriod').value;
        const frequency = document.getElementById('updateFrequency').value;
        
        console.log('📊 Settings to save:', {
            auto_status_detection: enabled,
            late_grace_period: gracePeriod,
            update_frequency: frequency
        });

        try {
            const response = await fetch(`${this.apiBaseUrl}/settings.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    settings: {
                        auto_status_detection: enabled,
                        late_grace_period: gracePeriod,
                        update_frequency: frequency
                    }
                })
            });

            if (response.ok) {
                const data = await response.json();
                console.log('📡 Save API response:', data);
                
                if (data.success) {
                    console.log('✅ Settings saved successfully to API');
                    // Update last updated time
                    const lastUpdated = document.getElementById('lastUpdated');
                    if (lastUpdated) {
                        lastUpdated.textContent = new Date().toLocaleString();
                    }

                    this.showNotification('Settings saved successfully!', 'success');
                    
                    // Also save to localStorage as backup
                    localStorage.setItem('autoStatusEnabled', enabled);
                    localStorage.setItem('lateGracePeriod', gracePeriod);
                    localStorage.setItem('updateFrequency', frequency);
                    console.log('💾 Settings also saved to localStorage as backup');
                } else {
                    console.error('❌ API returned error:', data.message);
                    this.showNotification('Failed to save settings: ' + (data.message || 'Unknown error'), 'danger');
                }
            } else {
                console.error('❌ HTTP error:', response.status);
                this.showNotification('Failed to save settings: HTTP ' + response.status, 'danger');
            }
        } catch (error) {
            console.error('❌ Network error while saving settings:', error);
            this.showNotification('Failed to save settings: Network error', 'danger');
        }
    }

    resetSettings() {
        console.log('🔄 Reset settings requested');
        if (confirm('Are you sure you want to reset all settings to default values?')) {
            console.log('✅ Reset confirmed, applying default values...');
            // Reset form values
            document.getElementById('autoStatusToggle').checked = false;
            document.getElementById('lateGracePeriod').value = '15';
            document.getElementById('updateFrequency').value = 'realtime';
            
            // Reset localStorage
            localStorage.removeItem('autoStatusEnabled');
            localStorage.removeItem('lateGracePeriod');
            localStorage.removeItem('updateFrequency');
            console.log('🗑️ localStorage cleared');
            
            // Update UI
            this.toggleAutoStatus(false);
            const lastUpdated = document.getElementById('lastUpdated');
            if (lastUpdated) {
                lastUpdated.textContent = 'Never';
            }
            
            console.log('✅ Settings reset completed');
            this.showNotification('Settings reset to default values!', 'info');
        }
    }

    testDetection() {
        console.log('🧪 Test detection requested');
        this.showNotification('Testing auto status detection... This feature will be implemented in the backend.', 'info');
    }

    emergencyDisable() {
        console.log('🚨 Emergency disable requested');
        if (confirm('Are you sure you want to emergency disable auto status detection? This will immediately stop all automatic status updates.')) {
            console.log('✅ Emergency disable confirmed');
            document.getElementById('autoStatusToggle').checked = false;
            this.toggleAutoStatus(false);
            this.showNotification('Auto status detection has been emergency disabled!', 'warning');
        }
    }

    updateSettingsUI() {
        console.log('🎨 Updating settings UI...');
        // Update today's events count
        const todayEvents = document.getElementById('todayEvents');
        if (todayEvents) {
            const today = new Date().toDateString();
            const todayCount = this.events.filter(event => {
                const eventDate = new Date(event.start_time).toDateString();
                return eventDate === today;
            }).length;
            todayEvents.textContent = todayCount;
            console.log('📅 Today\'s events count updated:', todayCount);
        } else {
            console.warn('⚠️ Today events element not found');
        }
    }

    // QR Scanner Methods
    async initQRScanner() {
        console.log('📱 Initializing QR Scanner...');
        
        // Populate event selects
        await this.populateQRScannerEventSelects();
        
        // Setup event listeners
        this.setupQRScannerEventListeners();
        
            // Initialize scanner state
    this.scannerState = {
        isActive: false,
        stream: null,
        videoElement: null,
        canvasElement: null,
        scanInterval: null,
        recentScans: [],
        // Enhanced features from mobile app
        isCheckoutEnabled: false,
        recentlyScannedQRCodes: new Set(),
        isScanCooldown: false,
        cooldownSeconds: 2,
        cooldownTimer: null,
        showingDuplicateMessage: false,
        showingSuccessMessage: false,
        successStudentName: null,
        successAction: null,
        selectedEvent: null,
        isOfflineMode: false
    };
        
        // Start periodic cleanup of recently scanned codes (every 60 seconds)
        setInterval(() => {
            this.cleanupRecentlyScannedCodes();
        }, 60000);
        
        console.log('✅ QR Scanner initialized');
    }

    async populateQRScannerEventSelects() {
        console.log('📋 Populating QR Scanner event selects...');
        
        try {
            const response = await fetch(`${this.apiBaseUrl}/events/list.php`);
            if (response.ok) {
                const data = await response.json();
                if (data.success) {
                    const events = data.events || [];
                    
                    // Populate QR scanner event select
                    const qrEventSelect = document.getElementById('qrScannerEventSelect');
                    const manualEventSelect = document.getElementById('manualEventSelect');
                    
                    if (qrEventSelect) {
                        qrEventSelect.innerHTML = '<option value="">Choose an event...</option>';
                        events.forEach(event => {
                            const option = document.createElement('option');
                            option.value = event.id;
                            option.textContent = `${event.title} - ${new Date(event.start_time).toLocaleDateString()}`;
                            qrEventSelect.appendChild(option);
                        });
                    }
                    
                    if (manualEventSelect) {
                        manualEventSelect.innerHTML = '<option value="">Select event...</option>';
                        events.forEach(event => {
                            const option = document.createElement('option');
                            option.value = event.id;
                            option.textContent = `${event.title} - ${new Date(event.start_time).toLocaleDateString()}`;
                            manualEventSelect.appendChild(option);
                        });
                    }
                    
                    console.log('✅ QR Scanner event selects populated');
                }
            }
        } catch (error) {
            console.error('❌ Error populating QR Scanner event selects:', error);
        }
    }

    setupQRScannerEventListeners() {
        console.log('🎧 Setting up QR Scanner event listeners...');
        
        // Toggle scanner button
        const toggleBtn = document.getElementById('toggleScannerBtn');
        if (toggleBtn) {
            toggleBtn.addEventListener('click', () => this.toggleScanner());
        }
        
        // Manual entry form
        const manualForm = document.getElementById('manualEntryForm');
        if (manualForm) {
            manualForm.addEventListener('submit', (e) => this.handleManualEntry(e));
        }
        
        // Event selection change
        const eventSelect = document.getElementById('qrScannerEventSelect');
        if (eventSelect) {
            eventSelect.addEventListener('change', () => this.onEventSelectionChange());
        }
        
        // Test QR generation
        const generateTestQRBtn = document.getElementById('generateTestQRBtn');
        if (generateTestQRBtn) {
            generateTestQRBtn.addEventListener('click', () => this.generateTestQRCode());
        }
        
        // Enhanced mode toggles
        const checkoutModeToggle = document.getElementById('checkoutModeToggle');
        if (checkoutModeToggle) {
            checkoutModeToggle.addEventListener('change', (e) => this.toggleCheckoutMode(e.target.checked));
        }
        
        const offlineModeToggle = document.getElementById('offlineModeToggle');
        if (offlineModeToggle) {
            offlineModeToggle.addEventListener('change', (e) => this.toggleOfflineMode(e.target.checked));
        }
        
        console.log('✅ QR Scanner event listeners setup complete');
    }

    async toggleScanner() {
        console.log('🔄 Toggling scanner...');
        
        if (this.scannerState.isActive) {
            await this.stopScanner();
        } else {
            await this.startScanner();
        }
    }

    async startScanner() {
        console.log('🚀 Starting QR Scanner...');
        
        const selectedEvent = document.getElementById('qrScannerEventSelect').value;
        if (!selectedEvent) {
            this.showNotification('Please select an event first!', 'warning');
            return;
        }
        
        try {
            // Request camera access
            const stream = await navigator.mediaDevices.getUserMedia({ 
                video: { 
                    facingMode: 'environment',
                    width: { ideal: 1280 },
                    height: { ideal: 720 }
                } 
            });
            
            this.scannerState.stream = stream;
            this.scannerState.isActive = true;
            
            // Setup video element
            const video = document.getElementById('scannerVideo');
            const canvas = document.getElementById('scannerCanvas');
            const placeholder = document.getElementById('scannerPlaceholder');
            
            video.srcObject = stream;
            video.play();
            
            // Show video, hide placeholder
            video.style.display = 'block';
            placeholder.style.display = 'none';
            
            // Update UI
            this.updateScannerUI();
            
            // Start scanning loop
            this.startScanningLoop();
            
            // Start cleanup timer
            this.startCleanupTimer();
            
            console.log('✅ QR Scanner started successfully');
            this.showNotification('Scanner started! Point camera at QR code', 'success');
            
        } catch (error) {
            console.error('❌ Error starting scanner:', error);
            this.showNotification('Failed to start scanner: ' + error.message, 'danger');
        }
    }

    async stopScanner() {
        console.log('🛑 Stopping QR Scanner...');
        
        if (this.scannerState.stream) {
            this.scannerState.stream.getTracks().forEach(track => track.stop());
            this.scannerState.stream = null;
        }
        
        if (this.scannerState.scanInterval) {
            clearInterval(this.scannerState.scanInterval);
            this.scannerState.scanInterval = null;
        }
        
        if (this.scannerState.cleanupTimer) {
            clearInterval(this.scannerState.cleanupTimer);
            this.scannerState.cleanupTimer = null;
        }
        
        this.scannerState.isActive = false;
        
        // Reset UI
        const video = document.getElementById('scannerVideo');
        const placeholder = document.getElementById('scannerPlaceholder');
        
        video.style.display = 'none';
        placeholder.style.display = 'block';
        
        this.updateScannerUI();
        
        console.log('✅ QR Scanner stopped');
        this.showNotification('Scanner stopped', 'info');
    }

    startScanningLoop() {
        console.log('🔄 Starting scanning loop...');
        
        const video = document.getElementById('scannerVideo');
        const canvas = document.getElementById('scannerCanvas');
        const ctx = canvas.getContext('2d');
        
        this.scannerState.scanInterval = setInterval(() => {
            if (video.videoWidth > 0 && video.videoHeight > 0) {
                // Set canvas dimensions
                canvas.width = video.videoWidth;
                canvas.height = video.videoHeight;
                
                // Draw video frame to canvas
                ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
                
                // Get image data for QR detection
                const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                
                // Debug: Log scanning activity
                console.log('🔍 Scanning frame...', new Date().toISOString());
                
                // Simple QR code detection (basic pattern matching)
                // In a real implementation, you'd use a QR library like jsQR
                this.detectQRCode(imageData);
            }
        }, 100); // Scan every 100ms
    }

    detectQRCode(imageData) {
        try {
            // Check if scanner is in cooldown
            if (this.scannerState.isScanCooldown) {
                return;
            }
            
            // Use jsQR library for actual QR code detection
            const code = jsQR(imageData.data, imageData.width, imageData.height);
            
            console.log('🔍 jsQR result:', code);
            
            if (code && code.data && code.data.trim() !== '') {
                console.log('🔍 QR Code detected:', code.data);
                console.log('🔍 QR Code length:', code.data.length);
                console.log('🔍 QR Code first 50 chars:', code.data.substring(0, 50));
                
                // Check for duplicate QR code
                if (this.scannerState.recentlyScannedQRCodes.has(code.data)) {
                    console.log('🔄 Duplicate QR code detected');
                    this.showDuplicateMessage();
                    return;
                }
                
                // Clear duplicate message if showing
                if (this.scannerState.showingDuplicateMessage) {
                    this.scannerState.showingDuplicateMessage = false;
                }
                
                // Add to recently scanned codes
                this.scannerState.recentlyScannedQRCodes.add(code.data);
                
                // Parse the QR code data
                const qrData = this.parseQRCodeData(code.data);
                
                if (qrData && qrData.studentId) {
                    this.handleQRCodeScanned(qrData, code.data); // Pass original QR text
                }
            }
        } catch (error) {
            console.error('❌ Error detecting QR code:', error);
        }
    }

    parseQRCodeData(qrText) {
        console.log('🔍 Parsing QR data:', qrText);
        
        let eventId;
        let studentId;
        
        try {
            // Try to decode as base64 JSON first (exactly like mobile app)
            const decoded = atob(qrText);
            const payload = JSON.parse(decoded);
            
            console.log('📦 Decoded base64 payload:', payload);
            
            if (payload.eventId && payload.studentId) {
                // Traditional QR code with both eventId and studentId
                eventId = payload.eventId.toString();
                studentId = payload.studentId.toString();
            } else if (payload.studentId) {
                // Offline QR code with only studentId
                studentId = payload.studentId.toString();
            }
        } catch (e) {
            // If base64 decoding fails, treat raw as student ID (exactly like mobile app)
            studentId = qrText;
        }
        
        return { eventId, studentId };
    }

    async handleQRCodeScanned(qrData, originalQRText) {
        console.log('📱 QR Code scanned:', qrData);
        
        // Don't process empty QR data
        if (!originalQRText || originalQRText.trim() === '') {
            console.log('❌ Empty QR data - ignoring');
            return;
        }
        
        let eventId;
        let studentId;
        
        try {
            // Handle different QR code formats exactly like mobile app
            if (qrData.eventId && qrData.studentId) {
                // Traditional QR code with both eventId and studentId
                eventId = qrData.eventId;
                studentId = qrData.studentId;
            } else if (qrData.studentId) {
                // Offline QR code with only studentId
                studentId = qrData.studentId;
                
                if (this.scannerState.isOfflineMode) {
                    // Offline mode: use selected event
                    if (!this.scannerState.selectedEvent) {
                        this.showNotification('No event selected for offline mode!', 'warning');
                        return;
                    }
                    eventId = this.scannerState.selectedEvent;
                } else {
                    // Auto event mode: use UI selection
                    eventId = document.getElementById('qrScannerEventSelect').value;
                    if (!eventId) {
                        this.showNotification('No event selected!', 'warning');
                        return;
                    }
                }
            } else {
                // Try to parse as plain student ID for offline mode
                studentId = qrData;
                
                if (this.scannerState.isOfflineMode) {
                    // Offline mode: use selected event
                    if (!this.scannerState.selectedEvent) {
                        this.showNotification('No event selected for offline mode!', 'warning');
                        return;
                    }
                    eventId = this.scannerState.selectedEvent;
                } else {
                    // Auto event mode: use UI selection
                    eventId = document.getElementById('qrScannerEventSelect').value;
                    if (!eventId) {
                        this.showNotification('No event selected!', 'warning');
                        return;
                    }
                }
            }
        } catch (e) {
            // If parsing fails, treat raw as student ID for offline mode
            studentId = qrData;
            
            if (this.scannerState.isOfflineMode) {
                // Offline mode: use selected event
                if (!this.scannerState.selectedEvent) {
                    this.showNotification('No event selected for offline mode!', 'warning');
                    return;
                }
                eventId = this.scannerState.selectedEvent;
            } else {
                // Auto event mode: use UI selection
                eventId = document.getElementById('qrScannerEventSelect').value;
                if (!eventId) {
                    this.showNotification('No event selected!', 'warning');
                    return;
                }
            }
        }
        
        try {
            // Check current attendance status first (like mobile app)
            const currentStatus = await this.getCurrentAttendanceStatus(eventId, studentId);
            console.log('📊 Current attendance status:', currentStatus);
            
            // Check if checkout is enabled and validate student status (like mobile app)
            if (this.scannerState.isCheckoutEnabled) {
                if (currentStatus === 'not_checked_in') {
                    // Student not checked in, but checkout mode is enabled
                    this.addToRecentScans({
                        studentId: studentId,
                        studentName: 'Student',
                        eventId: eventId,
                        status: 'warning',
                        message: 'Student not checked in - cannot check out',
                        timestamp: new Date()
                    });
                    this.showNotification('Student not checked in - cannot check out', 'warning');
                    return;
                } else if (currentStatus === 'checked_out') {
                    // Student already checked out
                    this.addToRecentScans({
                        studentId: studentId,
                        studentName: 'Student',
                        eventId: eventId,
                        status: 'warning',
                        message: 'Student already checked out',
                        timestamp: new Date()
                    });
                    this.showNotification('Student already checked out', 'warning');
                    return;
                }
            } else {
                // Check-in mode - check if student is already checked in
                if (currentStatus === 'checked_in') {
                    // Student already checked in
                    this.addToRecentScans({
                        studentId: studentId,
                        studentName: 'Student',
                        eventId: eventId,
                        status: 'warning',
                        message: 'Student already checked in',
                        timestamp: new Date()
                    });
                    this.showNotification('Student already checked in', 'warning');
                    return;
                }
            }
            
            // Send to backend exactly like mobile app
            const requestBody = {
                qrCodeData: originalQRText, // Use original QR text like mobile app
                eventId: parseInt(eventId) || eventId,
                studentId: parseInt(studentId) || studentId,
            };
            
            console.log('📡 Sending QR scan request:', requestBody);
            
            // Mark attendance exactly like mobile app
            const response = await fetch(`${this.apiBaseUrl}/attendance/mark.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(requestBody)
            });
            
            console.log('📡 Response status:', response.status);
            console.log('📡 Response ok:', response.ok);
            
            if (response.ok) {
                const data = await response.json();
                console.log('📡 Response data:', data);
                
                if (data.success) {
                    console.log('✅ Success - showing success message');
                    
                    // Add to recent scans
                    this.addToRecentScans({
                        studentId: studentId,
                        studentName: data.attendance?.studentName || 'Student',
                        eventId: eventId,
                        status: 'success',
                        message: `Successfully ${data.action || 'checked in'}`,
                        timestamp: new Date()
                    });
                    
                    // Show success message exactly like mobile app
                    this.showSuccessMessage('Student', data.action || 'check_in');
                } else {
                    console.log('❌ API returned success=false');
                    
                    // Add to recent scans with error
                    this.addToRecentScans({
                        studentId: studentId,
                        studentName: 'Student',
                        eventId: eventId,
                        status: 'error',
                        message: data.message || 'Failed to mark attendance',
                        timestamp: new Date()
                    });
                    
                    this.showNotification('Failed to mark attendance: ' + (data.message || 'Unknown error'), 'danger');
                }
            } else {
                // Handle specific status codes properly
                const errorText = await response.text();
                console.log('❌ Response not ok:', errorText);
                
                let errorMessage = 'Network error';
                let scanStatus = 'error';
                
                try {
                    const errorData = JSON.parse(errorText);
                    if (errorData.message) {
                        errorMessage = errorData.message;
                        // Treat 409 (Conflict) as warning, not error
                        if (response.status === 409) {
                            scanStatus = 'warning';
                        }
                    }
                } catch (e) {
                    // If parsing fails, use default error message
                }
                
                // Add to recent scans
                this.addToRecentScans({
                    studentId: studentId,
                    studentName: 'Student',
                    eventId: eventId,
                    status: scanStatus,
                    message: errorMessage,
                    timestamp: new Date()
                });
                
                // Show appropriate notification
                if (response.status === 409) {
                    this.showNotification(errorMessage, 'warning');
                } else {
                    this.showNotification('Failed to mark attendance: ' + errorMessage, 'danger');
                }
            }
            
        } catch (error) {
            console.error('❌ Error marking attendance:', error);
            this.showNotification('Network error while marking attendance', 'danger');
        }
    }

    async getCurrentAttendanceStatus(eventId, studentId) {
        try {
            // Get recent attendances to check current status
            const response = await fetch(`${this.apiBaseUrl}/attendance/list_recent.php?limit=1000`);
            
            if (!response.ok) {
                console.log('❌ Failed to fetch attendances for status check');
                return 'unknown';
            }
            
            const data = await response.json();
            if (!data.success) {
                console.log('❌ Failed to get attendance data for status check');
                return 'unknown';
            }
            
            // Find attendance record for this student and event
            const attendance = data.attendances.find(a => 
                a.eventId === eventId.toString() && a.studentId === studentId.toString()
            );
            
            if (!attendance) {
                return 'not_checked_in';
            }
            
            // Check if student is checked in or checked out
            if (attendance.checkInTime && !attendance.checkOutTime) {
                return 'checked_in';
            } else if (attendance.checkInTime && attendance.checkOutTime) {
                return 'checked_out';
            } else {
                return 'not_checked_in';
            }
            
        } catch (error) {
            console.error('❌ Error checking attendance status:', error);
            return 'unknown';
        }
    }

    addToRecentScans(scanData) {
        console.log('📝 Adding scan to recent scans:', scanData);
        
        this.scannerState.recentScans.unshift(scanData);
        
        // Keep only last 10 scans
        if (this.scannerState.recentScans.length > 10) {
            this.scannerState.recentScans = this.scannerState.recentScans.slice(0, 10);
        }
        
        this.updateRecentScansUI();
    }

    updateRecentScansUI() {
        console.log('🎨 Updating recent scans UI...');
        
        const recentScansList = document.getElementById('recentScansList');
        if (!recentScansList) return;
        
        if (this.scannerState.recentScans.length === 0) {
            recentScansList.innerHTML = `
                <div class="text-center text-muted">
                    <i class="fas fa-info-circle"></i> No scans yet
                </div>
            `;
            return;
        }
        
        const scansHTML = this.scannerState.recentScans.map(scan => {
            const statusClass = scan.status === 'success' ? 'success' : 
                               scan.status === 'error' ? 'error' : 'warning';
            
            return `
                <div class="scan-result ${statusClass}">
                    <div class="d-flex justify-content-between align-items-start">
                        <div>
                            <strong>${scan.studentName || scan.studentId}</strong><br>
                            <small>${scan.studentName ? `ID: ${scan.studentId} - ` : ''}${scan.message}</small>
                        </div>
                        <small>${scan.timestamp.toLocaleTimeString()}</small>
                    </div>
                </div>
            `;
        }).join('');
        
        recentScansList.innerHTML = scansHTML;
    }

    async handleManualEntry(event) {
        event.preventDefault();
        console.log('✍️ Handling manual entry...');
        
        const studentId = document.getElementById('manualStudentId').value.trim();
        const eventId = document.getElementById('manualEventSelect').value;
        
        if (!studentId || !eventId) {
            this.showNotification('Please fill in all fields!', 'warning');
            return;
        }
        
        try {
            // First, look up the user by student_id to get the user_id
            console.log('🔍 Looking up user by student_id:', studentId);
            const userResponse = await fetch(`${this.apiBaseUrl}/users/list.php`);
            
            if (!userResponse.ok) {
                throw new Error(`Failed to fetch users: HTTP ${userResponse.status}`);
            }
            
            const userData = await userResponse.json();
            if (!userData.success) {
                throw new Error('Failed to fetch users data');
            }
            
            // Find the user with matching student_id
            const user = userData.users.find(u => u.student_id === studentId);
            if (!user) {
                this.showNotification(`Student with ID ${studentId} not found!`, 'danger');
                return;
            }
            
            console.log('✅ Found user:', user);
            
            // Create QR code data in the format expected by the API
            const qrCodeData = {
                studentId: parseInt(user.id), // Use the user.id (integer) instead of student_id (string)
                eventId: parseInt(eventId)
            };
            
            // Encode as base64 JSON
            const qrCodeDataString = btoa(JSON.stringify(qrCodeData));
            
            const requestBody = {
                qrCodeData: qrCodeDataString,
                eventId: parseInt(eventId),
                studentId: parseInt(user.id) // Use the user.id (integer)
            };
            
            console.log('📡 Sending manual entry request:', requestBody);
            console.log('📡 Manual Entry Data (decoded):', qrCodeData);
            
            const response = await fetch(`${this.apiBaseUrl}/attendance/mark.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(requestBody)
            });
            
            console.log('📡 Manual Entry API Response status:', response.status);
            
            if (response.ok) {
                const data = await response.json();
                console.log('📡 Manual Entry API Response data:', data);
                
                if (data.success) {
                    this.showNotification(`Attendance marked for ${user.name} (${studentId})!`, 'success');
                    
                    // Clear form
                    document.getElementById('manualStudentId').value = '';
                    document.getElementById('manualEventSelect').value = '';
                    
                    // Add to recent scans
                    this.addToRecentScans({
                        studentId: studentId,
                        studentName: user.name,
                        eventId: eventId,
                        status: 'success',
                        message: 'Manual entry - Attendance marked',
                        timestamp: new Date()
                    });
                } else {
                    this.showNotification('Failed to mark attendance: ' + (data.message || 'Unknown error'), 'danger');
                }
            } else {
                const errorText = await response.text();
                console.error('📡 Manual Entry API Error response:', errorText);
                throw new Error(`HTTP ${response.status}: ${errorText}`);
            }
            
        } catch (error) {
            console.error('❌ Error in manual entry:', error);
            this.showNotification('Network error while marking attendance', 'danger');
        }
    }

    onEventSelectionChange() {
        console.log('📅 Event selection changed in QR Scanner');
        // Update offline mode state based on event selection
        const selectedEvent = document.getElementById('qrScannerEventSelect').value;
        if (selectedEvent && this.scannerState.isOfflineMode) {
            this.scannerState.selectedEvent = selectedEvent;
        }
    }

    toggleCheckoutMode(enabled) {
        console.log('🔄 Toggling checkout mode:', enabled);
        this.scannerState.isCheckoutEnabled = enabled;
        
        // Clear recent scans when mode changes
        this.scannerState.recentlyScannedQRCodes.clear();
        this.scannerState.showingDuplicateMessage = false;
        
        this.showNotification(
            enabled ? 'Checkout mode ENABLED' : 'Checkout mode DISABLED',
            'info'
        );
        
        this.updateScannerUI();
    }

    toggleOfflineMode(enabled) {
        console.log('🔄 Toggling offline mode:', enabled);
        this.scannerState.isOfflineMode = enabled;
        
        if (enabled) {
            // In offline mode, require event selection
            const selectedEvent = document.getElementById('qrScannerEventSelect').value;
            if (!selectedEvent) {
                this.showNotification('Please select an event for offline mode!', 'warning');
                document.getElementById('offlineModeToggle').checked = false;
                this.scannerState.isOfflineMode = false;
                return;
            }
            this.scannerState.selectedEvent = selectedEvent;
        }
        
        // Clear recent scans when mode changes
        this.scannerState.recentlyScannedQRCodes.clear();
        this.scannerState.showingDuplicateMessage = false;
        
        this.showNotification(
            enabled ? 'Offline mode ENABLED' : 'Offline mode DISABLED',
            'info'
        );
        
        this.updateScannerUI();
    }

    startScanCooldown() {
        console.log('⏰ Starting scan cooldown...');
        this.scannerState.isScanCooldown = true;
        this.scannerState.cooldownSeconds = 2;
        
        if (this.scannerState.cooldownTimer) {
            clearInterval(this.scannerState.cooldownTimer);
        }
        
        this.scannerState.cooldownTimer = setInterval(() => {
            this.scannerState.cooldownSeconds--;
            
            // Update cooldown display
            const cooldownEl = document.getElementById('cooldownSeconds');
            if (cooldownEl) {
                cooldownEl.textContent = this.scannerState.cooldownSeconds;
            }
            
            if (this.scannerState.cooldownSeconds <= 0) {
                clearInterval(this.scannerState.cooldownTimer);
                this.scannerState.isScanCooldown = false;
                this.scannerState.showingSuccessMessage = false;
                this.scannerState.successStudentName = null;
                this.scannerState.successAction = null;
                
                // Hide success overlay
                const overlay = document.getElementById('successMessageOverlay');
                if (overlay) {
                    overlay.style.display = 'none';
                }
                
                this.updateScannerUI();
            }
        }, 1000);
        
        this.updateScannerUI();
    }



    showDuplicateMessage() {
        if (this.scannerState.isScanCooldown) return;
        if (this.scannerState.showingDuplicateMessage) return;
        
        console.log('🔄 Showing duplicate message');
        this.scannerState.showingDuplicateMessage = true;
        
        // Show duplicate overlay
        const overlay = document.getElementById('duplicateMessageOverlay');
        if (overlay) {
            overlay.style.display = 'flex';
        }
        
        // Auto-hide duplicate message after 3 seconds
        setTimeout(() => {
            this.dismissDuplicateMessage();
        }, 3000);
        
        this.updateScannerUI();
    }

    dismissDuplicateMessage() {
        console.log('❌ Dismissing duplicate message');
        this.scannerState.showingDuplicateMessage = false;
        
        // Hide duplicate overlay
        const overlay = document.getElementById('duplicateMessageOverlay');
        console.log('🔍 Found overlay element:', overlay);
        if (overlay) {
            console.log('🔍 Hiding overlay, current display:', overlay.style.display);
            overlay.style.display = 'none';
            console.log('🔍 Overlay display after hiding:', overlay.style.display);
        } else {
            console.log('❌ Overlay element not found!');
        }
        
        // Don't clear recently scanned codes - keep them to prevent multiple entries
        // this.scannerState.recentlyScannedQRCodes.clear();
        
        this.updateScannerUI();
    }

    showSuccessMessage(studentName, action) {
        console.log('✅ Showing success message:', studentName, action);
        this.scannerState.showingSuccessMessage = true;
        this.scannerState.successStudentName = studentName;
        this.scannerState.successAction = action;
        
        // Update success overlay content
        const overlay = document.getElementById('successMessageOverlay');
        const icon = document.getElementById('successIcon');
        const title = document.getElementById('successTitle');
        const studentNameEl = document.getElementById('successStudentName');
        
        if (overlay && icon && title && studentNameEl) {
            // Update icon and colors based on action
            if (action === 'check_in') {
                icon.className = 'fas fa-login fa-3x text-success mb-3';
                title.textContent = 'CHECKED IN';
                title.className = 'text-success';
            } else {
                icon.className = 'fas fa-logout fa-3x text-primary mb-3';
                title.textContent = 'CHECKED OUT';
                title.className = 'text-primary';
            }
            
            studentNameEl.textContent = studentName;
            overlay.style.display = 'flex';
        }
        
        this.startScanCooldown();
        this.updateScannerUI();
    }

    updateScannerUI() {
        console.log('🎨 Updating scanner UI...');
        
        const statusBadge = document.getElementById('scannerStatus');
        const toggleBtn = document.getElementById('toggleScannerBtn');
        const infoAlert = document.getElementById('scannerInfo');
        const infoText = document.getElementById('scannerInfoText');
        
        if (this.scannerState.isActive) {
            statusBadge.textContent = 'Active';
            statusBadge.className = 'badge bg-success me-2';
            toggleBtn.innerHTML = '<i class="fas fa-stop"></i> Stop Scanner';
            toggleBtn.className = 'btn btn-sm btn-outline-danger';
            
            infoAlert.style.display = 'block';
            
            // Enhanced status message based on modes
            let statusMessage = 'Scanner is active - Point camera at QR code';
            if (this.scannerState.isCheckoutEnabled) {
                statusMessage += ' (Checkout Mode)';
            }
            if (this.scannerState.isOfflineMode) {
                statusMessage += ' (Offline Mode)';
            }
            if (this.scannerState.isScanCooldown) {
                statusMessage += ` (Cooldown: ${this.scannerState.cooldownSeconds}s)`;
            }
            
            infoText.textContent = statusMessage;
        } else {
            statusBadge.textContent = 'Inactive';
            statusBadge.className = 'badge bg-secondary me-2';
            toggleBtn.innerHTML = '<i class="fas fa-play"></i> Start Scanner';
            toggleBtn.className = 'btn btn-sm btn-outline-primary';
            
            infoAlert.style.display = 'none';
        }
        
        // Update mode indicators
        this.updateModeIndicators();
    }

    updateModeIndicators() {
        // Update checkout mode toggle
        const checkoutToggle = document.getElementById('checkoutModeToggle');
        if (checkoutToggle) {
            checkoutToggle.checked = this.scannerState.isCheckoutEnabled;
        }
        
        // Update offline mode toggle
        const offlineToggle = document.getElementById('offlineModeToggle');
        if (offlineToggle) {
            offlineToggle.checked = this.scannerState.isOfflineMode;
        }
    }

    cleanupRecentlyScannedCodes() {
        console.log('🧹 Cleaning up recently scanned codes');
        this.scannerState.recentlyScannedQRCodes.clear();
    }

    // Auto-cleanup recently scanned codes every 5 minutes
    startCleanupTimer() {
        if (this.scannerState.cleanupTimer) {
            clearInterval(this.scannerState.cleanupTimer);
        }
        
        this.scannerState.cleanupTimer = setInterval(() => {
            console.log('🧹 Auto-cleaning up recently scanned codes');
            this.scannerState.recentlyScannedQRCodes.clear();
        }, 5 * 60 * 1000); // 5 minutes
    }

    generateTestQRCode() {
        console.log('🎨 Generating test QR code...');
        
        const studentId = document.getElementById('testQRInput').value.trim();
        if (!studentId) {
            this.showNotification('Please enter a student ID!', 'warning');
            return;
        }
        
        try {
            const qrContainer = document.getElementById('testQRCode');
            
            // Clear previous QR code
            qrContainer.innerHTML = '';
            
            // Create QR code data in the same format as mobile app
            let qrData;
            let qrText;
            
            if (this.scannerState.isOfflineMode) {
                // Offline mode: create QR with only studentId
                qrData = {
                    studentId: studentId
                };
                qrText = JSON.stringify(qrData);
                console.log('📱 Generating offline QR code:', qrData);
            } else {
                // Traditional mode: create QR with eventId and studentId
                const selectedEvent = document.getElementById('qrScannerEventSelect').value;
                if (!selectedEvent) {
                    this.showNotification('Please select an event for traditional QR code!', 'warning');
                    return;
                }
                qrData = {
                    eventId: parseInt(selectedEvent),
                    studentId: studentId
                };
                qrText = JSON.stringify(qrData);
                console.log('📱 Generating traditional QR code:', qrData);
            }
            
            // Generate QR code using QRCode library
            QRCode.toCanvas(qrContainer, qrText, {
                width: 200,
                height: 200,
                margin: 2,
                color: {
                    dark: '#000000',
                    light: '#FFFFFF'
                }
            }, (error) => {
                if (error) {
                    console.error('❌ Error generating QR code:', error);
                    qrContainer.innerHTML = '<p class="text-danger">Error generating QR code</p>';
                } else {
                    console.log('✅ Test QR code generated successfully');
                    qrContainer.innerHTML += `
                        <div class="mt-2">
                            <small class="text-muted">Student ID: ${studentId}</small>
                            <br>
                            <small class="text-muted">Format: ${this.scannerState.isOfflineMode ? 'Offline' : 'Traditional'}</small>
                            <br>
                            <small class="text-muted">Data: ${qrText}</small>
                        </div>
                    `;
                }
            });
            
        } catch (error) {
            console.error('❌ Error in QR generation:', error);
            this.showNotification('Failed to generate QR code', 'danger');
        }
    }

    // RFID Scanner Methods
    async initRFIDScanner() {
        console.log('📱 Initializing RFID Scanner...');
        
        // Check NFC availability
        await this.checkNFCAvailability();
        
        // Populate event selects
        await this.populateRFIDScannerEventSelects();
        
        // Setup event listeners
        this.setupRFIDScannerEventListeners();
        
        // Initialize scanner state
        this.rfidScannerState = {
            isActive: false,
            reader: null,
            recentScans: [],
            isCheckoutEnabled: false,
            recentlyScannedTags: new Set(),
            isScanCooldown: false,
            cooldownSeconds: 2,
            cooldownTimer: null,
            showingDuplicateMessage: false,
            showingSuccessMessage: false,
            successStudentName: null,
            successAction: null,
            selectedEvent: null,
            isOfflineMode: false,
            nfcAvailable: false
        };
        
        // Start periodic cleanup of recently scanned tags (every 60 seconds)
        setInterval(() => {
            this.cleanupRecentlyScannedRFIDTags();
        }, 60000);
        
        console.log('✅ RFID Scanner initialized');
    }

    async checkNFCAvailability() {
        console.log('🔍 Checking NFC availability...');
        const statusDiv = document.getElementById('nfcAvailabilityStatus');
        
        if (!('NDEFReader' in window)) {
            if (statusDiv) {
                statusDiv.innerHTML = `
                    <div class="alert alert-warning">
                        <i class="fas fa-exclamation-triangle"></i>
                        <strong>NFC Not Supported</strong><br>
                        <small>Your browser does not support Web NFC API. Please use Chrome/Edge on Android or Chrome OS.</small>
                    </div>
                `;
            }
            this.rfidScannerState = this.rfidScannerState || {};
            this.rfidScannerState.nfcAvailable = false;
            return false;
        }
        
        // Check if we're on HTTPS or localhost
        const isSecure = location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1';
        
        if (!isSecure) {
            if (statusDiv) {
                statusDiv.innerHTML = `
                    <div class="alert alert-warning">
                        <i class="fas fa-exclamation-triangle"></i>
                        <strong>HTTPS Required</strong><br>
                        <small>Web NFC requires HTTPS or localhost. Please access via HTTPS.</small>
                    </div>
                `;
            }
            this.rfidScannerState = this.rfidScannerState || {};
            this.rfidScannerState.nfcAvailable = false;
            return false;
        }
        
        if (statusDiv) {
            statusDiv.innerHTML = `
                <div class="alert alert-success">
                    <i class="fas fa-check-circle"></i>
                    <strong>NFC Available</strong><br>
                    <small>Ready to scan RFID/NFC tags</small>
                </div>
            `;
        }
        this.rfidScannerState = this.rfidScannerState || {};
        this.rfidScannerState.nfcAvailable = true;
        return true;
    }

    async populateRFIDScannerEventSelects() {
        console.log('📋 Populating RFID Scanner event selects...');
        
        try {
            const response = await fetch(`${this.apiBaseUrl}/events/list.php`);
            if (response.ok) {
                const data = await response.json();
                if (data.success) {
                    const events = data.events || [];
                    
                    // Populate RFID scanner event select
                    const rfidEventSelect = document.getElementById('rfidScannerEventSelect');
                    const rfidManualEventSelect = document.getElementById('rfidManualEventSelect');
                    
                    if (rfidEventSelect) {
                        rfidEventSelect.innerHTML = '<option value="">Choose an event...</option>';
                        events.forEach(event => {
                            const option = document.createElement('option');
                            option.value = event.id;
                            option.textContent = `${event.title} - ${new Date(event.start_time).toLocaleDateString()}`;
                            rfidEventSelect.appendChild(option);
                        });
                    }
                    
                    if (rfidManualEventSelect) {
                        rfidManualEventSelect.innerHTML = '<option value="">Select event...</option>';
                        events.forEach(event => {
                            const option = document.createElement('option');
                            option.value = event.id;
                            option.textContent = `${event.title} - ${new Date(event.start_time).toLocaleDateString()}`;
                            rfidManualEventSelect.appendChild(option);
                        });
                    }
                    
                    console.log('✅ RFID Scanner event selects populated');
                }
            }
        } catch (error) {
            console.error('❌ Error populating RFID Scanner event selects:', error);
        }
    }

    setupRFIDScannerEventListeners() {
        console.log('🎧 Setting up RFID Scanner event listeners...');
        
        // Toggle scanner button
        const toggleBtn = document.getElementById('toggleRFIDScannerBtn');
        if (toggleBtn) {
            toggleBtn.addEventListener('click', () => this.toggleRFIDScanner());
        }
        
        // Manual entry form
        const manualForm = document.getElementById('rfidManualEntryForm');
        if (manualForm) {
            manualForm.addEventListener('submit', (e) => this.handleRFIDManualEntry(e));
        }
        
        // Event selection change
        const eventSelect = document.getElementById('rfidScannerEventSelect');
        if (eventSelect) {
            eventSelect.addEventListener('change', () => this.onRFIDEventSelectionChange());
        }
        
        // Enhanced mode toggles
        const checkoutModeToggle = document.getElementById('rfidCheckoutModeToggle');
        if (checkoutModeToggle) {
            checkoutModeToggle.addEventListener('change', (e) => this.toggleRFIDCheckoutMode(e.target.checked));
        }
        
        const offlineModeToggle = document.getElementById('rfidOfflineModeToggle');
        if (offlineModeToggle) {
            offlineModeToggle.addEventListener('change', (e) => this.toggleRFIDOfflineMode(e.target.checked));
        }
        
        console.log('✅ RFID Scanner event listeners setup complete');
    }

    async toggleRFIDScanner() {
        console.log('🔄 Toggling RFID scanner...');
        
        if (this.rfidScannerState && this.rfidScannerState.isActive) {
            await this.stopRFIDScanner();
        } else {
            await this.startRFIDScanner();
        }
    }

    async startRFIDScanner() {
        console.log('🚀 Starting RFID Scanner...');
        
        if (!this.rfidScannerState || !this.rfidScannerState.nfcAvailable) {
            this.showNotification('NFC is not available on this device/browser', 'warning');
            return;
        }
        
        const selectedEvent = document.getElementById('rfidScannerEventSelect').value;
        if (!selectedEvent && (!this.rfidScannerState || !this.rfidScannerState.isOfflineMode)) {
            this.showNotification('Please select an event first!', 'warning');
            return;
        }
        
        try {
            const reader = new NDEFReader();
            this.rfidScannerState.reader = reader;
            this.rfidScannerState.isActive = true;
            
            // Update UI
            this.updateRFIDScannerUI();
            
            // Start scanning
            await reader.scan();
            
            reader.addEventListener('reading', (event) => {
                this.handleRFIDTagRead(event);
            });
            
            reader.addEventListener('readingerror', (error) => {
                console.error('❌ RFID reading error:', error);
                this.showNotification('Error reading RFID tag: ' + error.message, 'danger');
            });
            
            console.log('✅ RFID Scanner started successfully');
            this.showNotification('RFID Scanner started! Hold device near tag', 'success');
            
            // Update info
            const infoDiv = document.getElementById('rfidScannerInfo');
            const infoText = document.getElementById('rfidScannerInfoText');
            if (infoDiv && infoText) {
                infoDiv.style.display = 'block';
                infoText.textContent = 'Hold device near RFID/NFC tag...';
            }
            
        } catch (error) {
            console.error('❌ Error starting RFID scanner:', error);
            this.showNotification('Failed to start scanner: ' + error.message, 'danger');
            if (this.rfidScannerState) {
                this.rfidScannerState.isActive = false;
            }
            this.updateRFIDScannerUI();
        }
    }

    async stopRFIDScanner() {
        console.log('🛑 Stopping RFID Scanner...');
        
        if (this.rfidScannerState && this.rfidScannerState.reader) {
            // NDEFReader doesn't have a stop method, but we can just stop listening
            this.rfidScannerState.reader = null;
        }
        
        if (this.rfidScannerState && this.rfidScannerState.cooldownTimer) {
            clearInterval(this.rfidScannerState.cooldownTimer);
            this.rfidScannerState.cooldownTimer = null;
        }
        
        if (this.rfidScannerState) {
            this.rfidScannerState.isActive = false;
        }
        
        // Reset UI
        this.updateRFIDScannerUI();
        
        // Hide info
        const infoDiv = document.getElementById('rfidScannerInfo');
        if (infoDiv) {
            infoDiv.style.display = 'none';
        }
        
        console.log('✅ RFID Scanner stopped');
        this.showNotification('RFID Scanner stopped', 'info');
    }

    async handleRFIDTagRead(event) {
        if (!this.rfidScannerState || this.rfidScannerState.isScanCooldown) {
            return;
        }
        
        console.log('🔵 RFID Tag detected:', event);
        
        try {
            let tagData = null;
            
            // Try to read NDEF message
            if (event.message && event.message.records && event.message.records.length > 0) {
                const record = event.message.records[0];
                
                if (record.recordType === 'text') {
                    // Text record - decode as UTF-8
                    const decoder = new TextDecoder();
                    tagData = decoder.decode(record.data);
                } else if (record.recordType === 'mime' && record.mediaType === 'text/plain') {
                    const decoder = new TextDecoder();
                    tagData = decoder.decode(record.data);
                }
            }
            
            // Fallback: Use tag ID if no NDEF data
            if (!tagData && event.serialNumber) {
                // Convert serial number to hex string
                tagData = Array.from(new Uint8Array(event.serialNumber))
                    .map(b => b.toString(16).padStart(2, '0'))
                    .join(':');
            }
            
            if (!tagData) {
                console.warn('⚠️ Could not extract data from RFID tag');
                this.showNotification('Could not read tag data', 'warning');
                return;
            }
            
            console.log('📋 Tag Data:', tagData);
            
            // Check for duplicate tag
            if (this.rfidScannerState.recentlyScannedTags.has(tagData)) {
                console.log('🔄 Duplicate tag detected');
                this.showRFIDDuplicateMessage();
                return;
            }
            
            // Clear duplicate message if showing
            if (this.rfidScannerState.showingDuplicateMessage) {
                this.rfidScannerState.showingDuplicateMessage = false;
                const overlay = document.getElementById('rfidDuplicateMessageOverlay');
                if (overlay) overlay.style.display = 'none';
            }
            
            // Add to recently scanned tags
            this.rfidScannerState.recentlyScannedTags.add(tagData);
            
            // Process tag data
            await this.processRFIDTagData(tagData);
            
        } catch (error) {
            console.error('❌ Error processing RFID tag:', error);
            this.showNotification('Error processing tag: ' + error.message, 'danger');
        }
    }

    async processRFIDTagData(tagData) {
        console.log('📋 Processing RFID tag data:', tagData);
        
        let eventId;
        let studentId;
        
        try {
            // Try to decode as base64 JSON first
            const decoded = atob(tagData);
            const payload = JSON.parse(decoded);
            
            if (payload.eventId && payload.studentId) {
                // Traditional format - both present
                eventId = payload.eventId.toString();
                studentId = payload.studentId.toString();
            } else if (payload.studentId) {
                // Offline format - only studentId
                studentId = payload.studentId.toString();
                
                if (this.rfidScannerState.isOfflineMode) {
                    if (!this.rfidScannerState.selectedEvent) {
                        const selectedEventId = document.getElementById('rfidScannerEventSelect').value;
                        if (!selectedEventId) {
                            this.showNotification('No event selected for offline mode!', 'warning');
                            return;
                        }
                        eventId = selectedEventId;
                    } else {
                        eventId = this.rfidScannerState.selectedEvent;
                    }
                } else {
                    const selectedEventId = document.getElementById('rfidScannerEventSelect').value;
                    if (!selectedEventId) {
                        this.showNotification('No event selected!', 'warning');
                        return;
                    }
                    eventId = selectedEventId;
                }
            } else {
                throw new Error('Invalid payload format');
            }
        } catch (e) {
            // If not JSON, treat as plain student ID
            console.log('⚠️ Not JSON format, treating as plain student ID');
            studentId = tagData;
            
            if (this.rfidScannerState.isOfflineMode) {
                const selectedEventId = document.getElementById('rfidScannerEventSelect').value;
                if (!selectedEventId) {
                    this.showNotification('No event selected for offline mode!', 'warning');
                    return;
                }
                eventId = selectedEventId;
            } else {
                const selectedEventId = document.getElementById('rfidScannerEventSelect').value;
                if (!selectedEventId) {
                    this.showNotification('No event selected!', 'warning');
                    return;
                }
                eventId = selectedEventId;
            }
        }
        
        // Get current attendance status
        const currentStatus = await this.getCurrentRFIDAttendanceStatus(eventId, studentId);
        
        // Check if checkout is enabled and validate student status
        if (this.rfidScannerState.isCheckoutEnabled) {
            if (currentStatus === 'not_checked_in') {
                this.showNotification('Student not checked in - cannot check out', 'warning');
                return;
            } else if (currentStatus === 'checked_out') {
                this.showNotification('Student already checked out', 'info');
                return;
            }
        } else {
            // Check-in mode
            if (currentStatus === 'checked_in') {
                this.showNotification('Student already checked in', 'info');
                return;
            }
        }
        
        // Prepare QR code data for API
        let qrCodeDataToSend;
        if (this.rfidScannerState.isOfflineMode) {
            const offlinePayload = JSON.stringify({ studentId: studentId });
            qrCodeDataToSend = btoa(offlinePayload);
        } else {
            qrCodeDataToSend = tagData;
        }
        
        // Send to API
        await this.markAttendanceFromRFID(eventId, studentId, qrCodeDataToSend);
    }

    async getCurrentRFIDAttendanceStatus(eventId, studentId) {
        try {
            const response = await fetch(`${this.apiBaseUrl}/attendance/list_by_event.php?eventId=${eventId}`);
            if (response.ok) {
                const data = await response.json();
                if (data.success && data.attendances) {
                    const attendance = data.attendances.find(a => 
                        a.studentId === studentId || a.user_id === studentId
                    );
                    
                    if (attendance) {
                        if (attendance.checkOutTime) return 'checked_out';
                        if (attendance.checkInTime) return 'checked_in';
                    }
                }
            }
        } catch (error) {
            console.error('Error checking attendance status:', error);
        }
        return 'not_checked_in';
    }

    async markAttendanceFromRFID(eventId, studentId, qrCodeData) {
        try {
            const requestBody = {
                qrCodeData: qrCodeData,
                eventId: parseInt(eventId) || eventId,
                studentId: parseInt(studentId) || studentId,
            };
            
            console.log('📡 Sending RFID attendance request:', requestBody);
            
            const response = await fetch(`${this.apiBaseUrl}/attendance/mark.php`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(requestBody)
            });
            
            if (response.ok) {
                const data = await response.json();
                if (data.success) {
                    const action = data.action || 'check_in';
                    const attendance = data.attendance;
                    const studentName = attendance.studentName || 'Student';
                    
                    // Add to recent scans
                    this.addToRFIDRecentScans({
                        studentId: studentId,
                        studentName: studentName,
                        eventId: eventId,
                        status: 'success',
                        message: action === 'check_in' ? 'Checked in' : 'Checked out',
                        timestamp: new Date()
                    });
                    
                    // Show success message
                    this.showRFIDSuccessMessage(studentName, action);
                    
                    // Start cooldown
                    this.startRFIDScanCooldown();
                    
                    this.showNotification(`${studentName} ${action === 'check_in' ? 'checked in' : 'checked out'} successfully!`, 'success');
                } else {
                    this.showNotification(data.message || 'Failed to mark attendance', 'danger');
                }
            } else {
                const errorData = await response.json().catch(() => ({}));
                this.showNotification(errorData.message || 'Failed to mark attendance', 'danger');
            }
        } catch (error) {
            console.error('❌ Error marking attendance:', error);
            this.showNotification('Error marking attendance: ' + error.message, 'danger');
        }
    }

    addToRFIDRecentScans(scan) {
        if (!this.rfidScannerState) return;
        this.rfidScannerState.recentScans.unshift(scan);
        if (this.rfidScannerState.recentScans.length > 10) {
            this.rfidScannerState.recentScans.pop();
        }
        this.updateRFIDRecentScansList();
    }

    updateRFIDRecentScansList() {
        const listDiv = document.getElementById('rfidRecentScansList');
        if (!listDiv || !this.rfidScannerState) return;
        
        if (this.rfidScannerState.recentScans.length === 0) {
            listDiv.innerHTML = '<div class="text-center text-muted"><i class="fas fa-info-circle"></i> No scans yet</div>';
            return;
        }
        
        listDiv.innerHTML = this.rfidScannerState.recentScans.map(scan => {
            const statusClass = scan.status === 'success' ? 'success' : scan.status === 'warning' ? 'warning' : 'danger';
            const time = new Date(scan.timestamp).toLocaleTimeString();
            return `
                <div class="d-flex justify-content-between align-items-center mb-2 p-2 border rounded">
                    <div>
                        <strong>${scan.studentName}</strong><br>
                        <small class="text-muted">${scan.message}</small>
                    </div>
                    <div class="text-end">
                        <span class="badge bg-${statusClass}">${scan.status}</span><br>
                        <small class="text-muted">${time}</small>
                    </div>
                </div>
            `;
        }).join('');
    }

    showRFIDDuplicateMessage() {
        if (!this.rfidScannerState || this.rfidScannerState.isScanCooldown) return;
        if (this.rfidScannerState.showingDuplicateMessage) return;
        
        this.rfidScannerState.showingDuplicateMessage = true;
        const overlay = document.getElementById('rfidDuplicateMessageOverlay');
        if (overlay) overlay.style.display = 'block';
    }

    dismissRFIDDuplicateMessage() {
        if (!this.rfidScannerState) return;
        this.rfidScannerState.showingDuplicateMessage = false;
        const overlay = document.getElementById('rfidDuplicateMessageOverlay');
        if (overlay) overlay.style.display = 'none';
    }

    showRFIDSuccessMessage(studentName, action) {
        if (!this.rfidScannerState) return;
        this.rfidScannerState.showingSuccessMessage = true;
        this.rfidScannerState.successStudentName = studentName;
        this.rfidScannerState.successAction = action;
        
        const overlay = document.getElementById('rfidSuccessMessageOverlay');
        const icon = document.getElementById('rfidSuccessIcon');
        const title = document.getElementById('rfidSuccessTitle');
        const name = document.getElementById('rfidSuccessStudentName');
        
        if (overlay) overlay.style.display = 'block';
        if (icon) {
            icon.className = action === 'check_in' 
                ? 'fas fa-check-circle fa-3x text-success mb-3'
                : 'fas fa-sign-out-alt fa-3x text-primary mb-3';
        }
        if (title) title.textContent = action === 'check_in' ? 'CHECKED IN' : 'CHECKED OUT';
        if (name) name.textContent = studentName;
    }

    startRFIDScanCooldown() {
        if (!this.rfidScannerState) return;
        this.rfidScannerState.isScanCooldown = true;
        this.rfidScannerState.cooldownSeconds = this.rfidScannerState.cooldownSeconds || 2;
        
        const cooldownSpan = document.getElementById('rfidCooldownSeconds');
        if (cooldownSpan) cooldownSpan.textContent = this.rfidScannerState.cooldownSeconds;
        
        this.rfidScannerState.cooldownTimer = setInterval(() => {
            this.rfidScannerState.cooldownSeconds--;
            
            if (cooldownSpan) cooldownSpan.textContent = this.rfidScannerState.cooldownSeconds;
            
            if (this.rfidScannerState.cooldownSeconds <= 0) {
                clearInterval(this.rfidScannerState.cooldownTimer);
                this.rfidScannerState.cooldownTimer = null;
                this.rfidScannerState.isScanCooldown = false;
                this.rfidScannerState.cooldownSeconds = 2;
                this.rfidScannerState.showingSuccessMessage = false;
                
                const overlay = document.getElementById('rfidSuccessMessageOverlay');
                if (overlay) overlay.style.display = 'none';
            }
        }, 1000);
    }

    cleanupRecentlyScannedRFIDTags() {
        if (this.rfidScannerState) {
            this.rfidScannerState.recentlyScannedTags.clear();
        }
    }

    toggleRFIDCheckoutMode(enabled) {
        if (!this.rfidScannerState) return;
        this.rfidScannerState.isCheckoutEnabled = enabled;
        this.rfidScannerState.recentlyScannedTags.clear();
        this.showNotification(enabled ? 'Checkout mode ENABLED' : 'Checkout mode DISABLED', enabled ? 'success' : 'info');
    }

    toggleRFIDOfflineMode(enabled) {
        if (!this.rfidScannerState) return;
        this.rfidScannerState.isOfflineMode = enabled;
        this.rfidScannerState.recentlyScannedTags.clear();
        this.showNotification(enabled ? 'Offline mode ENABLED' : 'Offline mode DISABLED', enabled ? 'success' : 'info');
    }

    onRFIDEventSelectionChange() {
        const selectedEvent = document.getElementById('rfidScannerEventSelect').value;
        if (this.rfidScannerState && selectedEvent) {
            this.rfidScannerState.selectedEvent = selectedEvent;
            this.rfidScannerState.recentlyScannedTags.clear();
        }
    }

    async handleRFIDManualEntry(e) {
        e.preventDefault();
        
        const studentId = document.getElementById('rfidManualStudentId').value.trim();
        const eventId = document.getElementById('rfidManualEventSelect').value;
        
        if (!studentId || !eventId) {
            this.showNotification('Please fill in all fields', 'warning');
            return;
        }
        
        // Create QR code data
        const payload = JSON.stringify({ studentId: studentId });
        const qrCodeData = btoa(payload);
        
        await this.markAttendanceFromRFID(eventId, studentId, qrCodeData);
        
        // Clear form
        document.getElementById('rfidManualStudentId').value = '';
    }

    updateRFIDScannerUI() {
        const statusBadge = document.getElementById('rfidScannerStatus');
        const toggleBtn = document.getElementById('toggleRFIDScannerBtn');
        
        const isActive = this.rfidScannerState && this.rfidScannerState.isActive;
        
        if (statusBadge) {
            statusBadge.textContent = isActive ? 'Active' : 'Inactive';
            statusBadge.className = isActive ? 'badge bg-success me-2' : 'badge bg-secondary me-2';
        }
        
        if (toggleBtn) {
            toggleBtn.innerHTML = isActive 
                ? '<i class="fas fa-stop"></i> Stop Scanner'
                : '<i class="fas fa-play"></i> Start Scanner';
            toggleBtn.className = isActive 
                ? 'btn btn-sm btn-outline-danger'
                : 'btn btn-sm btn-outline-primary';
        }
    }
}

// Initialize the dashboard when the page loads
console.log('📄 DOM Content Loaded event fired');
document.addEventListener('DOMContentLoaded', () => {
    console.log('🎯 Creating AdminDashboard instance...');
    window.adminDashboard = new AdminDashboard();
    console.log('✅ AdminDashboard instance created and assigned to window.adminDashboard');
});

// Global test function
window.testSettings = function() {
    console.log('🧪 Testing settings functionality...');
    if (window.adminDashboard) {
        console.log('✅ AdminDashboard instance found');
        window.adminDashboard.initSettings();
    } else {
        console.error('❌ AdminDashboard instance not found');
    }
}; 