'use client';

import { MapContainer, TileLayer, Marker, Popup, Circle, Polygon, useMap } from 'react-leaflet';
import L from 'leaflet';
import { useEffect, useState } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';

// Fix for Leaflet default icon issues in Next.js
const fixLeafletIcon = () => {
  // @ts-expect-error - Leaflet icon options
  delete L.Icon.Default.prototype._getIconUrl;
  L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
    iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
    shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
  });
};

import { 
  Waves, Flame, Activity, Wind, Mountain, PersonStanding, 
  MapPin, ThumbsUp, ThumbsDown, CheckCircle, Flag, 
  Layers, History, Edit3, X, ZapOff, Droplets, 
  WifiOff, Construction, MoreHorizontal, Building2, 
  Navigation, Check, AlertTriangle, Camera,
  Settings, Users, ChevronRight, ClipboardList
} from 'lucide-react';

const disasterTypeConfig: Record<string, { color: string, icon: any }> = {
  'Flooding': { color: '#3b82f6', icon: Waves },
  'Fire': { color: '#ef4444', icon: Flame },
  'Collapsed buildings': { color: '#78350f', icon: Building2 },
  'Landslide / soil erosion': { color: '#854d0e', icon: Mountain },
  'Volcanic activity': { color: '#ea580c', icon: Activity },
  'Power outage': { color: '#eab308', icon: ZapOff },
  'Water supply disruption': { color: '#0ea5e9', icon: Droplets },
  'Signal failure (cell network down)': { color: '#64748b', icon: WifiOff },
  'Road blockage / impassable routes': { color: '#6d28d9', icon: Construction },
  'Other (custom entry)': { color: '#475569', icon: MoreHorizontal },
};

const createCustomIcon = (type: string) => {
  const config = disasterTypeConfig[type] || { color: '#ef4444', icon: MapPin };
  const Icon = config.icon;

  const html = renderToStaticMarkup(
    <div style={{
      backgroundColor: 'white',
      borderRadius: '50%',
      width: '40px',
      height: '40px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      border: `2px solid ${config.color}`,
      boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)'
    }}>
      <Icon size={20} color={config.color} />
    </div>
  );

  return new L.DivIcon({
    html,
    className: 'custom-hazard-marker',
    iconSize: [40, 40],
    iconAnchor: [20, 20],
  });
};

const FlyToLocation = ({ center }: { center: [number, number] | null }) => {
  const map = useMap();
  useEffect(() => {
    if (center) {
      // Use current zoom if it's already deep, otherwise use 15
      const currentZoom = map.getZoom();
      map.flyTo(center, Math.max(currentZoom, 15), { duration: 1.5 });
    }
  }, [center, map]);
  return null;
};

const LocationHandler = ({ watchLocation }: { watchLocation: number }) => {
  const map = useMap();
  useEffect(() => {
    if (watchLocation > 0) {
      map.locate({ setView: true, maxZoom: 18 });
    }
  }, [map, watchLocation]);

  useEffect(() => {
    map.on('locationfound', (e) => {
      const userHtml = renderToStaticMarkup(
        <div className="relative">
          <div className="absolute inset-0 bg-blue-500 rounded-full animate-ping opacity-25"></div>
          <div className="relative bg-blue-600 rounded-full w-5 h-5 border-2 border-white shadow-xl"></div>
        </div>
      );
      L.marker(e.latlng, { icon: L.divIcon({ html: userHtml, className: '' }) })
        .addTo(map)
        .bindPopup("Your current location")
        .openPopup();
    });
  }, [map]);
  return null;
};

interface Report {
  id: string;
  type: string;
  description: string | null;
  latitude: number;
  longitude: number;
  imageUrl: string | null;
  createdAt: string;
}

const MapEvents = ({ onMapClick }: { onMapClick: (latlng: L.LatLng) => void }) => {
  const map = useMap();
  useEffect(() => {
    map.on('moveend zoomend', () => {
      localStorage.setItem('riskqph_map_state', JSON.stringify({
        center: [map.getCenter().lat, map.getCenter().lng],
        zoom: map.getZoom()
      }));
    });
    
    map.on('click', (e) => {
      onMapClick(e.latlng);
    });
  }, [map, onMapClick]);
  return null;
};

