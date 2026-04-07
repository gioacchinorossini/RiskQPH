'use client';

import { useState, useEffect } from "react";
import MapWrapper from "../components/MapWrapper";
import ThemeToggle from "../components/ThemeToggle";

export default function Home() {
  const [showBarangays, setShowBarangays] = useState(true);
  const [user, setUser] = useState<any>(null);
  const [reports, setReports] = useState<any[]>([]);
  const [stats, setStats] = useState({ active: 0, resolved: 0 });

  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (savedUser) {
      setUser(JSON.parse(savedUser));
    }

    const fetchReports = async () => {
      try {
        const res = await fetch('/api/reports');
        const data = await res.json();
        if (Array.isArray(data)) {
          setReports(data.slice(0, 5)); // Show latest 5
          setStats({
            active: data.filter(r => !r.isResolved).length,
            resolved: data.filter(r => r.isResolved).length
          });
        }
      } catch (e) {
        console.error(e);
      }
    };

    fetchReports();
    const interval = setInterval(fetchReports, 10000);
    return () => clearInterval(interval);
  }, []);

  const getTimeAgo = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffInSeconds < 60) return 'just now';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`;
    return `${Math.floor(diffInSeconds / 86400)}d ago`;
  };

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

          </nav>
          <div className="flex items-center gap-3">
            <ThemeToggle />
            {user ? (
              <div className="flex items-center gap-3">
                <a
                  href={user.role === 'barangay_head' ? '/barangay-head' : '#'}
                  className="hidden h-9 items-center justify-center rounded-full border border-zinc-200 bg-zinc-900 text-white px-4 text-xs font-semibold hover:bg-zinc-800 transition-all md:flex"
                >
                  {user.role === 'barangay_head' ? 'COMMAND CENTER' : 'MY DASHBOARD'}
                </a>
                <button
                  onClick={() => {
                    localStorage.removeItem('user');
                    setUser(null);
                  }}
                  className="h-9 items-center justify-center rounded-full border border-zinc-200 bg-white px-4 text-xs font-semibold text-red-600 transition-all hover:bg-red-50 dark:border-zinc-800 dark:bg-zinc-900 md:flex"
                >
                  Sign Out
                </button>
              </div>
            ) : (
              <a href="/login" className="hidden h-9 items-center justify-center rounded-full border border-zinc-200 bg-white px-4 text-xs font-semibold text-zinc-900 transition-all hover:bg-zinc-50 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-100 md:flex">
                Sign In
              </a>
            )}
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
                <div className="rounded-xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-900 shadow-sm">
                  <p className="text-xs text-zinc-500 dark:text-zinc-400">Active Reports</p>
                  <p className="text-2xl font-bold text-red-600 tracking-tighter">{stats.active}</p>
                </div>
                <div className="rounded-xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-900 shadow-sm">
                  <p className="text-xs text-zinc-500 dark:text-zinc-400">Resolved</p>
                  <p className="text-2xl font-bold text-emerald-600 tracking-tighter">{stats.resolved}</p>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xs font-bold uppercase tracking-wider text-zinc-400 mb-4">Live Activity</h2>
              <div className="space-y-3">
                {reports.length === 0 ? (
                  <div className="text-center py-8 bg-white dark:bg-zinc-900 rounded-2xl border border-dashed border-zinc-200 dark:border-zinc-800">
                    <p className="text-xs text-zinc-500">No active incidents reported</p>
                  </div>
                ) : (
                  reports.map((report, i) => {
                    const isResolved = report.isResolved;
                    return (
                      <div key={report.id} className="group flex items-start justify-between rounded-xl border border-zinc-100 bg-white p-4 transition-all hover:border-zinc-300 dark:border-zinc-800 dark:bg-zinc-900 shadow-sm">
                        <div className="min-w-0 pr-2">
                          <div className="flex items-center gap-2 mb-1">
                            <span className={`w-1.5 h-1.5 rounded-full ${isResolved ? 'bg-emerald-500' : 'bg-red-500 animate-pulse'}`} />
                            <h3 className="text-sm font-bold text-zinc-900 dark:text-zinc-100 truncate">{report.type}</h3>
                          </div>
                          <p className="text-[11px] text-zinc-500 dark:text-zinc-400 line-clamp-1">{report.description || 'No details provided'}</p>
                          <p className="text-[10px] text-zinc-400 mt-2 font-medium">{getTimeAgo(report.createdAt)}</p>
                        </div>
                        <span className={`flex-shrink-0 rounded-full px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider ${isResolved ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-900/20 dark:text-emerald-400' : 'bg-red-50 text-red-700 dark:bg-red-900/20 dark:text-red-400'}`}>
                          {isResolved ? 'Resolved' : 'Active'}
                        </span>
                      </div>
                    );
                  })
                )}
              </div>
              {reports.length > 0 && (
                <button className="w-full mt-4 text-[10px] font-bold text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 transition-colors uppercase tracking-widest">
                  View All Reports
                </button>
              )}
            </section>

          </div>
        </aside>

        <section className="flex-1 relative">
          <MapWrapper showBarangays={showBarangays} />
        </section>
      </main>
    </div>
  );
}
