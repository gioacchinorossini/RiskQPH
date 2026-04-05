'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { 
  UserPlus, 
  ArrowLeft, 
  Activity, 
  MapPin, 
  ShieldCheck, 
  Loader2, 
  Mail, 
  Lock, 
  User, 
  Calendar,
  ChevronRight,
  ShieldIcon,
  Search
} from 'lucide-react';

export default function AddUserPage() {
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const router = useRouter();

  const [formData, setFormData] = useState({
    email: '',
    password: '',
    firstName: '',
    lastName: '',
    middleName: '',
    birthdate: '',
    gender: 'MALE',
    address: '',
    latitude: 14.5995,
    longitude: 120.9842,
    role: 'resident',
  });

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
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    
    try {
      const res = await fetch('/api/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...formData,
          barangay: user.barangay,
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'Registration failed');

      setSuccess(true);
      setTimeout(() => {
        router.push('/barangay-head');
      }, 2000);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-black font-sans selection:bg-red-600 selection:text-white">
      {/* Navigation Header */}
      <nav className="h-20 border-b border-zinc-200 dark:border-zinc-800 bg-white/80 dark:bg-zinc-950/80 backdrop-blur-md sticky top-0 z-50 px-6 lg:px-12 flex items-center justify-between">
         <button 
           onClick={() => router.back()}
           className="flex items-center gap-2 text-xs font-black uppercase tracking-widest text-zinc-500 hover:text-black dark:hover:text-white transition-colors"
         >
           <ArrowLeft size={16} />
           Back to Radar
         </button>
         
         <div className="flex items-center gap-3">
             <div className="h-8 w-8 rounded-lg bg-red-600 flex items-center justify-center rotate-3">
               <span className="text-white font-black italic tracking-tighter text-xs">RQ</span>
             </div>
             <p className="text-[10px] font-black tracking-widest uppercase opacity-40">Add New Account</p>
         </div>
      </nav>

      <main className="max-w-4xl mx-auto p-6 lg:py-20">
        <header className="mb-12 text-center space-y-4">
           <div className="h-20 w-20 rounded-3xl bg-zinc-900 dark:bg-white text-white dark:text-black flex items-center justify-center mx-auto shadow-2xl mb-6">
              <UserPlus size={40} strokeWidth={2.5} />
           </div>
           <h1 className="text-4xl lg:text-6xl font-black tracking-tighter uppercase leading-none">Add <span className="text-red-600 italic">User</span></h1>
           <p className="text-xs font-black uppercase tracking-[0.3em] text-zinc-400">Jurisdictional Registration Form</p>
        </header>

        {error && (
          <div className="mb-8 p-6 rounded-3xl bg-red-50 border border-red-200 text-red-600 flex items-center gap-4 animate-in fade-in zoom-in-95 duration-300">
             <ShieldIcon size={24} />
             <p className="text-xs font-black uppercase tracking-widest">{error}</p>
          </div>
        )}

        {success && (
          <div className="mb-8 p-12 rounded-[3.5rem] bg-emerald-600 text-white text-center space-y-6 shadow-2xl shadow-emerald-500/20 animate-in fade-in zoom-in-95 duration-500">
             <ShieldCheck size={64} className="mx-auto" />
             <h2 className="text-2xl font-black uppercase tracking-widest">Resident Added Successfully</h2>
             <p className="text-[10px] font-black uppercase tracking-[0.2em] opacity-80">Syncing database and redirecting...</p>
          </div>
        )}

        {!success && (
          <form onSubmit={handleSubmit} className="space-y-12">
            {/* Role Assignment */}
            <section className="bg-white dark:bg-zinc-950 p-10 lg:p-14 rounded-[3.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl space-y-10">
               <div className="flex items-center gap-4 border-b border-zinc-100 dark:border-zinc-900 pb-6">
                  <div className="h-10 w-10 rounded-xl bg-zinc-100 dark:bg-zinc-900 flex items-center justify-center text-zinc-500">
                     <ShieldIcon size={20} />
                  </div>
                  <div>
                    <h3 className="text-sm font-black uppercase tracking-widest">Account Type</h3>
                    <p className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">Select user responsibility level</p>
                  </div>
               </div>

               <div className="grid grid-cols-2 gap-4">
                  {[
                    { id: 'resident', label: 'Resident' },
                    { id: 'responder', label: 'Responder' },
                  ].map((role) => (
                    <button
                      key={role.id}
                      type="button"
                      onClick={() => setFormData({ ...formData, role: role.id })}
                      className={`h-14 rounded-2xl border transition-all text-[9px] font-black uppercase tracking-widest ${
                        (formData.role || 'resident') === role.id 
                          ? 'bg-red-600 border-red-600 text-white shadow-xl shadow-red-600/20' 
                          : 'bg-zinc-50 dark:bg-zinc-900 border-zinc-200 dark:border-zinc-800 text-zinc-500 hover:border-red-600/30'
                      }`}
                    >
                       {role.label}
                    </button>
                  ))}
               </div>
            </section>

            {/* Form Section: Identity */}
            <section className="bg-white dark:bg-zinc-950 p-10 lg:p-14 rounded-[3.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl space-y-10">
               <div className="flex items-center gap-4 border-b border-zinc-100 dark:border-zinc-900 pb-6">
                  <div className="h-10 w-10 rounded-xl bg-zinc-100 dark:bg-zinc-900 flex items-center justify-center text-zinc-500">
                     <User size={20} />
                  </div>
                  <div>
                    <h3 className="text-sm font-black uppercase tracking-widest">Personal Identification</h3>
                    <p className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">Legal name and identity details</p>
                  </div>
               </div>

               <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">First Name</label>
                     <input 
                       required
                       placeholder="JOHN"
                       value={formData.firstName}
                       onChange={(e) => setFormData({...formData, firstName: e.target.value.toUpperCase()})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                     />
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Last Name</label>
                     <input 
                       required
                       placeholder="DOE"
                       value={formData.lastName}
                       onChange={(e) => setFormData({...formData, lastName: e.target.value.toUpperCase()})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                     />
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Middle Initial</label>
                     <input 
                       placeholder="SMITH"
                       value={formData.middleName}
                       onChange={(e) => setFormData({...formData, middleName: e.target.value.toUpperCase()})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                     />
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Gender</label>
                     <select 
                       value={formData.gender}
                       onChange={(e) => setFormData({...formData, gender: e.target.value})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-[10px] font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                     >
                       <option value="MALE">MALE</option>
                       <option value="FEMALE">FEMALE</option>
                       <option value="OTHER">OTHER</option>
                     </select>
                  </div>
                  <div className="md:col-span-2 space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Birthdate</label>
                     <div className="relative">
                        <Calendar className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-400" size={16} />
                        <input 
                          type="date"
                          required
                          value={formData.birthdate}
                          onChange={(e) => setFormData({...formData, birthdate: e.target.value})}
                          className="w-full h-14 pl-14 pr-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                        />
                     </div>
                  </div>
               </div>
            </section>

            {/* Form Section: Credentials */}
            <section className="bg-white dark:bg-zinc-950 p-10 lg:p-14 rounded-[3.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl space-y-10">
               <div className="flex items-center gap-4 border-b border-zinc-100 dark:border-zinc-900 pb-6">
                  <div className="h-10 w-10 rounded-xl bg-zinc-100 dark:bg-zinc-900 flex items-center justify-center text-zinc-500">
                     <Lock size={20} />
                  </div>
                  <div>
                    <h3 className="text-sm font-black uppercase tracking-widest">Access Credentials</h3>
                    <p className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">Login and security parameters</p>
                  </div>
               </div>

               <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Email Address</label>
                     <div className="relative">
                        <Mail className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-400" size={16} />
                        <input 
                          type="email"
                          required
                          placeholder="EMAIL@RISKQPH.GOV"
                          value={formData.email}
                          onChange={(e) => setFormData({...formData, email: e.target.value})}
                          className="w-full h-14 pl-14 pr-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                        />
                     </div>
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Temporary Password</label>
                     <div className="relative">
                        <Lock className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-400" size={16} />
                        <input 
                          type="password"
                          required
                          placeholder="••••••••"
                          value={formData.password}
                          onChange={(e) => setFormData({...formData, password: e.target.value})}
                          className="w-full h-14 pl-14 pr-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                        />
                     </div>
                  </div>
               </div>
            </section>

            {/* Form Section: Residency */}
            <section className="bg-white dark:bg-zinc-950 p-10 lg:p-14 rounded-[3.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl space-y-10">
               <div className="flex items-center gap-4 border-b border-zinc-100 dark:border-zinc-900 pb-6">
                  <div className="h-10 w-10 rounded-xl bg-zinc-100 dark:bg-zinc-900 flex items-center justify-center text-zinc-500">
                     <MapPin size={20} />
                  </div>
                  <div>
                    <h3 className="text-sm font-black uppercase tracking-widest">Residency & Location</h3>
                    <p className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">Physical address within jurisdiction</p>
                  </div>
               </div>

               <div className="space-y-8">
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Street Address / Household No.</label>
                     <textarea 
                       required
                       placeholder="UNIT 101, BLK 3, BARANGAY STREET"
                       value={formData.address}
                       onChange={(e) => setFormData({...formData, address: e.target.value.toUpperCase()})}
                       className="w-full h-28 p-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all resize-none shadow-inner"
                     />
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-8 opacity-40 select-none pointer-events-none">
                     <div className="space-y-2">
                        <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Assigned Barangay</label>
                        <input disabled value={`BRGY. ${user?.barangay}`} className="w-full h-14 px-6 rounded-2xl border border-zinc-200 bg-zinc-50 text-xs font-black uppercase tracking-widest" />
                     </div>
                     <div className="space-y-2">
                        <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Jurisdiction Lock</label>
                        <div className="w-full h-14 px-6 rounded-2xl border border-emerald-100 bg-emerald-50 text-emerald-600 text-[9px] font-black uppercase tracking-widest flex items-center gap-2">
                           <ShieldCheck size={14} />
                           System Verified
                        </div>
                     </div>
                  </div>
               </div>
            </section>

            <button
              type="submit"
              disabled={loading}
              className="w-full h-20 rounded-[2rem] bg-zinc-900 dark:bg-white text-white dark:text-black font-black uppercase tracking-[0.3em] text-xs hover:bg-black dark:hover:bg-zinc-200 transition-all flex items-center justify-center gap-4 shadow-2xl relative group overflow-hidden"
            >
              {loading ? (
                <Loader2 className="animate-spin" />
              ) : (
                <>
                  <div className="absolute inset-0 bg-red-600 translate-y-full group-hover:translate-y-0 transition-transform duration-500"></div>
                  <span className="relative z-10">Add User</span>
                  <ChevronRight className="relative z-10 group-hover:translate-x-2 transition-transform" size={20} />
                </>
              )}
            </button>
          </form>
        )}
      </main>
    </div>
  );
}
