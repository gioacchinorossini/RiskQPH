'use client';

import { useState, useEffect, useMemo } from 'react';
import { 
  Users, 
  AlertTriangle, 
  Activity, 
  BarChart, 
  PieChart as PieChartIcon, 
  TrendingUp, 
  Clock, 
  ShieldCheck, 
  ShieldAlert,
  Landmark,
  ArrowUpRight,
  ArrowDownRight,
  Target,
  Zap,
  Loader2
} from 'lucide-react';
import { 
  BarChart as ReBarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer, 
  Cell,
  PieChart,
  Pie,
  AreaChart,
  Area
} from 'recharts';

interface AnalyticsData {
  residents: {
    total: number;
    verified: number;
    pending: number;
    gender: Array<{ gender: string; _count: number }>;
  };
  reports: {
    byType: Array<{ type: string; _count: number }>;
    recent: any[];
  };
  disasters: {
    byType: Array<{ type: string; _count: number }>;
    lastDisaster: {
      type: string | null;
      isActive: boolean;
      safetyRate: string;
      totalReports: number;
    } | null;
  };
  evacuation: Array<{
    name: string;
    capacity: number | null;
    current: number;
    occupancy: string;
  }>;
}

const COLORS = ['#dc2626', '#10b981', '#3b82f6', '#f59e0b', '#8b5cf6', '#ec4899', '#71717a'];

