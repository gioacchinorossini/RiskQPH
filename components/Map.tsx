'use client';

import { MapContainer, TileLayer, Marker, Popup, Circle, Polygon, useMap } from 'react-leaflet';
import L from 'leaflet';
import { useEffect, useState } from 'react';
import { Waves, Flame, Activity, Wind, Mountain, PersonStanding, MapPin, ThumbsUp, ThumbsDown, CheckCircle, Flag } from 'lucide-react';
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
  'Earthquake': { color: '#f97316', icon: Activity },
  'Fire': { color: '#ef4444', icon: Flame },
  'Typhoon': { color: '#06b6d4', icon: Wind },
  'Landslide': { color: '#22c55e', icon: Mountain },
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

const LocationHandler = () => {
  const map = useMap();
  useEffect(() => {
    map.locate({ setView: true, maxZoom: 15 });
    map.on('locationfound', (e) => {
      const userHtml = renderToStaticMarkup(
        <div className="bg-blue-500 rounded-full w-4 h-4 border-2 border-white shadow-lg animate-pulse"></div>
      );
      L.marker(e.latlng, { icon: L.divIcon({ html: userHtml, className: '' }) }).addTo(map).bindPopup("You are here").openPopup();
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

const MapEvents = () => {
  const map = useMap();
  useEffect(() => {
    map.on('moveend zoomend', () => {
      localStorage.setItem('riskqph_map_state', JSON.stringify({
        center: [map.getCenter().lat, map.getCenter().lng],
        zoom: map.getZoom()
      }));
    });
  }, [map]);
  return null;
};

const Map = ({ showBarangays = true }: { showBarangays?: boolean }) => {
  const [reports, setReports] = useState<Report[]>([]);
  const [focusCenter, setFocusCenter] = useState<[number, number] | null>(null);

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

  return (
    <div className="relative h-full w-full">
      {/* Recent Reports Window */}
      <div className="absolute top-4 right-4 z-[1000] w-64 max-h-[80%] bg-white/90 backdrop-blur-md rounded-2xl shadow-2xl border border-zinc-200 overflow-hidden flex flex-col">
        <div className="p-4 bg-zinc-900 text-white">
          <h2 className="text-sm font-bold flex items-center gap-2">
            <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
            Recent Reports
          </h2>
        </div>
        <div className="overflow-y-auto flex-1 p-2 space-y-2">
          {reports.length === 0 ? (
            <p className="text-xs text-zinc-500 text-center py-4">No recent reports found.</p>
          ) : (
            reports.map((r) => {
              const config = disasterTypeConfig[r.type] || { color: '#6366f1', icon: MapPin };
              return (
                <button
                  key={r.id}
                  onClick={() => setFocusCenter([r.latitude, r.longitude])}
                  className="w-full text-left p-2 rounded-xl hover:bg-zinc-100 transition-all border border-transparent hover:border-zinc-200 group"
                >
                  <div className="flex items-center gap-3">
                    <div className="p-2 rounded-lg bg-zinc-100 group-hover:bg-white transition-colors" style={{ color: config.color }}>
                      <config.icon size={14} />
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

      <MapContainer
        center={initialState.center}
        zoom={initialState.zoom}
        scrollWheelZoom={true}

        className="h-full w-full"
      >
        <MapEvents />
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <LocationHandler />
        <FlyToLocation center={focusCenter} />

        {/* Barangay boundaries */}
        {showBarangays && barangaySamples.map((b, i) => {
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