const Map = ({ showBarangays: initialShowBarangays = true }: { showBarangays?: boolean }) => {
  const [reports, setReports] = useState<Report[]>([]);
  const [focusCenter, setFocusCenter] = useState<[number, number] | null>(null);
  
  // UI State
  const [isReportsPanelOpen, setIsReportsPanelOpen] = useState(false);
  const [isLayersPanelOpen, setIsLayersPanelOpen] = useState(false);
  const [isFamilyPanelOpen, setIsFamilyPanelOpen] = useState(false);
  const [isReportMode, setIsReportMode] = useState(false);
  const [showBarangayBoundaries, setShowBarangayBoundaries] = useState(initialShowBarangays);
  const [reportingLocation, setReportingLocation] = useState<[number, number] | null>(null);
  const [isActionGroupExpanded, setIsActionGroupExpanded] = useState(false);
  const [user, setUser] = useState<any>(null);
  
  // Report Form State
  const [selectedType, setSelectedType] = useState<string | null>(null);
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [locationTrigger, setLocationTrigger] = useState(0);

  // Persisted Map State
  const [initialState, setInitialState] = useState<{ center: [number, number], zoom: number } | null>(null);

  useEffect(() => {
    const saved = localStorage.getItem('riskqph_map_state');
    if (saved) {
      setInitialState(JSON.parse(saved));
    } else {
      setInitialState({ center: [12.8797, 121.7740], zoom: 6 });
    }

    const savedUser = localStorage.getItem('user');
    if (savedUser) {
      setUser(JSON.parse(savedUser));
    }
  }, []);

  const fetchReports = async () => {
    try {
      const res = await fetch('/api/reports');
      const data = await res.json();
      if (Array.isArray(data)) {
        setReports(data);
      } else {
        console.error('Expected array of reports, got:', data);
        setReports([]); // Fallback to empty list instead of crashing
      }
    } catch (e) {
      console.error('Fetch error:', e);
      setReports([]); // Safety first
    }
  };

  const handleAction = async (id: string, action: string) => {
    try {
      const res = await fetch(`/api/reports/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action }),
      });
      if (res.ok) fetchReports();
    } catch (e) {
      console.error(e);
    }
  };

  useEffect(() => {
    fixLeafletIcon();
    fetchReports();
    const interval = setInterval(fetchReports, 10000); // Polling for sync
    return () => clearInterval(interval);
  }, []);

  const barangaySamples = [
    {
      name: 'Barangay 649 (Baseco)',
      points: [
        [14.5930, 120.9600],
        [14.5960, 120.9600],
        [14.5960, 120.9650],
        [14.5930, 120.9650],
      ] as [number, number][],
      risk: 0.9,
    },
    {
      name: 'Barangay 20 (Parola)',
      points: [
        [14.6040, 120.9580],
        [14.6080, 120.9580],
        [14.6080, 120.9630],
        [14.6040, 120.9630],
      ] as [number, number][],
      risk: 0.7,
    },
    {
      name: 'Barangay 128 (Smokey Mountain)',
      points: [
        [14.6280, 120.9610],
        [14.6320, 120.9610],
        [14.6320, 120.9660],
        [14.6280, 120.9660],
      ] as [number, number][],
      risk: 0.8,
    },
    {
      name: 'Intramuros',
      points: [
        [14.5880, 120.9730],
        [14.5940, 120.9730],
        [14.5940, 120.9780],
        [14.5880, 120.9780],
      ] as [number, number][],
      risk: 0.2,
    },
  ];

  if (!initialState) return <div className="h-full w-full bg-zinc-100 animate-pulse" />;

  const handleMapClick = (latlng: L.LatLng) => {
    if (isReportMode) {
      setReportingLocation([latlng.lat, latlng.lng]);
    }
  };

  const submitReport = async () => {
    if (!selectedType || !reportingLocation) return;
    setIsSubmitting(true);
    try {
      const res = await fetch('/api/reports', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: selectedType,
          description,
          latitude: reportingLocation[0],
          longitude: reportingLocation[1],
          reporterName: 'Web User', // Should ideally come from auth
        }),
      });
      if (res.ok) {
        setReportingLocation(null);
        setSelectedType(null);
        setDescription('');
        fetchReports();
      }
    } catch (e) {
      console.error(e);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!initialState) return <div className="h-full w-full bg-zinc-100 animate-pulse" />;

  return (
    <div className="relative h-full w-full overflow-hidden">
      {/* Unified Action Menu (Top Left - Horizontal, matching mobile app) */}
      <div className="absolute top-6 left-6 z-[2000] flex flex-col items-start gap-4">
        <div className="flex items-center gap-2 p-1.5 bg-zinc-900/90 backdrop-blur-xl border border-zinc-800 rounded-[24px] shadow-2xl">
          <button
            onClick={() => {
              setIsActionGroupExpanded(!isActionGroupExpanded);
              if (!isActionGroupExpanded) {
                setIsLayersPanelOpen(false);
                setIsReportsPanelOpen(false);
                setIsFamilyPanelOpen(false);
              }
            }}
            className={`w-10 h-10 flex items-center justify-center rounded-full transition-all duration-300 ${
              isActionGroupExpanded ? 'bg-red-600 text-white rotate-90' : 'bg-white text-zinc-900'
            }`}
          >
            {isActionGroupExpanded ? <X size={20} /> : <ChevronRight size={20} />}
          </button>

          {isActionGroupExpanded && (
            <div className="flex items-center gap-2 pr-1 animate-in slide-in-from-left-4 duration-300">
              <div className="w-[1px] h-6 bg-zinc-800 mx-1" />
              
              {/* Settings/Layers */}
              <button
                onClick={() => {
                  setIsLayersPanelOpen(!isLayersPanelOpen);
                  setIsReportsPanelOpen(false);
                  setIsFamilyPanelOpen(false);
                }}
                className={`w-10 h-10 flex items-center justify-center rounded-full transition-all ${
                  isLayersPanelOpen ? 'bg-zinc-700 text-white' : 'bg-transparent text-zinc-400 hover:bg-zinc-800 hover:text-white'
                }`}
                title="Settings/Layers"
              >
                <Settings size={20} />
              </button>

              {/* Family (Resident Only) */}
              {user?.role === 'resident' && (
                <button
                  onClick={() => {
                    setIsFamilyPanelOpen(!isFamilyPanelOpen);
                    setIsLayersPanelOpen(false);
                    setIsReportsPanelOpen(false);
                  }}
                  className={`w-10 h-10 flex items-center justify-center rounded-full transition-all ${
                    isFamilyPanelOpen ? 'bg-zinc-700 text-white' : 'bg-transparent text-zinc-400 hover:bg-zinc-800 hover:text-white'
                  }`}
                  title="My Family"
                >
                  <Users size={20} />
                </button>
              )}

              {/* Reports List */}
              <button
                onClick={() => {
                  setIsReportsPanelOpen(!isReportsPanelOpen);
                  setIsLayersPanelOpen(false);
                  setIsFamilyPanelOpen(false);
                }}
                className={`w-10 h-10 flex items-center justify-center rounded-full transition-all ${
                  isReportsPanelOpen ? 'bg-zinc-700 text-white' : 'bg-transparent text-zinc-400 hover:bg-zinc-800 hover:text-white'
                }`}
                title="Recent Reports"
              >
                <ClipboardList size={20} />
              </button>

              {/* Report Mode */}
              <button
                onClick={() => {
                  setIsReportMode(!isReportMode);
                }}
                className={`w-10 h-10 flex items-center justify-center rounded-full transition-all ${
                  isReportMode ? 'bg-red-600 text-white drop-shadow-[0_0_10px_rgba(239,68,68,0.4)]' : 'bg-transparent text-zinc-400 hover:bg-zinc-800 hover:text-white'
                }`}
                title="Report Incident Mode"
              >
                <Edit3 size={20} className={isReportMode ? 'animate-pulse' : ''} />
              </button>
            </div>
          )}
        </div>

        {/* Panel Popups (Aligned with the menu) */}
        <div className="flex flex-col gap-3">
          {isReportsPanelOpen && (
            <div className="w-72 max-h-[60vh] bg-white/95 backdrop-blur-xl rounded-[28px] shadow-2xl border border-zinc-200/50 overflow-hidden flex flex-col animate-in slide-in-from-top-4 duration-300">
              <div className="p-5 bg-zinc-900 text-white flex items-center justify-between">
                <h2 className="text-xs font-black uppercase tracking-widest flex items-center gap-2">
                  <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
                  Live Reports
                </h2>
                <button onClick={() => setIsReportsPanelOpen(false)} className="p-1 hover:bg-zinc-800 rounded-full transition-colors">
                  <X size={14} />
                </button>
              </div>
              <div className="overflow-y-auto flex-1 p-3 space-y-2">
                {reports.length === 0 ? (
                  <p className="text-[10px] text-zinc-500 text-center py-8 font-medium italic">No recent reports found in this area.</p>
                ) : (
                  reports.map((r) => {
                    const config = disasterTypeConfig[r.type] || { color: '#6366f1', icon: MapPin };
                    return (
                      <button
                        key={r.id}
                        onClick={() => setFocusCenter([r.latitude, r.longitude])}
                        className="w-full text-left p-3 rounded-2xl hover:bg-zinc-50 transition-all border border-transparent hover:border-zinc-100 group flex items-center gap-3"
                      >
                        <div className="w-10 h-10 rounded-xl bg-zinc-100 group-hover:bg-white transition-colors flex items-center justify-center flex-shrink-0" style={{ color: config.color }}>
                          <config.icon size={18} />
                        </div>
                        <div className="min-w-0">
                          <p className="text-[11px] font-bold text-zinc-900 truncate">{r.type}</p>
                          <p className="text-[10px] text-zinc-500 truncate">{r.description || 'No description provided'}</p>
                        </div>
                      </button>
                    );
                  })
                )}
              </div>
            </div>
          )}

          {isLayersPanelOpen && (
            <div className="w-64 bg-white/95 backdrop-blur-xl rounded-[28px] shadow-2xl border border-zinc-200/50 overflow-hidden animate-in slide-in-from-top-4 duration-300">
              <div className="p-5 bg-zinc-900 text-white flex items-center justify-between">
                <h2 className="text-xs font-black uppercase tracking-widest">Map Layers</h2>
                <button onClick={() => setIsLayersPanelOpen(false)} className="p-1 hover:bg-zinc-800 rounded-full transition-colors">
                  <X size={14} />
                </button>
              </div>
              <div className="p-4 space-y-4">
                <div 
                  onClick={() => setShowBarangayBoundaries(!showBarangayBoundaries)}
                  className="flex items-center justify-between p-3 rounded-2xl hover:bg-zinc-50 cursor-pointer transition-all group border border-transparent hover:border-zinc-100"
                >
                  <div className="flex flex-col">
                    <span className="text-[11px] font-bold text-zinc-900">Barangay Boundaries</span>
                    <span className="text-[9px] text-zinc-500">Risk Level Shading</span>
                  </div>
                  <div className={`w-10 h-6 rounded-full transition-all flex items-center px-1 ${showBarangayBoundaries ? 'bg-zinc-900' : 'bg-zinc-200'}`}>
                    <div className={`w-4 h-4 rounded-full bg-white transition-all shadow-sm ${showBarangayBoundaries ? 'translate-x-4' : 'translate-x-0'}`} />
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Bottom Right: Location Toggle */}
      <div className="absolute bottom-10 right-10 z-[1000]">
        <button
          onClick={() => setLocationTrigger(prev => prev + 1)}
          className="w-14 h-14 bg-white border border-zinc-200 text-zinc-900 rounded-full shadow-2xl group hover:bg-zinc-900 hover:text-white transition-all hover:scale-110 active:scale-95 flex items-center justify-center overflow-hidden relative"
          title="Find My Location"
        >
          <Navigation size={24} className="group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
          <div className="absolute inset-x-0 bottom-0 h-1 bg-blue-600 opacity-0 group-hover:opacity-100 transition-opacity" />
        </button>
      </div>

      {/* Report Modal */}
      {reportingLocation && (
        <div className="absolute inset-0 z-[3000] flex items-center justify-center p-4 bg-black/60 backdrop-blur-md animate-in fade-in duration-300">
          <div className="bg-white rounded-[40px] shadow-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-300 border border-white/20">
            <div className="p-8 border-b border-zinc-100 flex items-center justify-between bg-zinc-50/50">
              <div>
                <h3 className="text-2xl font-black text-zinc-900 tracking-tight">Report Incident</h3>
                <p className="text-[11px] text-zinc-500 font-bold uppercase tracking-widest mt-1 opacity-60">Selection Required</p>
              </div>
              <button 
                onClick={() => setReportingLocation(null)}
                className="w-10 h-10 flex items-center justify-center bg-white hover:bg-zinc-200 rounded-full transition-all shadow-sm"
              >
                <X size={20} className="text-zinc-500" />
              </button>
            </div>
            
            <div className="p-8 space-y-8">
              <div className="grid grid-cols-3 gap-3 max-h-[340px] overflow-y-auto p-1 pr-2 custom-scrollbar">
                {Object.entries(disasterTypeConfig).map(([type, config]) => (
                  <button
                    key={type}
                    onClick={() => setSelectedType(type)}
                    className={`group flex flex-col items-center gap-3 p-4 rounded-[32px] transition-all ${
                      selectedType === type 
                        ? 'bg-zinc-900 text-white scale-[1.02] shadow-xl ring-4 ring-zinc-900/10' 
                        : 'bg-zinc-50 text-zinc-600 hover:bg-zinc-100 border border-transparent'
                    }`}
                  >
                    <div className={`w-12 h-12 flex items-center justify-center rounded-2xl transition-all ${selectedType === type ? 'bg-white/10 rotate-12' : 'bg-white shadow-sm'}`}>
                      <config.icon size={22} color={selectedType === type ? 'white' : config.color} />
                    </div>
                    <span className="text-[10px] font-black text-center leading-tight uppercase tracking-tighter">{type}</span>
                  </button>
                ))}
              </div>
              
              <div className="space-y-3">
                <label className="text-[11px] font-black uppercase tracking-widest text-zinc-400 pl-1">Description</label>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Provide essential details for responder accuracy..."
                  className="w-full h-32 p-6 rounded-[32px] bg-zinc-50 border border-zinc-200 focus:outline-none focus:ring-4 focus:ring-zinc-900/5 focus:border-zinc-900 transition-all text-sm resize-none"
                />
              </div>

              <div className="flex flex-col gap-4">
                <div className="flex items-center gap-3 px-6 py-4 bg-zinc-50 rounded-[28px] border border-dashed border-zinc-300/50">
                  <div className="w-8 h-8 rounded-full bg-white flex items-center justify-center text-zinc-400">
                    <Camera size={16} />
                  </div>
                  <span className="text-[11px] text-zinc-500 font-bold italic tracking-tight uppercase">Photo evidence coming soon</span>
                </div>
                
                <button
                  disabled={!selectedType || isSubmitting}
                  onClick={submitReport}
                  className={`w-full py-6 rounded-[32px] font-black uppercase tracking-[2px] text-xs flex items-center justify-center gap-3 transition-all ${
                    !selectedType || isSubmitting
                      ? 'bg-zinc-100 text-zinc-400 cursor-not-allowed'
                      : 'bg-red-600 text-white hover:bg-red-700 shadow-2xl shadow-red-500/20 active:scale-95'
                  }`}
                >
                  {isSubmitting ? (
                    <div className="w-5 h-5 border-[3px] border-white/30 border-t-white rounded-full animate-spin"></div>
                  ) : (
                    <>
                      <Navigation size={18} fill="currentColor" />
                      Dispatch Alert
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      <MapContainer
        center={initialState.center}
        zoom={initialState.zoom}
        scrollWheelZoom={true}

        className="h-full w-full z-0"
      >
        <MapEvents onMapClick={handleMapClick} />
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <LocationHandler watchLocation={locationTrigger} />
        <FlyToLocation center={focusCenter} />

        {/* Barangay boundaries */}
        {showBarangayBoundaries && barangaySamples.map((b, i) => {
          const color = b.risk > 0.8 ? '#ef4444' : b.risk > 0.5 ? '#f97316' : '#22c55e';
          return (
            <Polygon
              key={`b-${i}`}
              positions={b.points}
              pathOptions={{ fillColor: color, color: color, fillOpacity: 0.3, weight: 2 }}
            >
              <Popup>
                <div className="p-1">
                  <h3 className="font-bold text-xs">{b.name}</h3>
                  <p className="text-[10px] text-zinc-500">Risk Level: {(b.risk * 100).toFixed(0)}%</p>
                </div>
              </Popup>
            </Polygon>
          );
        })}

        {reports.filter((r: any) => !r.isResolved).map((r: any) => {
          const config = disasterTypeConfig[r.type] || { color: '#6366f1', icon: MapPin };
          const isOwnReport = r.userId === (typeof window !== 'undefined' ? localStorage.getItem('riskqph_user_id') : null);
          return (
            <div key={r.id}>
              <Marker position={[r.latitude, r.longitude]} icon={createCustomIcon(r.type)}>
                <Popup className="report-popup">
                  <div className="w-64 p-2">
                    {r.imageUrl && (
                      <div className="relative w-full h-32 rounded-2xl overflow-hidden mb-4 shadow-sm">
                        <img src={r.imageUrl} alt={r.type} className="w-full h-full object-cover" />
                        <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                      </div>
                    )}
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2">
                        <div className="w-2.5 h-2.5 rounded-full animate-pulse" style={{ backgroundColor: config.color }} />
                        <h3 className="font-black text-xs uppercase tracking-widest text-zinc-900">{r.type}</h3>
                      </div>
                      {r.isResolved && (
                        <span className="text-[8px] font-black text-emerald-600 bg-emerald-50 px-2 py-1 rounded-full border border-emerald-100 tracking-tighter">
                          RESOLVED
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-1.5 mb-3">
                      <div className="w-4 h-4 rounded-full bg-zinc-100 flex items-center justify-center">
                        <Users size={10} className="text-zinc-400" />
                      </div>
                      <p className="text-[9px] font-bold text-zinc-400 uppercase tracking-tight">Reported by {r.reporterName}</p>
                    </div>
                    <p className="text-[11px] text-zinc-600 leading-relaxed font-medium mb-4 bg-zinc-50 p-3 rounded-xl border border-zinc-100/50">{r.description || 'No additional details provided by the reporter.'}</p>

                    <div className="flex items-center gap-2 pt-3 border-t border-zinc-100">
                      <button
                        onClick={() => handleAction(r.id, 'upvote')}
                        className={`flex-1 flex items-center justify-center gap-2 py-2 rounded-xl text-[10px] font-extrabold transition-all ${isOwnReport
                            ? 'bg-emerald-50 text-emerald-600 opacity-50 cursor-not-allowed'
                            : 'bg-emerald-50 text-emerald-600 hover:bg-emerald-500 hover:text-white border border-emerald-100'
                          }`}
                      >
                        <CheckCircle size={14} />
                        Agree ({r.upvotes})
                      </button>
                      <button
                        onClick={() => handleAction(r.id, 'flag')}
                        className={`flex items-center justify-center w-10 h-10 rounded-xl transition-all ${isOwnReport
                            ? 'bg-zinc-50 text-zinc-400 opacity-50 cursor-not-allowed'
                            : 'bg-amber-50 text-amber-600 hover:bg-amber-500 hover:text-white border border-amber-100'
                          }`}
                        title="Flag as false info"
                      >
                        <Flag size={14} />
                      </button>
                    </div>

                    {!r.isResolved && (
                      <button
                        onClick={() => handleAction(r.id, 'resolve')}
                        className="w-full mt-2 font-black text-[9px] py-2.5 rounded-xl border-2 border-emerald-600 text-emerald-600 hover:bg-emerald-600 hover:text-white transition-all uppercase tracking-widest bg-white"
                      >
                        Mark as Resolved
                      </button>
                    )}
                  </div>
                </Popup>
              </Marker>
            </div>
          );
        })}
      </MapContainer>
    </div>
  );
};

export default Map;