export default function AnalyticsDashboard({ barangay }: { barangay: string }) {
  const [data, setData] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function fetchAnalytics() {
      try {
        const res = await fetch(`/api/barangay/analytics?barangay=${barangay}`);
        if (!res.ok) throw new Error('Failed to fetch analytics');
        const json = await res.json();
        setData(json);
      } catch (err) {
        console.error(err);
        setError('Failed to load analytics data');
      } finally {
        setLoading(false);
      }
    }
    fetchAnalytics();
  }, [barangay]);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-4 opacity-50">
        <Loader2 className="animate-spin text-zinc-400" size={32} />
        <p className="text-[10px] font-black uppercase tracking-[0.3em]">ANALYZING JURISDICTION DATA...</p>
      </div>
    );
  }

  if (!data) return null;

  const residentStats = [
    { label: 'Total Citizens', value: data.residents.total, icon: Users, color: 'text-zinc-900 dark:text-white', bg: 'bg-zinc-100 dark:bg-zinc-800' },
    { label: 'Verified Accounts', value: data.residents.verified, icon: ShieldCheck, color: 'text-emerald-600', bg: 'bg-emerald-50 dark:bg-emerald-900/10' },
    { label: 'Pending Approval', value: data.residents.pending, icon: Clock, color: 'text-amber-600', bg: 'bg-amber-50 dark:bg-amber-900/10' },
    { label: 'Incident Reports', value: data.reports.recent.length, icon: AlertTriangle, color: 'text-red-600', bg: 'bg-red-50 dark:bg-red-900/10' },
  ];

  const reportChartData = data.reports.byType.map(r => ({
    name: r.type,
    value: r._count
  }));

  const genderChartData = data.residents.gender.map(g => ({
    name: g.gender || 'Not Specified',
    value: g._count
  }));

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Top Banner Stats */}
      <section className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {residentStats.map((stat, i) => (
          <div key={i} className="p-8 rounded-[2.5rem] border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 shadow-sm relative overflow-hidden group hover:shadow-xl hover:-translate-y-1 transition-all">
            <div className={`h-12 w-12 ${stat.bg} ${stat.color} rounded-2xl flex items-center justify-center mb-6 transition-transform group-hover:scale-110 group-hover:rotate-3`}>
              <stat.icon size={24} strokeWidth={2.5} />
            </div>
            <div className="flex flex-col">
              <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1">{stat.label}</p>
              <p className="text-4xl font-black tracking-tighter">{stat.value}</p>
            </div>
            <div className="absolute top-0 right-0 p-8 opacity-[0.03] select-none pointer-events-none">
              <stat.icon size={120} strokeWidth={1} />
            </div>
          </div>
        ))}
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Incident Type Analysis */}
        <div className="lg:col-span-8 p-10 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 shadow-2xl relative overflow-hidden">
          <header className="mb-10 flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-red-600 text-white rounded-2xl">
                <BarChart size={20} />
              </div>
              <div>
                <h3 className="text-sm font-black uppercase tracking-widest">Incident Frequency Analysis</h3>
                <p className="text-[9px] font-black tracking-widest text-zinc-400">DISTRIBUTION BY CATEGORY ACROSS BARANGAY</p>
              </div>
            </div>
            <div className="flex items-center gap-2 px-4 py-2 bg-zinc-100 dark:bg-zinc-900 rounded-xl">
              <TrendingUp size={12} className="text-red-600" />
              <span className="text-[9px] font-black uppercase tracking-widest">LIVE ANALYTICS</span>
            </div>
          </header>

          <div className="h-[400px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <ReBarChart data={reportChartData} margin={{ top: 20, right: 30, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e4e4e7" />
                <XAxis 
                  dataKey="name" 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fontSize: 9, fontWeight: 900, fill: '#71717a' }}
                  dy={10}
                />
                <YAxis 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fontSize: 9, fontWeight: 900, fill: '#71717a' }}
                />
                <Tooltip 
                  contentStyle={{ 
                    backgroundColor: '#000', 
                    border: 'none', 
                    borderRadius: '1.5rem',
                    padding: '12px 20px',
                    color: '#fff',
                    boxShadow: '0 20px 25px -5px rgb(0 0 0 / 0.1)'
                  }}
                  itemStyle={{ color: '#fff', fontSize: '10px', textTransform: 'uppercase', fontWeight: 900 }}
                  labelStyle={{ display: 'none' }}
                />
                <Bar dataKey="value" radius={[12, 12, 0, 0]} barSize={40}>
                  {reportChartData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Bar>
              </ReBarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Demographic Breakdown */}
        <div className="lg:col-span-4 p-10 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 shadow-2xl overflow-hidden">
          <header className="mb-10">
            <div className="flex items-center gap-4 mb-2">
              <div className="p-3 bg-zinc-900 dark:bg-white text-white dark:text-black rounded-2xl">
                <PieChartIcon size={20} />
              </div>
              <h3 className="text-sm font-black uppercase tracking-widest">Demographics</h3>
            </div>
            <p className="text-[9px] font-black tracking-widest text-zinc-400">CITIZEN GENDER RATIO</p>
          </header>

          <div className="h-[250px] relative">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={genderChartData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={100}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {genderChartData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} stroke="transparent" />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-center pointer-events-none">
              <p className="text-2xl font-black tracking-tighter">{data.residents.total}</p>
              <p className="text-[8px] font-black uppercase text-zinc-500">RESIDENTS</p>
            </div>
          </div>

          <div className="mt-8 space-y-4">
            {genderChartData.map((item, i) => (
              <div key={i} className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-3 h-3 rounded-full" style={{ backgroundColor: COLORS[i % COLORS.length] }}></div>
                  <span className="text-[10px] font-black uppercase tracking-widest text-zinc-500">{item.name}</span>
                </div>
                <span className="text-[10px] font-black uppercase tracking-widest">{((item.value / data.residents.total) * 100).toFixed(0)}%</span>
              </div>
            ))}
          </div>
        </div>

        {/* Disaster Success Metric */}
        <div className="lg:col-span-12 grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="p-10 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 bg-black text-white shadow-2xl relative overflow-hidden group">
            <div className="relative z-10">
              <span className="inline-block px-3 py-1 bg-red-600 rounded-lg text-[9px] font-black uppercase tracking-widest mb-6">Last Response Protocol</span>
              <h4 className="text-3xl font-black tracking-tighter uppercase mb-4 leading-none">
                {data.disasters.lastDisaster?.safetyRate}% <span className="text-red-500 italic">Survival</span> Success
              </h4>
              <p className="text-[10px] font-black tracking-widest text-zinc-400 uppercase leading-relaxed mb-10 max-w-[240px]">
                Calculated efficiency during "{data.disasters.lastDisaster?.type || 'No Event'}" protocol execution.
              </p>
              <div className="flex items-center gap-6">
                <div className="flex flex-col">
                  <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1">Impact Radius</p>
                  <p className="text-xl font-black tracking-tighter">Jurisdiction-Wide</p>
                </div>
                <div className="flex flex-col">
                  <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1">Extraction Rate</p>
                  <p className="text-xl font-black tracking-tighter">Normal</p>
                </div>
              </div>
            </div>
            <div className="absolute top-0 right-0 p-10 opacity-10 group-hover:scale-110 transition-transform duration-500">
              <Target size={180} strokeWidth={1} />
            </div>
          </div>

          <div className="lg:col-span-2 p-10 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 shadow-2xl relative overflow-hidden">
            <header className="mb-10 flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="p-3 bg-emerald-600 text-white rounded-2xl">
                  <Landmark size={20} />
                </div>
                <div>
                  <h3 className="text-sm font-black uppercase tracking-widest">Evacuation Center Analytics</h3>
                  <p className="text-[9px] font-black tracking-widest text-zinc-400">CURRENT CAPACITY VS OCCUPANCY RATE</p>
                </div>
              </div>
            </header>

            <div className="space-y-8">
              {data.evacuation.length > 0 ? data.evacuation.map((ec, i) => (
                <div key={i} className="space-y-3">
                  <div className="flex items-center justify-between">
                    <p className="text-[11px] font-black uppercase tracking-tighter">{ec.name}</p>
                    <div className="flex items-center gap-3">
                      <span className="text-[10px] font-black text-zinc-400 uppercase tracking-widest">{ec.current} / {ec.capacity || '???'}</span>
                      <span className="text-[11px] font-black uppercase tracking-tighter text-emerald-600">{ec.occupancy}%</span>
                    </div>
                  </div>
                  <div className="h-5 w-full bg-zinc-100 dark:bg-zinc-900 rounded-full overflow-hidden p-1 border border-zinc-200 dark:border-zinc-800">
                    <div 
                      className={`h-full rounded-full transition-all duration-1000 ${parseFloat(ec.occupancy) > 90 ? 'bg-red-600' : parseFloat(ec.occupancy) > 70 ? 'bg-amber-600' : 'bg-emerald-600 shadow-[0_0_15px_rgba(16,185,129,0.3)]'}`}
                      style={{ width: `${Math.min(100, parseFloat(ec.occupancy))}%` }}
                    />
                  </div>
                </div>
              )) : (
                <div className="flex flex-col items-center justify-center py-10 opacity-30">
                  <Landmark size={48} strokeWidth={1} />
                  <p className="text-[11px] font-black uppercase mt-4">No Evacuation Centers Established</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Recent Protocols */}
        <div className="lg:col-span-12 p-10 rounded-[3rem] border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-950 shadow-2xl relative overflow-hidden">
          <header className="mb-10 flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-zinc-900 dark:bg-white text-white dark:text-black rounded-2xl">
                <Clock size={20} />
              </div>
              <div>
                <h3 className="text-sm font-black uppercase tracking-widest">Recent Incident Stream</h3>
                <p className="text-[9px] font-black tracking-widest text-zinc-400">REAL-TIME DATA AUDIT LOG</p>
              </div>
            </div>
            <button className="text-[10px] font-black uppercase tracking-widest text-zinc-900 dark:text-white underline underline-offset-8 decoration-red-600 decoration-2">Export Log (CSV)</button>
          </header>

          <div className="space-y-2">
            {data.reports.recent.length > 0 ? data.reports.recent.map((report, i) => (
              <div key={i} className="group p-6 rounded-[1.5rem] bg-zinc-50 dark:bg-zinc-900/50 hover:bg-black hover:text-white dark:hover:bg-white dark:hover:text-black transition-all border border-transparent hover:border-zinc-800 duration-300">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                  <div className="flex items-center gap-6">
                    <span className="text-[10px] font-black tracking-widest text-zinc-400 opacity-60">0{i+1}</span>
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${i % 2 === 0 ? 'bg-red-600/10 text-red-600' : 'bg-amber-600/10 text-amber-600'}`}>
                      <Zap size={18} fill="currentColor" />
                    </div>
                    <div>
                      <p className="text-xs font-black uppercase tracking-tight">{report.type}</p>
                      <p className="text-[9px] font-bold text-zinc-500 uppercase tracking-widest truncate max-w-[300px]">{report.description || 'No description provided.'}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-8">
                    <div className="flex flex-col items-end">
                      <p className="text-[9px] font-black uppercase tracking-widest">Reporter</p>
                      <p className="text-[10px] font-bold opacity-60 uppercase">{report.user?.firstName} {report.user?.lastName}</p>
                    </div>
                    <div className="flex flex-col items-end">
                      <p className="text-[9px] font-black uppercase tracking-widest">Timestamp</p>
                      <p className="text-[10px] font-bold opacity-60 uppercase">{new Date(report.createdAt).toLocaleTimeString()}</p>
                    </div>
                    <button className="h-10 w-10 flex items-center justify-center rounded-xl bg-white dark:bg-zinc-800 text-zinc-900 dark:text-white group-hover:bg-red-600 group-hover:text-white transition-colors">
                      <ArrowUpRight size={18} />
                    </button>
                  </div>
                </div>
              </div>
            )) : (
              <p className="text-[11px] font-black uppercase text-center py-20 opacity-30">No recent incidents detected within jurisdiction</p>
            )}
          </div>
        </div>
      </section>
    </div>
  );
}
