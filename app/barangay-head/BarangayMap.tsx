'use client';

import { MapContainer, TileLayer, Marker, Popup, Circle, useMap, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import { useEffect, useState } from 'react';
import { User, ShieldCheck, ShieldAlert, MapPin, Landmark } from 'lucide-react';
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

const MapClickHandler = ({ onMapClick }: { onMapClick?: (lat: number, lng: number) => void }) => {
  useMapEvents({
    click(e) {
      if (onMapClick) onMapClick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
};

const FlyToLocation = ({ center }: { center: [number, number] | null }) => {
  const map = useMap();
  useEffect(() => {
    if (center) {
      map.flyTo(center, 16, { duration: 1.5 });
    }
  }, [center, map]);
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

export default function BarangayMap({ 
  residents, 
  isActive, 
  focusResident,
  hqLocation,
  onMapClick,
  barangayName
}: { 
  residents: Resident[], 
  isActive: boolean,
  focusResident?: Resident | null,
  hqLocation?: { lat: number, lng: number } | null,
  onMapClick?: (lat: number, lng: number) => void,
  barangayName?: string
}) {
  useEffect(() => {
    fixLeafletIcon();
  }, []);

  const validResidents = residents.filter(r => r.latitude && r.longitude);
  const center: [number, number] = focusResident?.latitude && focusResident?.longitude 
    ? [focusResident.latitude, focusResident.longitude]
    : validResidents.length > 0 
      ? [validResidents[0].latitude!, validResidents[0].longitude!]
      : [12.8797, 121.7740];

  return (
    <div className="h-full w-full rounded-3xl overflow-hidden border border-zinc-200 dark:border-zinc-800 shadow-inner">
      <MapContainer
        center={center}
        zoom={validResidents.length > 0 ? 15 : 6}
        scrollWheelZoom={true}
        className="h-full w-full"
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <FlyToLocation center={focusResident?.latitude && focusResident?.longitude ? [focusResident.latitude, focusResident.longitude] : (hqLocation ? [hqLocation.lat, hqLocation.lng] : null)} />
        <MapClickHandler onMapClick={onMapClick} />

        {hqLocation && (
           <Marker 
             position={[hqLocation.lat, hqLocation.lng]} 
             icon={createBarangayIcon()}
           >
             <Popup>
               <div className="p-3">
                 <p className="text-[10px] font-black uppercase text-red-600 mb-1">COMMAND HEADQUARTERS</p>
                 <p className="font-bold text-sm text-zinc-900 leading-none capitalize">Brgy. {barangayName || 'Hall'}</p>
                 <p className="text-[9px] text-zinc-500 mt-2 italic px-2 py-1 bg-zinc-100 rounded border border-zinc-200">Official coordination hub for emergency protocols.</p>
               </div>
             </Popup>
           </Marker>
        )}

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
                  {isActive ? (r.isSafe ? 'MARKED SAFE' : 'STATUS PENDING') : 'MONITORING IDLE'}
                </div>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
