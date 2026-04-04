'use client';

import { useState } from "react";
import MapWrapper from "../components/MapWrapper";

export default function Home() {
  const [showBarangays, setShowBarangays] = useState(true);

  return (
    <div className="flex min-h-screen flex-col bg-white dark:bg-black font-sans antialiased selection:bg-zinc-900 selection:text-white">
      <header className="fixed top-0 z-50 w-full border-b border-zinc-200 bg-white/80 dark:bg-black/80 backdrop-blur-md dark:border-zinc-800">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded bg-red-600 flex items-center justify-center">
              <span className="text-white font-bold italic tracking-tighter">RQ</span>
            </div>
            <h1 className="text-xl font-bold tracking-tight text-zinc-900 dark:text-zinc-50">
              RiskQPH <span className="font-light text-zinc-500">Hazard Tracker</span>
            </h1>
          </div>
          <nav className="hidden items-center gap-8 md:flex">
            <a href="#" className="text-sm font-medium text-zinc-900 dark:text-zinc-400 hover:text-red-500 dark:hover:text-zinc-100 transition-colors">Emergency</a>
            <a href="#" className="text-sm font-medium text-zinc-500 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors">Dashboards</a>
            <a href="#" className="text-sm font-medium text-zinc-500 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors">Resources</a>
          </nav>
          <div className="flex items-center gap-4">
            <button className="hidden h-9 items-center justify-center rounded-full border border-zinc-200 bg-white px-4 text-xs font-semibold text-zinc-900 transition-all hover:bg-zinc-50 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-100 md:flex">
              Sign In
            </button>
            <button className="flex h-9 items-center justify-center rounded-full bg-red-600 px-4 text-xs font-bold text-white transition-all hover:bg-red-700">
              Report Hazard
            </button>
          </div>
        </div>
      </header>

      <main className="mt-16 flex-1 flex flex-col xl:flex-row h-[calc(100vh-64px)] overflow-hidden">
        {/* Sidebar */}
        <aside className="w-full xl:w-[400px] border-r border-zinc-200 bg-zinc-50 dark:bg-zinc-950 dark:border-zinc-800 overflow-y-auto p-6">
          <div className="space-y-8">
            <section>
              <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-400 mb-4">Quick Stats</h2>
              <div className="grid grid-cols-2 gap-4">
                <div className="rounded-xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-900">
                  <p className="text-xs text-zinc-500 dark:text-zinc-400">Active Warning</p>
                  <p className="text-2xl font-bold text-red-600">32</p>
                </div>
                <div className="rounded-xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-900">
                  <p className="text-xs text-zinc-500 dark:text-zinc-400">Safe Areas</p>
                  <p className="text-2xl font-bold text-emerald-600">854</p>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-400 mb-4">Current Hazards</h2>
              <div className="space-y-3">
                {[
                  { name: "Luzon Flooding", status: "Critical", time: "2h ago", color: "bg-red-100 text-red-700" },
                  { name: "Mindanao Seismic Activity", status: "Moderate", time: "5h ago", color: "bg-orange-100 text-orange-700" },
                  { name: "Visayas Storm Watch", status: "Low Risk", time: "12h ago", color: "bg-blue-100 text-blue-700" },
                ].map((hazard, i) => (
                  <div key={i} className="flex items-center justify-between rounded-xl border border-zinc-100 bg-white p-4 transition-all hover:border-zinc-200 dark:border-zinc-800 dark:bg-zinc-900 shadow-sm">
                    <div>
                      <h3 className="text-sm font-semibold text-zinc-900 dark:text-zinc-100">{hazard.name}</h3>
                      <p className="text-xs text-zinc-500">{hazard.time}</p>
                    </div>
                    <span className={`rounded-full px-2 py-1 text-[10px] font-bold ${hazard.color}`}>
                      {hazard.status}
                    </span>
                  </div>
                ))}
              </div>
            </section>
            
            <section className="rounded-2xl bg-zinc-900 p-6 text-white dark:bg-zinc-100 dark:text-black">
              <h3 className="text-lg font-bold mb-2">Join Voluntaris</h3>
              <p className="text-xs text-zinc-400 dark:text-zinc-600 mb-4 leading-relaxed">
                Be part of the community-led hazard monitoring network across the Philippines.
              </p>
              <button className="w-full rounded-xl bg-white py-3 text-xs font-bold text-black transition-opacity hover:opacity-90 dark:bg-black dark:text-white">
                Learn More
              </button>
            </section>
          </div>
        </aside>

        {/* Map Container */}
        <section className="flex-1 relative">
          <div className="absolute top-6 right-6 z-40 bg-white/90 dark:bg-black/90 backdrop-blur-md rounded-xl shadow-xl border border-zinc-200 dark:border-zinc-800 p-4 w-64">
            <h4 className="text-sm font-bold mb-3">Map Layers</h4>
            <div className="space-y-2">
              <label className="flex items-center gap-3 cursor-pointer">
                <input type="checkbox" defaultChecked className="h-4 w-4 rounded border-zinc-300 accent-red-600" />
                <span className="text-xs font-medium text-zinc-700 dark:text-zinc-300">Hazard Zones</span>
              </label>
              <label className="flex items-center gap-3 cursor-pointer">
                <input type="checkbox" defaultChecked className="h-4 w-4 rounded border-zinc-300 accent-red-600" />
                <span className="text-xs font-medium text-zinc-700 dark:text-zinc-300">Organized Shelters</span>
              </label>
              <label className="flex items-center gap-3 cursor-pointer">
                <input 
                  type="checkbox" 
                  checked={showBarangays}
                  onChange={(e) => setShowBarangays(e.target.checked)}
                  className="h-4 w-4 rounded border-zinc-300 accent-red-600" 
                />
                <span className="text-xs font-medium text-zinc-700 dark:text-zinc-300">Barangay Boundaries</span>
              </label>
              <label className="flex items-center gap-3 cursor-pointer">
                <input type="checkbox" className="h-4 w-4 rounded border-zinc-300 accent-red-600" />
                <span className="text-xs font-medium text-zinc-700 dark:text-zinc-300">Real-time Traffic</span>
              </label>
            </div>
          </div>
          
          <MapWrapper showBarangays={showBarangays} />
          
          <div className="absolute bottom-6 left-6 z-40 bg-red-600 text-white px-4 py-2 rounded-full shadow-lg text-xs font-bold animate-pulse">
            LIVE SIGNAL: Regional Monitoring Active
          </div>
        </section>
      </main>
    </div>
  );
}
