'use client';

import { MapContainer, TileLayer, Marker, Popup, Circle, Polygon, useMap, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useEffect, useState, useCallback } from 'react';
import { 
  User, ShieldCheck, ShieldAlert, MapPin, Landmark,
  Waves, Flame, Activity, Wind, Mountain, PersonStanding,
  Layers, History, Edit3, X, ZapOff, Droplets, 
  WifiOff, Construction, MoreHorizontal, Building2, 
  Navigation, Check, AlertTriangle, Camera,
  Home, HeartPulse, GraduationCap, Church
} from 'lucide-react';
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
      width: '32px',
      height: '32px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      border: `2px solid ${config.color}`,
      boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)'
    }}>
      <Icon size={16} color={config.color} />
    </div>
  );

  return new L.DivIcon({
    html,
    className: 'custom-hazard-marker',
    iconSize: [32, 32],
    iconAnchor: [16, 16],
  });
};

const createResidentIcon = (isSafe: boolean, isActive: boolean) => {
  const color = isActive ? (isSafe ? '#10b981' : '#ef4444') : '#6366f1';
  const html = renderToStaticMarkup(
    <div className={`relative flex items-center justify-center`}>
      {!isSafe && isActive && (
        <div className="absolute w-10 h-10 bg-red-500/30 rounded-full animate-ping" />
      )}
      <div style={{
        backgroundColor: 'white',
        borderRadius: '50%',
        width: '32px',
        height: '32px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        border: `2px solid ${color}`,
        boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)'
      }}>
        {isSafe ? <ShieldCheck size={16} color={color} /> : <User size={16} color={color} />}
      </div>
    </div>
  );

  return new L.DivIcon({
    html,
    className: 'resident-marker',
    iconSize: [32, 32],
    iconAnchor: [16, 16],
  });
};

const createBarangayIcon = () => {
  const html = renderToStaticMarkup(
    <div className="bg-zinc-900 border-2 border-white rounded-xl p-2 shadow-2xl scale-125">
       <Landmark size={20} color="white" />
    </div>
  );
  return new L.DivIcon({
    html,
    className: 'barangay-marker',
    iconSize: [40, 40],
    iconAnchor: [20, 20],
  });
};

const createEvacuationIcon = (name: string, type?: string) => {
  let Icon = Landmark;
  switch (type) {
    case 'Building': Icon = Building2; break;
    case 'Home': Icon = Home; break;
    case 'Medical': Icon = HeartPulse; break;
    case 'School': Icon = GraduationCap; break;
    case 'Church': Icon = Church; break;
    case 'Activity': Icon = Activity; break;
    default: Icon = Landmark;
  }

  const html = renderToStaticMarkup(
    <div className="flex flex-col items-center gap-1 -translate-y-8">
      <div className="bg-white border-2 border-zinc-400 rounded-xl p-2 shadow-2xl scale-110">
         <Icon size={20} className="text-zinc-600" />
      </div>
      <div className="bg-zinc-900/80 backdrop-blur-md text-white text-[8px] font-black uppercase px-2 py-1 rounded-lg shadow-xl whitespace-nowrap tracking-widest border border-white/20">
         {name}
      </div>
    </div>
  );
  return new L.DivIcon({
    html,
    className: 'evacuation-marker',
    iconSize: [40, 60],
    iconAnchor: [20, 30],
  });
};

const MapEvents = ({ onMapClick }: { onMapClick: (latlng: L.LatLng) => void }) => {
  useMapEvents({
    click(e) {
      onMapClick(e.latlng);
    },
  });
  return null;
};

