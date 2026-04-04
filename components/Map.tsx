'use client';

import { MapContainer, TileLayer, Marker, Popup, Circle, useMap } from 'react-leaflet';
import L from 'leaflet';
import { useEffect } from 'react';

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

const redIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const orangeIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-orange.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const blueIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const LocationHandler = () => {
  const map = useMap();
  
  useEffect(() => {
    map.locate({ setView: true, maxZoom: 18 });
    
    map.on('locationfound', (e) => {
      L.marker(e.latlng).addTo(map)
        .bindPopup("You are here")
        .openPopup();
    });

    map.on('locationerror', (e) => {
      console.warn("Location error:", e.message);
    });
  }, [map]);

  return null;
};

const Map = () => {
  useEffect(() => {
    fixLeafletIcon();
  }, []);

  const hazards = [
    { pos: [14.5995, 120.9842] as [number, number], title: "Manila Region", desc: "Critical Flooding potential in NCR.", icon: redIcon, color: "#ef4444" },
    { pos: [10.3157, 123.8854] as [number, number], title: "Cebu City", desc: "Moderate Storm Surge warning.", icon: orangeIcon, color: "#f97316" },
    { pos: [7.0736, 125.6128] as [number, number], title: "Davao Region", desc: "Minor Seismic Activity recorded.", icon: blueIcon, color: "#3b82f6" }
  ];

  return (
    <div className="map-container">
      <MapContainer 
        center={[12.8797, 121.7740]} 
        zoom={15} 
        scrollWheelZoom={true}
        className="h-full w-full"
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <LocationHandler />
        {hazards.map((h, i) => (
          <div key={i}>
            <Marker position={h.pos} icon={h.icon}>
              <Popup>
                <div className="p-1">
                  <h3 className="font-bold text-sm text-zinc-900 mb-1">{h.title}</h3>
                  <p className="text-xs text-zinc-600 mb-2">{h.desc}</p>
                  <button className="text-[10px] bg-zinc-900 text-white px-2 py-1 rounded" style={{ backgroundColor: h.color }}>
                    View Full Details
                  </button>
                </div>
              </Popup>
            </Marker>
            <Circle 
              center={h.pos}
              radius={20000}
              pathOptions={{ fillColor: h.color, color: h.color, fillOpacity: 0.2 }}
            />
          </div>
        ))}
      </MapContainer>
    </div>
  );
};

export default Map;
