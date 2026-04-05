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
  Navigation, Check, AlertTriangle, Camera
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
  const [isReportMode, setIsReportMode] = useState(false);
  const [showBarangayBoundaries, setShowBarangayBoundaries] = useState(initialShowBarangays);
  const [reportingLocation, setReportingLocation] = useState<[number, number] | null>(null);
  
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

  const hazards = [
    { pos: [14.5995, 120.9842] as [number, number], title: "Manila Region", desc: "Critical Flooding potential in NCR.", type: "Flooding" },
    { pos: [10.3157, 123.8854] as [number, number], title: "Cebu City", desc: "Moderate Storm Surge warning.", type: "Typhoon" },
    { pos: [7.0736, 125.6128] as [number, number], title: "Davao Region", desc: "Minor Seismic Activity recorded.", type: "Earthquake" }
  ];

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
      {/* Top Right: Recent Reports */}
      <div className="absolute top-4 right-4 z-[1000] flex flex-col items-end gap-3">
        <button
          onClick={() => {
            setIsReportsPanelOpen(!isReportsPanelOpen);
            if (!isReportsPanelOpen) setIsLayersPanelOpen(false);
          }}
          className={`p-3 rounded-2xl shadow-xl border transition-all ${
            isReportsPanelOpen ? 'bg-zinc-900 border-zinc-800 text-white' : 'bg-white border-zinc-200 text-zinc-900 group hover:bg-zinc-50'
          }`}
        >
          {isReportsPanelOpen ? <X size={20} /> : <History size={20} className="group-hover:scale-110 transition-transform" />}
        </button>

        {isReportsPanelOpen && (
          <div className="w-64 max-h-[70vh] bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl border border-zinc-200 overflow-hidden flex flex-col animate-in slide-in-from-right duration-300">
            <div className="p-4 bg-zinc-900 text-white">
              <h2 className="text-sm font-bold flex items-center gap-2">
                <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
                Recent Reports
              </h2>
            </div>
            <div className="overflow-y-auto flex-1 p-2 space-y-1">
              {reports.length === 0 ? (
                <p className="text-xs text-zinc-500 text-center py-4">No recent reports found.</p>
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
                        <div className="p-2 rounded-lg bg-zinc-100 group-hover:bg-white transition-colors flex-shrink-0" style={{ color: config.color }}>
                          <config.icon size={16} />
                        </div>
                        <div className="min-w-0">
                          <p className="text-[11px] font-bold text-zinc-900 truncate">{r.type}</p>
                          <p className="text-[10px] text-zinc-500 truncate">{r.description || 'No description'}</p>
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

      {/* Top Left: Layers & Report Mode */}
      <div className="absolute top-4 left-4 z-[1000] flex flex-col items-start gap-3">
        {/* Layers Toggle */}
        <button
          onClick={() => {
            setIsLayersPanelOpen(!isLayersPanelOpen);
            if (!isLayersPanelOpen) setIsReportsPanelOpen(false);
          }}
          className={`p-3 rounded-2xl shadow-xl border transition-all ${
            isLayersPanelOpen ? 'bg-zinc-900 border-zinc-800 text-white' : 'bg-white border-zinc-200 text-zinc-900 group hover:bg-zinc-50'
          }`}
        >
          {isLayersPanelOpen ? <X size={20} /> : <Layers size={20} className="group-hover:scale-110 transition-transform" />}
        </button>

        {isLayersPanelOpen && (
          <div className="w-56 bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl border border-zinc-200 overflow-hidden animate-in slide-in-from-left duration-300">
            <div className="p-4 bg-zinc-900 text-white">
              <h2 className="text-sm font-bold">Map Layers</h2>
            </div>
            <div className="p-3">
              <label className="flex items-center justify-between p-2 rounded-xl hover:bg-zinc-100 cursor-pointer transition-colors group">
                <div className="flex flex-col">
                  <span className="text-xs font-bold text-zinc-900">Barangay Boundaries</span>
                  <span className="text-[10px] text-zinc-500">Risk Color Coding</span>
                </div>
                <div className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    className="sr-only peer"
                    checked={showBarangayBoundaries}
                    onChange={(e) => setShowBarangayBoundaries(e.target.checked)}
                  />
                  <div className="w-9 h-5 bg-zinc-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-zinc-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-zinc-900"></div>
                </div>
              </label>
            </div>
          </div>
        )}

        {/* Report Mode Toggle */}
        <button
          onClick={() => {
            setIsReportMode(!isReportMode);
            if (!isReportMode) {
              // Show toast or something?
            }
          }}
          className={`p-3 rounded-2xl shadow-xl border transition-all ${
            isReportMode ? 'bg-red-600 border-red-700 text-white ring-4 ring-red-100' : 'bg-white border-zinc-200 text-zinc-900 group hover:bg-zinc-50'
          }`}
        >
          <Edit3 size={20} className={isReportMode ? 'animate-pulse' : 'group-hover:scale-110 transition-transform'} />
        </button>
      </div>

      {/* Bottom Right: Location Toggle */}
      <div className="absolute bottom-10 right-4 z-[1000]">
        <button
          onClick={() => setLocationTrigger(prev => prev + 1)}
          className="p-4 bg-white border border-zinc-200 text-zinc-900 rounded-full shadow-2xl group hover:bg-zinc-50 transition-all hover:scale-110 active:scale-95"
          title="Find My Location"
        >
          <Navigation size={24} className="group-hover:text-blue-600 transition-colors" />
        </button>
      </div>

      {/* Report Modal */}
      {reportingLocation && (
        <div className="absolute inset-0 z-[2000] flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 animate-in fade-in duration-300">
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-300">
            <div className="p-6 border-b border-zinc-100 flex items-center justify-between bg-zinc-50">
              <div>
                <h3 className="text-xl font-bold text-zinc-900">Report Incident</h3>
                <p className="text-xs text-zinc-500">Tap incident type to select</p>
              </div>
              <button 
                onClick={() => setReportingLocation(null)}
                className="p-2 hover:bg-zinc-200 rounded-full transition-colors"
              >
                <X size={20} className="text-zinc-500" />
              </button>
            </div>
            
            <div className="p-6 space-y-6">
              <div className="grid grid-cols-4 gap-3 max-h-[300px] overflow-y-auto p-1">
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
                    <span className="text-[9px] font-bold text-center leading-tight">{type}</span>
                  </button>
                ))}
              </div>
              
              <div className="space-y-2">
                <label className="text-xs font-bold text-zinc-900">Description</label>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Tell us what's happening..."
                  className="w-full h-24 p-4 rounded-2xl bg-zinc-50 border border-zinc-200 focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:border-transparent text-sm resize-none transition-all"
                />
              </div>

              <div className="flex flex-col gap-3">
                <div className="flex items-center gap-2 px-4 py-3 bg-zinc-50 rounded-2xl border border-dashed border-zinc-300">
                  <Camera size={16} className="text-zinc-400" />
                  <span className="text-xs text-zinc-500 italic">Photos coming soon to web</span>
                </div>
                
                <button
                  disabled={!selectedType || isSubmitting}
                  onClick={submitReport}
                  className={`w-full py-4 rounded-2xl font-bold flex items-center justify-center gap-2 transition-all ${
                    !selectedType || isSubmitting
                      ? 'bg-zinc-100 text-zinc-400 cursor-not-allowed'
                      : 'bg-red-600 text-white hover:bg-red-700 shadow-xl shadow-red-100 active:scale-95'
                  }`}
                >
                  {isSubmitting ? (
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  ) : (
                    <>
                      <Navigation size={18} />
                      Submit Emergency Report
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

        {/* Global Hazards */}
        {hazards.map((h, i) => {
          const config = disasterTypeConfig[h.type] || { color: '#ef4444', icon: MapPin };
          return (
            <div key={`h-${i}`}>
              <Marker position={h.pos} icon={createCustomIcon(h.type)}>
                <Popup>
                  <div className="p-1">
                    <h3 className="font-bold text-sm text-zinc-900 mb-1">{h.title}</h3>
                    <p className="text-xs text-zinc-600 mb-2">{h.desc}</p>
                  </div>
                </Popup>
              </Marker>
              <Circle
                center={h.pos}
                radius={10000}
                pathOptions={{ fillColor: config.color, color: config.color, fillOpacity: 0.1 }}
              />
            </div>
          )
        })}

        {reports.filter((r: any) => !r.isResolved).map((r: any) => {
          const config = disasterTypeConfig[r.type] || { color: '#6366f1', icon: MapPin };
          const isOwnReport = r.userId === (typeof window !== 'undefined' ? localStorage.getItem('riskqph_user_id') : null);
          return (
            <div key={r.id}>
              <Marker position={[r.latitude, r.longitude]} icon={createCustomIcon(r.type)}>
                <Popup className="report-popup">
                  <div className="w-56 p-1">
                    {r.imageUrl && (
                      <img src={r.imageUrl} alt={r.type} className="w-full h-24 object-cover rounded-lg mb-2" />
                    )}
                    <div className="flex items-center justify-between mb-1">
                      <div className="flex items-center gap-2">
                        <span className="w-2 h-2 rounded-full" style={{ backgroundColor: r.isResolved ? '#22c55e' : config.color }}></span>
                        <h3 className="font-bold text-sm text-zinc-900">{r.type}</h3>
                      </div>
                      {r.isResolved && (
                        <span className="text-[9px] font-bold text-green-600 bg-green-50 px-2 py-0.5 rounded-full border border-green-200">
                          RESOLVED
                        </span>
                      )}
                    </div>
                    <p className="text-[10px] text-zinc-500 mb-2 italic">Reported by {r.reporterName}</p>
                    <p className="text-xs text-zinc-600 line-clamp-2 mb-3">{r.description}</p>

                    <div className="flex items-center justify-between border-t border-zinc-100 pt-3">
                      <div className="flex gap-2">
                        <button
                          onClick={() => handleAction(r.id, 'upvote')}
                          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${isOwnReport
                              ? 'bg-emerald-50 text-emerald-600 pointer-events-none'
                              : 'bg-emerald-50 text-emerald-600 hover:bg-emerald-100 cursor-pointer'
                            }`}
                        >
                          <CheckCircle className="w-3.5 h-3.5" />
                          Agree ({r.upvotes})
                        </button>
                      </div>
                      <button
                        onClick={() => handleAction(r.id, 'flag')}
                        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${isOwnReport
                            ? 'bg-amber-50 text-amber-600 pointer-events-none'
                            : 'bg-amber-50 text-amber-600 hover:bg-amber-100 cursor-pointer'
                          }`}
                      >
                        <Flag className="w-3.5 h-3.5" />
                        Flag
                      </button>
                    </div>

                    {!r.isResolved && (
                      <button
                        onClick={() => handleAction(r.id, 'resolve')}
                        className="w-full mt-3 text-[10px] font-bold py-1.5 rounded-lg border border-green-600 text-green-600 hover:bg-green-600 hover:text-white transition-all"
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