const FlyToLocation = ({ center, zoom = 16 }: { center: [number, number] | null, zoom?: number }) => {
  const map = useMap();
  useEffect(() => {
    if (center) {
      map.flyTo(center, zoom, { duration: 1.5 });
    }
  }, [center, map, zoom]);
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

interface Resident {
  id: string;
  firstName: string;
  lastName: string;
  latitude: number | null;
  longitude: number | null;
  isSafe: boolean;
  hasResponded: boolean;
}

interface Report {
  id: string;
  type: string;
  description: string | null;
  latitude: number;
  longitude: number;
  imageUrl: string | null;
  createdAt: string;
  reporterName: string;
  isResolved?: boolean;
}

interface EvacuationCenter {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  capacity: number | null;
  type: string | null;
  _count?: {
    evacuees: number;
  };
}

export default function BarangayMap({ 
  residents, 
  isActive, 
  focusResident,
  hqLocation,
  onMapClick,
  barangayName,
  evacuationCenters = [],
  onSelectEvacuationCenter
}: { 
  residents: Resident[], 
  isActive: boolean,
  focusResident?: Resident | null,
  hqLocation?: { lat: number, lng: number } | null,
  onMapClick?: (lat: number, lng: number) => void,
  barangayName?: string,
  evacuationCenters?: EvacuationCenter[],
  onSelectEvacuationCenter?: (center: EvacuationCenter) => void
}) {
  const [reports, setReports] = useState<Report[]>([]);
  const [focusCenter, setFocusCenter] = useState<[number, number] | null>(null);
  
  // UI State
  const [isReportsPanelOpen, setIsReportsPanelOpen] = useState(false);
  const [isLayersPanelOpen, setIsLayersPanelOpen] = useState(false);
  const [isReportMode, setIsReportMode] = useState(false);
  const [showBarangayBoundaries, setShowBarangayBoundaries] = useState(true);
  const [reportingLocation, setReportingLocation] = useState<[number, number] | null>(null);
  const [locationTrigger, setLocationTrigger] = useState(0);
  
  // Report Form State
  const [selectedType, setSelectedType] = useState<string | null>(null);
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchReports = useCallback(async () => {
    try {
      const res = await fetch('/api/reports');
      const data = await res.json();
      if (Array.isArray(data)) {
        setReports(data);
      }
    } catch (e) {
      console.error('Fetch error:', e);
    }
  }, []);

  useEffect(() => {
    fixLeafletIcon();
    fetchReports();
    const interval = setInterval(fetchReports, 15000);
    return () => clearInterval(interval);
  }, [fetchReports]);

  const handleMapInteraction = (latlng: L.LatLng) => {
    if (isReportMode) {
      setReportingLocation([latlng.lat, latlng.lng]);
    } else if (onMapClick) {
      onMapClick(latlng.lat, latlng.lng);
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
          reporterName: `Brgy. ${barangayName || 'Head'}`,
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

  const validResidents = residents.filter(r => r.latitude && r.longitude);
  const center: [number, number] = focusResident?.latitude && focusResident?.longitude 
    ? [focusResident.latitude, focusResident.longitude]
    : hqLocation 
      ? [hqLocation.lat, hqLocation.lng]
      : validResidents.length > 0 
        ? [validResidents[0].latitude!, validResidents[0].longitude!]
        : [12.8797, 121.7740];


  return (
    <div className="h-full w-full relative group/map">
      {/* Top Right: Recent Reports (Offset to avoid clashing with Activity Log button) */}
      <div className="absolute top-24 right-6 z-[1010] flex flex-col items-end gap-3">
        <button
          onClick={() => {
            setIsReportsPanelOpen(!isReportsPanelOpen);
            if (!isReportsPanelOpen) setIsLayersPanelOpen(false);
          }}
          className={`p-3 rounded-2xl shadow-xl border transition-all ${
            isReportsPanelOpen ? 'bg-zinc-900 border-zinc-800 text-white' : 'bg-white/90 backdrop-blur-md border-zinc-200 text-zinc-900 group hover:bg-zinc-50'
          }`}
        >
          {isReportsPanelOpen ? <X size={20} /> : <History size={20} className="hover:scale-110 transition-transform" />}
        </button>

        {isReportsPanelOpen && (
          <div className="w-64 max-h-[50vh] bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl border border-zinc-200 overflow-hidden flex flex-col animate-in slide-in-from-right duration-300">
            <div className="p-4 bg-zinc-900 text-white">
              <h2 className="text-[10px] font-black uppercase tracking-widest flex items-center gap-2">
                <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
                Incident Feed
              </h2>
            </div>
            <div className="overflow-y-auto flex-1 p-2 space-y-1">
              {reports.length === 0 ? (
                <p className="text-[10px] text-zinc-500 text-center py-4 font-bold">STATION IDLE</p>
              ) : (
                reports.map((r) => {
                  const config = disasterTypeConfig[r.type] || { color: '#6366f1', icon: MapPin };
                  return (
                    <button
                      key={r.id}
                      onClick={() => setFocusCenter([r.latitude, r.longitude])}
                      className="w-full text-left p-2.5 rounded-xl hover:bg-zinc-100 transition-all border border-transparent hover:border-zinc-200 group"
                    >
                      <div className="flex items-center gap-3">
                        <div className="p-2 rounded-lg bg-zinc-50 group-hover:bg-white transition-colors flex-shrink-0" style={{ color: config.color }}>
                          <config.icon size={14} />
                        </div>
                        <div className="min-w-0">
                          <p className="text-[10px] font-black text-zinc-900 truncate uppercase">{r.type}</p>
                          <p className="text-[9px] text-zinc-500 truncate font-medium">{r.description || 'No data reported'}</p>
                        </div>
                      </div>
                    </button>
                  );
                })
              )}
            </div>
          </div>
        )}
      </div>

      {/* Top Left: Layers & Report Mode (Offset to avoid clashing with Legend) */}
      <div className="absolute top-40 left-6 z-[1010] flex flex-col items-start gap-4">
        {/* Layers Toggle */}
        <button
          onClick={() => {
            setIsLayersPanelOpen(!isLayersPanelOpen);
            if (!isLayersPanelOpen) setIsReportsPanelOpen(false);
          }}
          className={`p-3 rounded-2xl shadow-xl border transition-all ${
            isLayersPanelOpen ? 'bg-zinc-900 border-zinc-800 text-white' : 'bg-white/90 backdrop-blur-md border-zinc-200 text-zinc-900 group hover:bg-zinc-50'
          }`}
        >
          {isLayersPanelOpen ? <X size={20} /> : <Layers size={20} className="hover:scale-110 transition-transform" />}
        </button>

        {isLayersPanelOpen && (
          <div className="w-56 bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl border border-zinc-200 overflow-hidden animate-in slide-in-from-left duration-300">
            <div className="p-4 bg-zinc-900 text-white">
              <h2 className="text-[10px] font-black uppercase tracking-widest">Map Configuration</h2>
            </div>
            <div className="p-3">
               <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-widest text-center py-2 opacity-50">Map Overlays Active</p>
            </div>
          </div>
        )}

        {/* Report Mode Toggle */}
        <button
          onClick={() => setIsReportMode(!isReportMode)}
          className={`p-3 rounded-2xl shadow-xl border transition-all ${
            isReportMode ? 'bg-red-600 border-red-700 text-white ring-4 ring-red-100 animate-pulse' : 'bg-white/90 backdrop-blur-md border-zinc-200 text-zinc-900 group hover:bg-zinc-50'
          }`}
          title="Toggle Manual Reporting"
        >
          <Edit3 size={20} className={isReportMode ? 'animate-bounce' : 'group-hover:scale-110 transition-transform'} />
        </button>
      </div>

      {/* Bottom Right: Location Toggle */}
      <div className="absolute bottom-10 right-6 z-[1010]">
        <button
          onClick={() => setLocationTrigger(prev => prev + 1)}
          className="p-4 bg-white border border-zinc-200 text-zinc-900 rounded-full shadow-2xl group hover:bg-zinc-50 transition-all hover:scale-110 active:scale-95"
          title="Focus Location"
        >
          <Navigation size={22} className="group-hover:text-blue-600 transition-colors" />
        </button>
      </div>

      {/* Manual Report Modal */}
      {reportingLocation && (
        <div className="absolute inset-0 z-[2000] flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 animate-in fade-in duration-300">
          <div className="bg-white rounded-[2.5rem] shadow-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-300 border border-zinc-200">
            <div className="p-6 border-b border-zinc-100 flex items-center justify-between bg-zinc-50">
              <div>
                <h3 className="text-xl font-black uppercase tracking-tighter text-zinc-900">Manual Incident Dispatch</h3>
                <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Log external jurisdictional hazard</p>
              </div>
              <button onClick={() => setReportingLocation(null)} className="p-2 hover:bg-zinc-200 rounded-full transition-colors">
                <X size={20} className="text-zinc-500" />
              </button>
            </div>
            
            <div className="p-6 space-y-6">
              <div className="grid grid-cols-4 gap-3 max-h-[250px] overflow-y-auto p-1">
                {Object.entries(disasterTypeConfig).map(([type, config]) => (
                  <button
                    key={type}
                    onClick={() => setSelectedType(type)}
                    className={`flex flex-col items-center gap-2 p-2 rounded-2xl transition-all ${
                      selectedType === type 
                        ? 'bg-zinc-900 text-white scale-105 shadow-lg' 
                        : 'bg-zinc-50 text-zinc-600 hover:bg-zinc-100 border border-transparent'
                    }`}
                  >
                    <div className={`p-2.5 rounded-xl ${selectedType === type ? 'bg-white/20' : 'bg-white shadow-sm'}`}>
                      <config.icon size={18} color={selectedType === type ? 'white' : config.color} />
                    </div>
                    <span className="text-[8px] font-black text-center leading-tight uppercase tracking-tighter">{type}</span>
                  </button>
                ))}
              </div>
              
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-zinc-900 ml-1">Dispatch Notes</label>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Detailed situation assessment..."
                  className="w-full h-24 p-4 rounded-2xl bg-zinc-50 border border-zinc-200 focus:outline-none focus:ring-2 focus:ring-zinc-900 text-[11px] font-bold uppercase resize-none transition-all"
                />
              </div>

              <button
                disabled={!selectedType || isSubmitting}
                onClick={submitReport}
                className={`w-full py-4 rounded-[1.25rem] font-black uppercase tracking-widest text-[10px] flex items-center justify-center gap-2 transition-all shadow-xl ${
                  !selectedType || isSubmitting
                    ? 'bg-zinc-100 text-zinc-400'
                    : 'bg-red-600 text-white hover:bg-red-700 active:scale-95'
                }`}
              >
                {isSubmitting ? <Activity className="animate-spin" size={16} /> : 'Dispatch Incident Log'}
              </button>
            </div>
          </div>
        </div>
      )}

      <MapContainer
        center={center}
        zoom={validResidents.length > 0 ? 15 : 6}
        scrollWheelZoom={true}
        className="h-full w-full z-0"
      >
        <MapEvents onMapClick={handleMapInteraction} />
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <FlyToLocation center={focusResident?.latitude && focusResident?.longitude ? [focusResident.latitude, focusResident.longitude] : focusCenter} />
        <LocationHandler watchLocation={locationTrigger} />


        {/* Existing Resident Markers */}
        {validResidents.map((r) => (
          <Marker 
            key={r.id} 
            position={[r.latitude!, r.longitude!]} 
            icon={createResidentIcon(r.isSafe, isActive)}
          >
            <Popup>
              <div className="p-2 min-w-32">
                <p className="font-bold text-sm text-zinc-900">{r.firstName} {r.lastName}</p>
                <div className={`mt-2 px-2 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider inline-block ${
                  isActive 
                    ? (r.isSafe ? 'bg-emerald-50 text-emerald-600 border border-emerald-100' : 'bg-red-50 text-red-600 border border-red-100')
                    : 'bg-zinc-100 text-zinc-500 border border-zinc-200'
                }`}>
                  {isActive ? (r.isSafe ? 'SAFE' : 'PENDING') : 'MONITORING'}
                </div>
              </div>
            </Popup>
          </Marker>
        ))}

        {/* Barangay HQ Marker */}
        {hqLocation && (
           <Marker 
             position={[hqLocation.lat, hqLocation.lng]} 
             icon={createBarangayIcon()}
           >
             <Popup>
               <div className="p-3">
                 <p className="text-[10px] font-black uppercase text-red-600 mb-1">HQ STATION</p>
                 <p className="font-bold text-sm text-zinc-900 leading-none capitalize">Brgy. {barangayName || 'Hall'}</p>
               </div>
             </Popup>
           </Marker>
        )}

        {/* Dynamic Hazard Reports */}
        {reports.filter(r => !r.isResolved).map((r) => (
          <Marker 
            key={r.id} 
            position={[r.latitude, r.longitude]} 
            icon={createCustomIcon(r.type)}
          >
            <Popup>
              <div className="w-48 p-1">
                <div className="flex items-center gap-2 mb-2">
                  <div className="w-2 h-2 rounded-full bg-red-600 animate-pulse" />
                  <p className="text-[10px] font-black uppercase tracking-widest">{r.type}</p>
                </div>
                <p className="text-[9px] text-zinc-500 italic mb-2 uppercase font-bold tracking-tighter">Reported by {r.reporterName}</p>
                <p className="text-xs text-zinc-600 mb-2 font-medium">{r.description || 'Verified hazard point.'}</p>
              </div>
            </Popup>
          </Marker>
        ))}

        {/* Evacuation Centers */}
        {evacuationCenters.map((ec) => (
          <Marker
            key={ec.id}
            position={[ec.latitude, ec.longitude]}
            icon={createEvacuationIcon(ec.name, ec.type || undefined)}
          >
            <Popup>
              <div className="p-3 min-w-48">
                <p className="text-[10px] font-black uppercase text-emerald-600 mb-1">EVACUATION CENTER</p>
                <p className="font-bold text-sm text-zinc-900 leading-none mb-2">{ec.name}</p>
                <div className="flex items-center justify-between text-[10px] font-bold text-zinc-500 uppercase mb-3">
                   <span>Occupancy:</span>
                   <span className="text-zinc-900">{ec._count?.evacuees || 0} / {ec.capacity || '∞'}</span>
                </div>
                {onSelectEvacuationCenter && (
                  <button 
                    onClick={() => onSelectEvacuationCenter(ec)}
                    className="w-full py-2 bg-emerald-600 text-white rounded-lg text-[9px] font-black uppercase tracking-widest hover:bg-emerald-700 transition-colors"
                  >
                    Open Registry
                  </button>
                )}
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
