'use client';

import { useState, useEffect, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import {
  Users,
  ShieldCheck,
  ShieldAlert,
  Map as MapIcon,
  MapPin,
  LogOut,
  Search,
  AlertTriangle,
  Activity,
  Bell,
  BarChart3,
  Settings,
  Globe,
  Target,
  CheckCircle2,
  XCircle,
  HelpCircle,
  ChevronDown,
  Loader2,
  Phone,
  Droplets,
  Flame,
  Wind,
  Mountain,
  Landmark,
  Zap,
  UserPlus,
  Building2,
  Home,
  HeartPulse,
  GraduationCap,
  Church
} from 'lucide-react';
import dynamic from 'next/dynamic';
import ThemeToggle from '../../components/ThemeToggle';

// Dynamically import map to avoid SSR issues
const BarangayMap = dynamic(() => import('./BarangayMap'), {
  ssr: false,
  loading: () => <div className="h-full w-full bg-zinc-100 animate-pulse rounded-3xl" />
});

const AnalyticsDashboard = dynamic(() => import('./AnalyticsDashboard'), {
  ssr: false,
  loading: () => <div className="flex flex-col items-center justify-center py-20 gap-4 opacity-50">
    <Loader2 className="animate-spin text-zinc-400" size={32} />
    <p className="text-[10px] font-black uppercase tracking-[0.3em]">ANALYZING JURISDICTION DATA...</p>
  </div>
});

interface Resident {
  id: string;
  firstName: string;
  lastName: string;
  middleName?: string | null;
  latitude: number | null;
  longitude: number | null;
  isSafe: boolean;
  hasResponded: boolean;
  role: string;
  safetyUpdatedAt?: string | null;
  updatedAt?: string | null;
  evacuationCenterId?: string | null;
  evacuationCenterName?: string | null;
}

interface Disaster {
  id: string;
  type: string;
  description: string | null;
  isActive: boolean;
  barangay: string;
}

interface EvacuationCenter {
  id: string;
  name: string;
  barangay: string;
  latitude: number;
  longitude: number;
  capacity: number | null;
  _count?: {
    evacuees: number;
  };
}

interface Evacuee {
  id: string;
  firstName: string;
  lastName: string;
  middleName?: string | null;
  gender?: string | null;
  age?: number | null;
  medicalNotes?: string | null;
  createdAt: string;
}

export default function BarangayHeadDashboard() {
  const [user, setUser] = useState<any>(null);
  const [activeDisaster, setActiveDisaster] = useState<Disaster | null>(null);
  const [residents, setResidents] = useState<Resident[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'safe' | 'missing'>('all');
  const [isActivating, setIsActivating] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [disasterType, setDisasterType] = useState('General Emergency');
  const [disasterDesc, setDisasterDesc] = useState('');
  const [focusResident, setFocusResident] = useState<Resident | null>(null);
  const [activeTab, setActiveTab] = useState<'dashboard' | 'analytics' | 'residents'>('dashboard');
  const [hqLocation, setHqLocation] = useState<{ lat: number, lng: number } | null>(null);
  const [isSettingLocation, setIsSettingLocation] = useState(false);
  const [showIncidentLog, setShowIncidentLog] = useState(false);

  // Evacuation States
  const [evacuationCenters, setEvacuationCenters] = useState<EvacuationCenter[]>([]);
  const [isSettingEC, setIsSettingEC] = useState(false);
  const [showECManager, setShowECManager] = useState(false);
  const [selectedEC, setSelectedEC] = useState<EvacuationCenter | null>(null);
  const [showRegisterEvacuee, setShowRegisterEvacuee] = useState(false);
  const [ecName, setEcName] = useState('');
  const [ecCapacity, setEcCapacity] = useState('');
  const [evacuees, setEvacuees] = useState<Evacuee[]>([]);
  const [selectedEcIcon, setSelectedEcIcon] = useState('Landmark');
  const [ecPosition, setEcPosition] = useState<{ lat: number, lng: number } | null>(null);

  const router = useRouter();

  // Auth & Initial Load
  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (!savedUser) {
      router.push('/login');
      return;
    }
    const parsed = JSON.parse(savedUser);
    if (parsed.role !== 'barangay_head') {
      router.push('/');
      return;
    }
    setUser(parsed);
    fetchData(parsed.barangay);

    // Load HQ Location from database
    fetch(`/api/barangay/location?name=${parsed.barangay}`)
      .then(res => res.json())
      .then(data => {
        if (data.profile) setHqLocation({ lat: data.profile.hqLatitude, lng: data.profile.hqLongitude });
      })
      .catch(err => console.error('Error fetching HQ location:', err));

    // Load Evacuation Centers
    fetchEvacuationCenters(parsed.barangay);
  }, []);

  const fetchEvacuationCenters = async (barangay: string) => {
    try {
      const res = await fetch(`/api/evacuation-center?barangay=${barangay}`);
      const data = await res.json();
      setEvacuationCenters(data.centers || []);
    } catch (err) {
      console.error('Error fetching ECs:', err);
    }
  };

  const fetchEvacuees = async (ecId: string) => {
    try {
      const res = await fetch(`/api/evacuation-center/residents?evacuationCenterId=${ecId}`);
      const data = await res.json();
      setEvacuees(data.evacuees || []);
    } catch (err) {
      console.error('Error fetching evacuees:', err);
    }
  };

  const handleMapClick = async (lat: number, lng: number) => {
    if (isSettingLocation) {
      const loc = { lat, lng };
      setHqLocation(loc);

      try {
        await fetch('/api/barangay/location', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: user.barangay,
            hqLatitude: lat,
            hqLongitude: lng,
          }),
        });
      } catch (err) {
        console.error('Error saving HQ location:', err);
      }

      setIsSettingLocation(false);
    } else if (isSettingEC) {
      setEcPosition({ lat, lng });
      setIsSettingEC(false);
      setShowECManager(true);
    }
  };

  const fetchData = async (barangay: string) => {
    setLoading(true);
    try {
      // 1. Check for active disaster
      const dRes = await fetch(`/api/disaster?barangay=${barangay}`);
      const dData = await dRes.json();
      const activeD = dData.disaster;
      setActiveDisaster(activeD);

      // 2. Fetch residents
      const rRes = await fetch(`/api/barangay/residents?barangay=${barangay}${activeD ? `&disasterId=${activeD.id}` : ''}`);
      const rData = await rRes.json();
      setResidents(rData.residents || []);

      // 3. Connect SSE for real-time updates
      connectSSE(barangay);
    } catch (err) {
      setError('Failed to initialize dashboard data');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const connectSSE = (barangay: string) => {
    // SSE for Disaster status
    const disasterSource = new EventSource(`/api/disaster/events?barangay=${barangay}`);
    disasterSource.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.isActive) {
        setActiveDisaster(data.disaster);
      } else {
        setActiveDisaster(null);
      }
    };

    // SSE for Residents safety updates
    const residentsSource = new EventSource(`/api/barangay/residents/events?barangay=${barangay}`);
    residentsSource.onmessage = (event) => {
      const updatedResident = JSON.parse(event.data);
      setResidents(prev => prev.map(r => r.id === updatedResident.id ? { ...r, ...updatedResident } : r));
    };

    return () => {
      disasterSource.close();
      residentsSource.close();
    };
  };

  const handleToggleDisaster = async () => {
    if (!user) return;
    setIsActivating(true);
    try {
      const res = await fetch('/api/disaster', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          headId: user.id,
          barangay: user.barangay,
          isActive: !activeDisaster,
          type: disasterType,
          description: disasterDesc,
        }),
      });

      if (res.ok) {
        setDisasterDesc('');
        setShowModal(false);
        // Data will be updated via SSE, but we can re-fetch for safety or rely on SSE
      }
    } catch (err) {
      console.error(err);
    } finally {
      setIsActivating(false);
    }
  };

  const handleDeleteUser = async (id: string) => {
    if (!confirm('Are you sure you want to delete this account? This action cannot be undone.')) return;

    try {
      const res = await fetch(`/api/profile?id=${id}`, {
        method: 'DELETE',
      });
      if (res.ok) {
        setResidents(prev => prev.filter(r => r.id !== id));
      } else {
        const data = await res.json();
        alert(data.message || 'Deletion failed');
      }
    } catch (err) {
      console.error(err);
      alert('Server error while deleting user');
    }
  };

  const filteredResidents = useMemo(() => {
    return residents.filter(r => {
      const matchesSearch = `${r.firstName} ${r.lastName}`.toLowerCase().includes(search.toLowerCase());
      const matchesFilter = filter === 'all' || (filter === 'safe' ? r.isSafe : !r.isSafe);
      return matchesSearch && matchesFilter;
    });
  }, [residents, search, filter]);

  const stats = useMemo(() => ({
    total: residents.length,
    safe: residents.filter(r => r.isSafe).length,
    missing: residents.filter(r => r.hasResponded === false || r.isSafe === false).length,
    responded: residents.filter(r => r.hasResponded).length,
    responders: residents.filter(r => r.role === 'responder').length,
  }), [residents]);

  if (loading) return (
    <div className="h-screen w-screen bg-white dark:bg-black flex flex-col items-center justify-center gap-4">
      <div className="h-16 w-16 rounded-2xl bg-red-600 flex items-center justify-center animate-bounce shadow-2xl shadow-red-600/30">
        <span className="text-white font-black italic tracking-tighter text-2xl">RQ</span>
      </div>
      <div className="flex flex-col items-center text-zinc-400">
        <Loader2 className="animate-spin mb-2" />
        <p className="text-[10px] font-black uppercase tracking-[0.3em]">INITIALIZING COMMAND CENTER</p>
      </div>
    </div>
  );

  const isActive = !!activeDisaster;
  const primaryTheme = isActive ? 'text-red-600 bg-red-600/10' : 'text-emerald-600 bg-emerald-600/10';
  const borderTheme = isActive ? 'border-red-600/20' : 'border-emerald-600/20';

  return (
    <div className="flex min-h-screen bg-zinc-50 dark:bg-black font-sans antialiased text-zinc-900 dark:text-zinc-50 selection:bg-red-600 selection:text-white">
      {/* Sidebar Navigation */}
      <aside className="w-20 lg:w-72 border-r border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 flex flex-col z-50">
        <div className="p-6 lg:p-8">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 min-w-10 rounded-xl bg-red-600 flex items-center justify-center shadow-lg shadow-red-600/20 rotate-3 transition-transform hover:rotate-0">
              <span className="text-white font-black italic tracking-tighter text-sm">RQ</span>
            </div>
            <div className="hidden lg:block">
              <h1 className="text-lg font-black tracking-tighter uppercase leading-none">RISKQ<span className="text-red-600">PH</span></h1>
              <p className="text-[8px] font-black tracking-[0.3em] uppercase opacity-40">COMMUNITY MONITOR</p>
            </div>
          </div>
        </div>

        <nav className="flex-1 px-4 lg:px-6 space-y-2 py-4">
          {[
            { id: 'dashboard', label: 'Dashboard', icon: Activity },
            { id: 'residents', label: 'Residents', icon: Users },
            { id: 'analytics', label: 'Analytics', icon: BarChart3 },
          ].map((item) => (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id as any)}
              className={`w-full flex items-center gap-4 px-4 py-3 rounded-2xl transition-all duration-300 group ${activeTab === item.id
                ? 'bg-zinc-900 text-white dark:bg-white dark:text-black shadow-xl shadow-zinc-900/10'
                : 'text-zinc-500 hover:bg-zinc-100 dark:hover:bg-zinc-900'
                }`}
            >
              <item.icon size={20} strokeWidth={2.5} className={activeTab === item.id ? 'scale-110' : 'group-hover:scale-110 transition-transform'} />
              <span className="hidden lg:block text-xs font-black uppercase tracking-wider">{item.label}</span>
            </button>
          ))}

          <div className="pt-4 mt-4 border-t border-zinc-100 dark:border-zinc-900 space-y-2">
            <button
              onClick={() => router.push('/barangay-head/add-user')}
              className="w-full flex items-center gap-4 px-4 py-3 rounded-2xl transition-all duration-300 group text-zinc-400 hover:text-red-600 hover:bg-red-600/5 dark:hover:bg-red-600/10"
            >
              <UserPlus size={20} strokeWidth={2.5} className="group-hover:scale-110 transition-transform" />
              <span className="hidden lg:block text-xs font-black uppercase tracking-wider">Add Account</span>
            </button>
            <button
              onClick={() => router.push('/barangay-head/admin-add-user')}
              className="w-full flex items-center gap-4 px-4 py-3 rounded-2xl transition-all duration-300 group text-zinc-400 hover:text-red-600 hover:bg-red-600/5 dark:hover:bg-red-600/10"
            >
              <ShieldAlert size={20} strokeWidth={2.5} className="group-hover:scale-110 transition-transform" />
              <span className="hidden lg:block text-xs font-black uppercase tracking-wider">Admin Protocol</span>
            </button>
            <button
              onClick={() => setShowECManager(true)}
              className="w-full flex items-center gap-4 px-4 py-3 rounded-2xl transition-all duration-300 group text-zinc-400 hover:text-emerald-600 hover:bg-emerald-600/5 dark:hover:bg-emerald-600/10"
            >
              <Landmark size={20} strokeWidth={2.5} className="group-hover:scale-110 transition-transform" />
              <span className="hidden lg:block text-xs font-black uppercase tracking-wider">Evacuation</span>
            </button>
          </div>
        </nav>

        <div className="p-6 border-t border-zinc-200 dark:border-zinc-800 space-y-4">
          <div className="hidden lg:block p-4 rounded-3xl bg-zinc-100 dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800">
            <div className="flex items-center gap-3 mb-3">
              <div className="w-8 h-8 rounded-full bg-zinc-300 dark:bg-zinc-800 flex items-center justify-center text-xs font-black uppercase">
                {user?.firstName?.charAt(0)}{user?.lastName?.charAt(0)}
              </div>
              <div className="min-w-0">
                <p className="text-[10px] font-black uppercase truncate">{user?.firstName} {user?.lastName}</p>
                <p className="text-[8px] font-bold text-zinc-500 uppercase tracking-widest">BRGY. {user?.barangay} HEAD</p>
              </div>
            </div>
            <button
              onClick={() => {
                localStorage.removeItem('user');
                router.push('/login');
              }}
              className="w-full h-10 rounded-2xl bg-white dark:bg-zinc-800 text-red-600 text-[10px] font-black uppercase tracking-widest hover:bg-red-600 hover:text-white transition-all shadow-sm flex items-center justify-center gap-2"
            >
              <LogOut size={12} strokeWidth={3} />
              Sign Out
            </button>
          </div>
          <button
            onClick={() => {
              localStorage.removeItem('user');
              router.push('/login');
            }}
            className="lg:hidden w-full flex items-center justify-center p-3 text-red-600 hover:bg-red-50 rounded-2xl transition-colors"
          >
            <LogOut size={24} />
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 overflow-y-auto h-screen relative">
        {/* Top Header Stat Banner */}
        <header className="sticky top-0 z-40 w-full bg-zinc-50/80 dark:bg-black/80 backdrop-blur-md border-b border-zinc-200 dark:border-zinc-800 p-6 lg:px-12 flex flex-col md:flex-row justify-between items-center gap-6">
          <div className="flex flex-col">
            <h2 className="text-2xl font-black tracking-tight uppercase leading-none mb-1">
              {activeTab === 'dashboard' ? 'Barangay Dashboard' : activeTab === 'residents' ? 'Resident List' : 'Jurisdiction Analytics'}
            </h2>
            <div className="flex items-center gap-2 text-zinc-400">
              <MapPin size={10} className="text-red-600" />
              <p className="text-[9px] font-black uppercase tracking-[0.25em]">Barangay Jurisdiction: <span className="text-zinc-600 dark:text-zinc-300">{user?.barangay}</span></p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <ThemeToggle />
            <div className={`p-4 lg:px-6 lg:py-4 rounded-[2rem] border ${borderTheme} ${primaryTheme} transition-all duration-700 flex items-center gap-4 shadow-sm`}>
              <div className="flex flex-col">
                <p className="text-[8px] font-black uppercase tracking-[0.2em] opacity-60">Barangay Status</p>
                <p className="text-xs font-black uppercase tracking-widest">{isActive ? 'EMERGENCY ACTIVE' : 'SYSTEM STATUS SAFE'}</p>
              </div>
              <div className={`w-3 h-3 rounded-full ${isActive ? 'bg-red-600 animate-pulse' : 'bg-emerald-600'}`}></div>
            </div>
            <button className="h-14 w-1 flex md:hidden"></button> {/* Spacer */}
          </div>
        </header>

        <div className="p-6 lg:p-12 space-y-12">
          {activeTab === 'dashboard' && (
            <>
              {/* Quick Action & Stats Grid */}
              <section className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
                {/* Panic Toggle Card */}
                <div className={`lg:col-span-12 rounded-[3rem] p-8 lg:p-12 border ${borderTheme} bg-white dark:bg-zinc-950 overflow-hidden relative shadow-2xl`}>
                  <div className="absolute top-0 right-0 p-12 opacity-[0.03] select-none pointer-events-none">
                    <Activity size={300} strokeWidth={1} />
                  </div>

                  <div className="relative z-10 grid grid-cols-1 md:grid-cols-5 gap-8 items-center">
                    <div className="md:col-span-3 space-y-6">
                      <div className={`h-12 w-12 rounded-2xl flex items-center justify-center shadow-lg transition-all duration-700 ${isActive ? 'bg-red-600 text-white animate-pulse rotate-6' : 'bg-emerald-600 text-white'}`}>
                        {isActive ? <ShieldAlert size={28} strokeWidth={2.5} /> : <ShieldCheck size={28} strokeWidth={2.5} />}
                      </div>
                      <div>
                        <h3 className="text-3xl lg:text-5xl font-black tracking-tighter uppercase leading-none mb-4">
                          {isActive ? <>CEASE ALL <span className="text-red-600 italic">NON-CRITICAL</span> OPERATIONS</> : <>ALL CITIZENS <span className="text-emerald-600">CONFIRMED SAFE</span></>}
                        </h3>
                        <p className="text-zinc-500 dark:text-zinc-400 text-xs lg:text-sm font-bold max-w-lg leading-relaxed uppercase tracking-wider">
                          {isActive
                            ? `COMMENCING EVACUATION PROTOCOLS FOR BRGY. ${user?.barangay}. ${activeDisaster.type}: ${activeDisaster.description || 'Active hazard monitoring engaged.'}`
                            : `SYSTEM MONITORING ACTIVE IN BRGY. ${user?.barangay}. No active hazards detected within jurisdictional boundaries.`}
                        </p>
                      </div>

                      <div className="flex flex-wrap gap-4 pt-4">
                        <button
                          onClick={() => isActive ? handleToggleDisaster() : setShowModal(true)}
                          disabled={isActivating}
                          className={`min-w-[240px] h-16 rounded-[1.5rem] font-black uppercase tracking-[0.2em] text-[10px] items-center justify-center gap-3 transition-all duration-500 flex shadow-lg hover:shadow-2xl active:scale-95 ${isActive
                            ? 'bg-zinc-900 text-white hover:bg-black dark:bg-white dark:text-black dark:hover:bg-zinc-200'
                            : 'bg-red-600 text-white hover:bg-red-700 shadow-red-600/30'
                            }`}
                        >
                          {isActivating ? (
                            <Loader2 className="animate-spin" size={18} />
                          ) : (
                            <>
                              {isActive ? 'DEACTIVATE EMERGENCY PROTOCOL' : 'ACTIVATE DISASTER MODE'}
                              <Zap size={14} fill="currentColor" />
                            </>
                          )}
                        </button>

                        {isActive && (
                          <button className="px-10 h-16 rounded-[1.5rem] border border-red-600 text-red-600 font-black uppercase tracking-[0.2em] text-[10px] hover:bg-red-600 hover:text-white transition-all duration-300">
                            Send Mass Notification
                          </button>
                        )}
                      </div>
                    </div>

                    <div className="md:col-span-2 grid grid-cols-2 gap-4">
                      <div className="bg-zinc-100 dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 p-6 rounded-[2rem] flex flex-col justify-center">
                        <p className="text-[10px] font-black tracking-widest text-zinc-500 uppercase mb-2">Total Citizens</p>
                        <p className="text-4xl font-black tracking-tighter">{stats.total}</p>
                      </div>
                      <div className={`p-6 rounded-[2rem] border transition-all duration-700 ${isActive ? 'bg-red-600 border-red-700 text-white shadow-xl shadow-red-600/10' : 'bg-emerald-600 border-emerald-700 text-white'}`}>
                        <p className="text-[10px] font-black tracking-widest opacity-60 uppercase mb-2">{isActive ? 'MISSING' : 'SAFE'}</p>
                        <p className="text-4xl font-black tracking-tighter">{isActive ? stats.missing : stats.safe}</p>
                      </div>
                      <div className="bg-zinc-100 dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 p-6 rounded-[2rem] flex flex-col justify-center">
                        <p className="text-[10px] font-black tracking-widest text-zinc-500 uppercase mb-2">Responders</p>
                        <p className="text-4xl font-black tracking-tighter">{stats.responders}</p>
                      </div>
                      <div className="bg-zinc-100 dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 p-6 rounded-[2rem] flex flex-col justify-center">
                        <p className="text-[10px] font-black tracking-widest text-zinc-500 uppercase mb-2">Evacuation Centers</p>
                        <p className="text-4xl font-black tracking-tighter">{evacuationCenters.length}</p>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Map Area */}
                <div className="lg:col-span-12 space-y-6">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <MapIcon className="text-red-600" size={24} />
                      <h3 className="text-sm font-black uppercase tracking-widest">Map</h3>
                    </div>
                    <div className="flex items-center gap-4">
                      {isSettingLocation || isSettingEC ? (
                        <div className={`flex items-center gap-3 px-4 py-2 rounded-2xl animate-pulse ${isSettingEC ? 'bg-emerald-600' : 'bg-red-600'}`}>
                          <MapPin size={14} className="text-white" />
                          <p className="text-[10px] font-black uppercase text-white tracking-widest">
                            {isSettingLocation ? 'ClICK ON MAP TO SET HQ...' : `ClICK TO ESTABLISH: ${ecName || 'SAFE ZONE'}`}
                          </p>
                        </div>
                      ) : (
                        <div className="flex gap-2">
                          <button
                            onClick={() => setIsSettingLocation(!isSettingLocation)}
                            className={`h-10 px-6 rounded-xl border font-black uppercase tracking-widest text-[9px] transition-all border-zinc-200 text-zinc-500 hover:border-zinc-900 hover:text-zinc-900`}
                          >
                            SET BARANGAY HALL
                          </button>
                          <button
                            onClick={() => setIsSettingEC(true)}
                            className="h-10 px-6 rounded-xl bg-emerald-600 text-white font-black uppercase tracking-widest text-[9px] hover:bg-emerald-700 transition-all flex items-center gap-2"
                          >
                            <Landmark size={12} />
                            SET EVACUATION CENTER
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                  <div className={`h-[700px] shadow-2xl relative transition-all overflow-hidden rounded-[3rem] border border-zinc-200 dark:border-zinc-800 ${(isSettingLocation || isSettingEC) ? 'ring-8 ring-emerald-600/20' : ''}`}>
                    <BarangayMap
                      residents={filteredResidents}
                      isActive={isActive}
                      focusResident={focusResident}
                      hqLocation={hqLocation}
                      onMapClick={handleMapClick}
                      barangayName={user?.barangay}
                      evacuationCenters={evacuationCenters}
                      onSelectEvacuationCenter={(ec) => {
                        setSelectedEC(ec);
                        fetchEvacuees(ec.id);
                        setShowRegisterEvacuee(true);
                      }}
                    />

                    {/* Incident Log Floating Panel */}
                    {showIncidentLog && (
                      <div className="absolute top-24 right-6 z-[1005] w-96 max-h-[500px] flex flex-col bg-white/95 dark:bg-zinc-950/95 backdrop-blur-2xl rounded-[2.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl animate-in slide-in-from-top-4 fade-in duration-300">
                        <div className="p-6 border-b border-zinc-200 dark:border-zinc-800 flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <Activity className="text-red-600" size={18} />
                            <h4 className="text-[11px] font-black uppercase tracking-widest">LIVE INCIDENT STREAM</h4>
                          </div>
                          <span className="flex h-2 w-2 rounded-full bg-red-600 animate-pulse"></span>
                        </div>

                        <div className="p-6 flex-1 overflow-y-auto space-y-4">
                          {isActive ? (
                            residents.filter(r => !r.isSafe).length > 0 ? (
                              residents.filter(r => !r.isSafe).map((r, i) => (
                                <div
                                  key={i}
                                  onClick={() => {
                                    setFocusResident(r);
                                    setShowIncidentLog(false);
                                  }}
                                  className="p-4 rounded-2xl border border-red-600/10 bg-red-600/5 hover:bg-red-600/10 transition-all cursor-pointer group"
                                >
                                  <div className="flex items-center justify-between mb-2">
                                    <p className="text-[9px] font-black uppercase text-red-600">Priority Tracker</p>
                                    <Target size={12} className="text-red-600 opacity-0 group-hover:opacity-100 transition-opacity" />
                                  </div>
                                  <p className="text-[11px] font-black uppercase">{r.firstName} {r.lastName}</p>
                                  <p className="text-[8px] font-bold text-zinc-500 uppercase tracking-widest mt-1">LAT: {r.latitude?.toFixed(4)} | LNG: {r.longitude?.toFixed(4)}</p>
                                </div>
                              ))
                            ) : (
                              <div className="py-12 flex flex-col items-center justify-center opacity-40 text-center">
                                <ShieldCheck size={48} strokeWidth={1} className="mb-3" />
                                <p className="text-[9px] font-black uppercase">No recent activity</p>
                              </div>
                            )
                          ) : (
                            <div className="py-12 flex flex-col items-center justify-center opacity-40 text-center">
                              <ShieldCheck size={48} strokeWidth={1} className="mb-3" />
                              <p className="text-[9px] font-black uppercase">No Active Threats</p>
                            </div>
                          )}
                        </div>

                        <div className="p-6 border-t border-zinc-200 dark:border-zinc-800">
                          <button className="w-full h-12 rounded-xl bg-zinc-900 dark:bg-white text-white dark:text-black text-[9px] font-black uppercase tracking-widest hover:opacity-90 transition-all">
                            Open Archive Terminal
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </section>
            </>
          )}

          {activeTab === 'residents' && (
            <div className="animate-in fade-in slide-in-from-bottom-4 duration-700">
              {/* Citizen Monitor Table Section */}
              <section className="space-y-8">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
                  <div className="flex items-center gap-4">
                    <div className="p-3 bg-white dark:bg-zinc-900 rounded-2xl shadow-sm border border-zinc-200 dark:border-zinc-800">
                      <Users className="text-red-600" size={24} />
                    </div>
                    <div>
                      <h3 className="text-2xl font-black tracking-tight uppercase">Citizen Directory</h3>
                      <p className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Manage all registered households in your jurisdiction</p>
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-4">
                    <button
                      onClick={() => router.push('/barangay-head/add-user')}
                      className="h-12 px-8 rounded-2xl bg-zinc-900 dark:bg-white text-white dark:text-black text-[10px] font-black uppercase tracking-widest hover:bg-red-600 dark:hover:bg-red-600 hover:text-white transition-all flex items-center gap-3 shadow-xl shadow-zinc-900/10"
                    >
                      <UserPlus size={18} />
                      Add User
                    </button>
                    <div className="relative group">
                      <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-400 group-focus-within:text-red-600 transition-colors" size={16} />
                      <input
                        type="text"
                        placeholder="FIND CITIZEN..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="h-12 w-64 pl-12 pr-4 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-black text-[10px] font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 shadow-sm"
                      />
                    </div>
                    <div className="flex p-1 bg-zinc-200 dark:bg-zinc-900 rounded-2xl border border-zinc-200 dark:border-zinc-800">
                      {['all', 'safe', 'missing'].map((f) => (
                        <button
                          key={f}
                          onClick={() => setFilter(f as any)}
                          className={`px-6 h-10 rounded-xl text-[9px] font-black uppercase tracking-widest transition-all ${filter === f
                            ? 'bg-white dark:bg-zinc-800 text-red-600 shadow-sm shadow-zinc-900/5'
                            : 'text-zinc-500 hover:text-zinc-900'
                            }`}
                        >
                          {f}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="bg-white dark:bg-zinc-950 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 overflow-hidden shadow-2xl">
                  <div className="overflow-x-auto">
                    <table className="w-full text-left">
                      <thead>
                        <tr className="border-b border-zinc-200 dark:border-zinc-800">
                          <th className="px-8 py-6 text-[10px] font-black uppercase tracking-widest text-zinc-400">Citizen Name</th>
                          <th className="px-8 py-6 text-[10px] font-black uppercase tracking-widest text-zinc-400">Account Type</th>
                          <th className="px-8 py-6 text-[10px] font-black uppercase tracking-widest text-zinc-400">Current Status</th>
                          <th className="px-8 py-6 text-[10px] font-black uppercase tracking-widest text-zinc-400">Last Update</th>
                          <th className="px-8 py-6 text-[10px] font-black uppercase tracking-widest text-zinc-400 text-right">Actions</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-zinc-200 dark:divide-zinc-800">
                        {filteredResidents.length === 0 ? (
                          <tr>
                            <td colSpan={5} className="px-8 py-20 text-center opacity-30 uppercase font-black text-xs space-y-4">
                              <HelpCircle className="mx-auto" size={48} strokeWidth={1} />
                              <p>No citizens matching your search parameters.</p>
                            </td>
                          </tr>
                        ) : (
                          filteredResidents.map((r) => (
                            <tr key={r.id} className="group hover:bg-zinc-50 dark:hover:bg-zinc-900/50 transition-colors">
                              <td className="px-8 py-6">
                                <div className="flex items-center gap-4">
                                  <div className="w-10 h-10 rounded-xl bg-zinc-100 dark:bg-zinc-900 flex items-center justify-center text-xs font-black uppercase text-zinc-400 group-hover:bg-white group-hover:text-red-600 transition-colors">
                                    {r.firstName.charAt(0)}{r.lastName.charAt(0)}
                                  </div>
                                  <div>
                                    <p className="text-xs font-black uppercase">{r.firstName} {r.lastName}</p>
                                    <p className="text-[9px] font-medium text-zinc-500 uppercase tracking-widest">Resident ID: {r.id.slice(-8).toUpperCase()}</p>
                                  </div>
                                </div>
                              </td>
                              <td className="px-8 py-6">
                                <div className={`inline-flex items-center gap-2 px-3 py-1 rounded-lg text-[9px] font-black uppercase tracking-widest ${r.role === 'responder' ? 'bg-cyan-50 text-cyan-600 border border-cyan-100' : 'bg-zinc-100 text-zinc-500 border border-zinc-200'
                                  }`}>
                                  {r.role}
                                </div>
                              </td>
                              <td className="px-8 py-6">
                                <div className={`inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-[9px] font-black uppercase tracking-widest border ${isActive
                                  ? (r.isSafe ? 'bg-emerald-50 text-emerald-600 border-emerald-100' : 'bg-red-50 text-red-600 border-red-100')
                                  : 'bg-zinc-100 text-zinc-500 border-zinc-200'
                                  }`}>
                                  {isActive ? (
                                    <>
                                      {r.isSafe ? <ShieldCheck size={12} fill="currentColor" /> : <ShieldAlert size={12} fill="currentColor" />}
                                      {r.isSafe ? 'Marked Safe' : 'PENDING'}
                                    </>
                                  ) : (
                                    <>
                                      <Activity size={12} fill="currentColor" />
                                      Monitoring
                                    </>
                                  )}
                                </div>
                              </td>
                              <td className="px-8 py-6 text-[10px] font-bold text-zinc-500">
                                {r.safetyUpdatedAt ? new Date(r.safetyUpdatedAt).toLocaleString() : 'N/A'}
                              </td>
                              <td className="px-8 py-6 text-right flex items-center justify-end gap-2">
                                <button
                                  onClick={() => router.push(`/barangay-head/edit-user/${r.id}`)}
                                  className="h-10 px-4 rounded-xl bg-zinc-900 dark:bg-white text-white dark:text-black text-[9px] font-black uppercase tracking-widest hover:bg-red-600 dark:hover:bg-red-600 hover:text-white transition-all shadow-lg shadow-zinc-900/5"
                                >
                                  Edit
                                </button>
                                <button
                                  onClick={() => handleDeleteUser(r.id)}
                                  className="h-10 w-10 flex items-center justify-center rounded-xl bg-red-600/10 text-red-600 hover:bg-red-600 hover:text-white transition-all shadow-sm"
                                >
                                  <ShieldAlert size={16} />
                                </button>
                                <button
                                  onClick={() => {
                                    setFocusResident(r);
                                    setActiveTab('dashboard');
                                    window.scrollTo({ top: 300, behavior: 'smooth' });
                                  }}
                                  className="h-10 px-4 rounded-xl border border-zinc-200 dark:border-zinc-800 text-[9px] font-black uppercase tracking-widest hover:bg-zinc-900 hover:text-white dark:hover:bg-white dark:hover:text-black transition-all"
                                >
                                  Radar
                                </button>
                              </td>
                            </tr>
                          ))
                        )}
                      </tbody>
                    </table>
                  </div>
                </div>
              </section>
            </div>
          )}

          {activeTab === 'analytics' && (
            <AnalyticsDashboard barangay={user?.barangay} />
          )}
        </div>
      </main>

      {/* Activation Modal */}
      {showModal && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-black/60 backdrop-blur-sm animate-in fade-in duration-300">
          <div className="w-full max-w-lg bg-white dark:bg-zinc-950 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl overflow-hidden animate-in zoom-in-95 duration-300">
            <div className="p-8 lg:p-10">
              <header className="mb-8 flex items-center gap-4">
                <div className="h-12 w-12 rounded-2xl bg-red-600 flex items-center justify-center shadow-lg shadow-red-600/30">
                  <ShieldAlert size={28} color="white" strokeWidth={2.5} />
                </div>
                <div>
                  <h3 className="text-xl font-black tracking-tight uppercase leading-none mb-1">Create Emergency Alert</h3>
                  <p className="text-[10px] font-black uppercase tracking-widest text-red-600">This will notify all residents</p>
                </div>
              </header>

              <div className="space-y-6">
                <div className="space-y-2">
                  <label className="text-[9px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-1">Emergency Category</label>
                  <div className="grid grid-cols-3 gap-3">
                    {[
                      { id: 'Flooding', icon: Droplets },
                      { id: 'Fire', icon: Flame },
                      { id: 'Typhoon', icon: Wind },
                      { id: 'Earthquake', icon: Activity },
                      { id: 'Landslide', icon: Mountain },
                      { id: 'General', icon: AlertTriangle },
                    ].map((cat) => (
                      <button
                        key={cat.id}
                        onClick={() => setDisasterType(cat.id)}
                        className={`p-4 rounded-2xl border transition-all flex flex-col items-center gap-2 ${disasterType === cat.id
                          ? 'bg-red-600 border-red-600 text-white shadow-xl shadow-red-600/20'
                          : 'bg-zinc-50 dark:bg-zinc-900 border-zinc-200 dark:border-zinc-800 text-zinc-500 hover:border-red-600/30'
                          }`}
                      >
                        <cat.icon size={20} />
                        <span className="text-[8px] font-black uppercase tracking-widest">{cat.id}</span>
                      </button>
                    ))}
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-[9px] font-black uppercase tracking-[0.2em] text-zinc-400 ml-1">Specific Instructions</label>
                  <textarea
                    placeholder="E.G. EVACUATE TO COVERED COURT IMMEDIATELY..."
                    value={disasterDesc}
                    onChange={(e) => setDisasterDesc(e.target.value)}
                    className="w-full h-32 p-6 rounded-3xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-bold focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all resize-none shadow-inner"
                  />
                </div>
              </div>

              <div className="mt-10 flex gap-4">
                <button
                  onClick={() => setShowModal(false)}
                  className="flex-1 h-14 rounded-2xl bg-zinc-100 dark:bg-zinc-900 text-zinc-500 font-black uppercase tracking-widest text-[10px] hover:text-zinc-900 transition-all"
                >
                  Cancel
                </button>
                <button
                  onClick={handleToggleDisaster}
                  disabled={isActivating}
                  className="flex-1 h-14 rounded-2xl bg-red-600 text-white font-black uppercase tracking-widest text-[10px] shadow-lg shadow-red-600/20 hover:bg-zinc-900 transition-all flex items-center justify-center gap-2"
                >
                  {isActivating ? <Loader2 className="animate-spin" /> : 'Confirm Alert'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Evacuation Center Manager Modal */}
      {showECManager && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-black/60 backdrop-blur-sm animate-in fade-in duration-300">
          <div className="w-full max-w-2xl bg-white dark:bg-zinc-950 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl overflow-hidden animate-in zoom-in-95 duration-300">
            <div className="p-8 lg:p-10">
              <header className="mb-8 flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="h-12 w-12 rounded-2xl bg-emerald-600 flex items-center justify-center shadow-lg shadow-emerald-600/30">
                    <Landmark size={28} color="white" strokeWidth={2.5} />
                  </div>
                  <div>
                    <h3 className="text-xl font-black tracking-tight uppercase leading-none mb-1">Evacuation Centers</h3>
                    <p className="text-[10px] font-black uppercase tracking-widest text-emerald-600">Manage jurisdictional safe zones</p>
                  </div>
                </div>
                <button
                  onClick={() => {
                    setShowECManager(false);
                    setEcPosition(null);
                  }}
                  className="p-2 hover:bg-zinc-100 dark:hover:bg-zinc-900 rounded-full transition-colors"
                >
                  <XCircle size={24} className="text-zinc-400" />
                </button>
              </header>

              <div className="space-y-6">
                <div className="p-6 bg-zinc-50 dark:bg-zinc-900 rounded-[2rem] border border-zinc-200 dark:border-zinc-800 space-y-4">
                  <h4 className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Add New Center</h4>
                  <div className="grid grid-cols-2 gap-4">
                    <input
                      placeholder="CENTER NAME (E.G. COVERED COURT)"
                      value={ecName}
                      onChange={(e) => setEcName(e.target.value)}
                      className="h-12 px-6 rounded-xl border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-black text-[10px] font-black uppercase focus:ring-2 focus:ring-emerald-600/20 outline-none"
                    />
                    <input
                      placeholder="MAX CAPACITY"
                      type="number"
                      value={ecCapacity}
                      onChange={(e) => setEcCapacity(e.target.value)}
                      className="h-12 px-6 rounded-xl border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-black text-[10px] font-black uppercase focus:ring-2 focus:ring-emerald-600/20 outline-none"
                    />
                  </div>
                  <div className="space-y-2">
                    <h5 className="text-[8px] font-black uppercase tracking-widest text-zinc-400 ml-1">Center Symbol</h5>
                    <div className="grid grid-cols-7 gap-2">
                      {[
                        { id: 'Landmark', icon: Landmark },
                        { id: 'Building', icon: Building2 },
                        { id: 'Home', icon: Home },
                        { id: 'Medical', icon: HeartPulse },
                        { id: 'School', icon: GraduationCap },
                        { id: 'Church', icon: Church },
                        { id: 'Activity', icon: Activity },
                      ].map((item) => (
                        <button
                          key={item.id}
                          onClick={() => setSelectedEcIcon(item.id)}
                          className={`aspect-square rounded-xl border transition-all flex items-center justify-center ${selectedEcIcon === item.id
                            ? 'bg-emerald-600 border-emerald-600 text-white shadow-lg'
                            : 'bg-white dark:bg-black border-zinc-200 dark:border-zinc-800 text-zinc-400 hover:border-emerald-600/50'
                            }`}
                          type="button"
                          title={item.id}
                        >
                          <item.icon size={18} />
                        </button>
                      ))}
                    </div>
                  </div>

                  {ecPosition ? (
                    <button
                      onClick={async () => {
                        if (!user?.barangay) return;
                        try {
                          const res = await fetch('/api/evacuation-center', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({
                              name: ecName || 'New Evacuation Center',
                              barangay: user.barangay,
                              latitude: ecPosition.lat,
                              longitude: ecPosition.lng,
                              capacity: ecCapacity,
                              type: selectedEcIcon,
                            }),
                          });
                          if (res.ok) {
                            fetchEvacuationCenters(user.barangay);
                            setEcName('');
                            setEcCapacity('');
                            setEcPosition(null);
                            setShowECManager(false);
                          }
                        } catch (err) {
                          console.error('Error saving EC:', err);
                        }
                      }}
                      className="w-full h-12 rounded-xl bg-emerald-600 text-white text-[10px] font-black uppercase tracking-widest hover:bg-emerald-700 transition-all flex items-center justify-center gap-2 shadow-lg shadow-emerald-600/20"
                    >
                      <CheckCircle2 size={14} />
                      Finalize Establishment
                    </button>
                  ) : (
                    <button
                      onClick={() => {
                        setIsSettingEC(true);
                        setShowECManager(false);
                      }}
                      className="w-full h-12 rounded-xl bg-zinc-900 dark:bg-white text-white dark:text-black text-[10px] font-black uppercase tracking-widest hover:bg-emerald-600 dark:hover:bg-emerald-600 hover:text-white transition-all flex items-center justify-center gap-2"
                    >
                      <MapPin size={14} />
                      Pick Location on Map
                    </button>
                  )}
                </div>

                <div className="space-y-3 max-h-[300px] overflow-y-auto pr-2">
                  {evacuationCenters.length === 0 ? (
                    <div className="py-10 text-center opacity-30 text-[10px] font-black uppercase">No centers established yet</div>
                  ) : (
                    evacuationCenters.map((ec) => (
                      <div key={ec.id} className="p-4 bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl flex items-center justify-between group hover:border-emerald-600/50 transition-all">
                        <div>
                          <p className="text-xs font-black uppercase">{ec.name}</p>
                          <p className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest">
                            Capacity: {ec._count?.evacuees || 0} / {ec.capacity || 'UNLIMITED'}
                          </p>
                        </div>
                        <div className="flex gap-2">
                          <button
                            onClick={() => {
                              setSelectedEC(ec);
                              fetchEvacuees(ec.id);
                              setShowRegisterEvacuee(true);
                              setShowECManager(false);
                            }}
                            className="h-8 px-4 rounded-lg bg-zinc-900 dark:bg-white text-white dark:text-black text-[8px] font-black uppercase hover:bg-emerald-600 dark:hover:bg-emerald-600 hover:text-white transition-all"
                          >
                            Registry
                          </button>
                          <button
                            onClick={async () => {
                              if (confirm('Delete this center?')) {
                                await fetch(`/api/evacuation-center?id=${ec.id}`, { method: 'DELETE' });
                                fetchEvacuationCenters(user.barangay);
                              }
                            }}
                            className="h-8 w-8 flex items-center justify-center rounded-lg bg-red-100 text-red-600 hover:bg-red-600 hover:text-white transition-all"
                          >
                            <XCircle size={14} />
                          </button>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Evacuee Registration Modal */}
      {showRegisterEvacuee && selectedEC && (
        <div className="fixed inset-0 z-[110] flex items-center justify-center p-6 bg-black/60 backdrop-blur-sm animate-in fade-in duration-300">
          <div className="w-full max-w-4xl bg-white dark:bg-zinc-950 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl overflow-hidden animate-in zoom-in-95 duration-300 flex h-[80vh]">
            {/* Left Side: QR-only notice */}
            <div className="w-1/2 p-8 lg:p-10 border-r border-zinc-100 dark:border-zinc-900 flex flex-col">
              <header className="mb-8">
                <div className="flex items-center gap-3 mb-2">
                  <Landmark className="text-emerald-600" size={18} />
                  <h3 className="text-lg font-black tracking-tight uppercase leading-none">{selectedEC.name}</h3>
                </div>
                <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Evacuee registry (QR only)</p>
              </header>

              <div className="flex-1 space-y-4 overflow-y-auto pr-2 text-[10px] text-zinc-600 dark:text-zinc-400 leading-relaxed">
                <p className="font-bold text-zinc-900 dark:text-zinc-100 uppercase tracking-wide text-[9px]">
                  Manual registration is disabled. Add evacuees using the RiskQPH mobile app:
                </p>
                <ul className="list-disc pl-4 space-y-2">
                  <li>Open <span className="font-black text-emerald-600">Evacuation centers</span> and tap the QR icon.</li>
                  <li>Choose this center, then scan each resident&apos;s personal QR.</li>
                  <li>Evacuation registration syncs across the app for all roles (map pin stays at the resident&apos;s own location).</li>
                </ul>
                <button
                  type="button"
                  onClick={() => setShowRegisterEvacuee(false)}
                  className="w-full h-12 rounded-xl bg-zinc-900 dark:bg-white text-white dark:text-black text-[10px] font-black uppercase tracking-widest hover:opacity-90 transition-all mt-4"
                >
                  Close
                </button>
              </div>
            </div>

            {/* Right Side: List */}
            <div className="w-1/2 bg-zinc-50 dark:bg-zinc-900 p-8 lg:p-10 flex flex-col">
              <header className="mb-8">
                <h4 className="text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-2">Current Occupants</h4>
                <div className="flex items-center gap-2">
                  <span className="text-2xl font-black text-emerald-600 leading-none">{evacuees.length}</span>
                  <span className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Registered</span>
                </div>
              </header>

              <div className="flex-1 overflow-y-auto space-y-3 pr-2">
                {evacuees.length === 0 ? (
                  <div className="py-20 text-center opacity-30 text-[10px] font-black uppercase">Static terminal - focus required</div>
                ) : (
                  evacuees.map((ev) => (
                    <div key={ev.id} className="p-4 bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-800 rounded-2xl flex items-center justify-between group">
                      <div>
                        <p className="text-[10px] font-black uppercase">{ev.firstName} {ev.lastName}</p>
                        <p className="text-[8px] font-bold text-zinc-500 uppercase">{ev.gender} • AGE {ev.age || '?'}</p>
                      </div>
                      <button
                        onClick={async () => {
                          if (confirm('De-register this person?')) {
                            await fetch(`/api/evacuation-center/residents?id=${ev.id}`, { method: 'DELETE' });
                            fetchEvacuees(selectedEC.id);
                            fetchEvacuationCenters(user.barangay);
                          }
                        }}
                        className="h-8 w-8 flex items-center justify-center rounded-lg bg-zinc-100 dark:bg-zinc-700 text-zinc-400 hover:bg-red-600 hover:text-white transition-all opacity-0 group-hover:opacity-100"
                      >
                        <XCircle size={14} />
                      </button>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
