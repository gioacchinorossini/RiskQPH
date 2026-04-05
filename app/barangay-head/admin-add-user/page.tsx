'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { 
  UserPlus, 
  ArrowLeft, 
  ShieldAlert, 
  ShieldCheck, 
  Loader2, 
  Mail, 
  Lock, 
  User, 
  ChevronRight,
  ShieldIcon,
  Globe,
  Briefcase
} from 'lucide-react';

export default function AdminAddUserPage() {
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const router = useRouter();

  const [formData, setFormData] = useState({
    email: '',
    password: '',
    firstName: '',
    lastName: '',
    role: 'responder', // Default to responder for administrative addition
    barangay: '',
  });

  useEffect(() => {
    const savedUser = localStorage.getItem('user');
    if (!savedUser) {
      router.push('/login');
      return;
    }
    const parsed = JSON.parse(savedUser);
    // Allowing barangay_head to access this temporary "admin" feature as requested
    setCurrentUser(parsed);
    if (parsed.barangay) {
      setFormData(prev => ({ ...prev, barangay: parsed.barangay }));
    }
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    
    try {
      const res = await fetch('/api/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'Administrative registration failed');

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
    <div className="min-h-screen bg-zinc-50 dark:bg-black font-sans selection:bg-black selection:text-white">
      {/* Navigation Header */}
      <nav className="h-20 border-b border-zinc-200 dark:border-zinc-800 bg-white/80 dark:bg-zinc-950/80 backdrop-blur-md sticky top-0 z-50 px-6 lg:px-12 flex items-center justify-between">
         <button 
           onClick={() => router.back()}
           className="flex items-center gap-2 text-xs font-black uppercase tracking-widest text-zinc-500 hover:text-black dark:hover:text-white transition-colors"
         >
           <ArrowLeft size={16} />
           Exit Admin Dashboard
         </button>
         
         <div className="flex items-center gap-3">
             <div className="h-8 w-8 rounded-lg bg-zinc-900 dark:bg-white text-white dark:text-black flex items-center justify-center rotate-3">
               <ShieldAlert size={16} />
             </div>
             <p className="text-[10px] font-black tracking-widest uppercase opacity-40 italic">System Administration</p>
         </div>
      </nav>

      <main className="max-w-4xl mx-auto p-6 lg:py-20">
        <header className="mb-12 text-center space-y-4">
           <div className="h-20 w-20 rounded-3xl bg-red-600 text-white flex items-center justify-center mx-auto shadow-2xl mb-6 shadow-red-600/20">
              <ShieldIcon size={40} strokeWidth={2.5} />
           </div>
           <h1 className="text-4xl lg:text-6xl font-black tracking-tighter uppercase leading-none">Add <span className="text-red-600 italic">User</span></h1>
           <p className="text-xs font-black uppercase tracking-[0.3em] text-zinc-400">Account Role: <span className="text-zinc-900 dark:text-white">Admin</span></p>
        </header>

        {error && (
          <div className="mb-8 p-6 rounded-3xl bg-red-50 border border-red-200 text-red-600 flex items-center gap-4">
             <ShieldIcon size={24} />
             <p className="text-xs font-black uppercase tracking-widest">{error}</p>
          </div>
        )}

        {success && (
          <div className="mb-8 p-12 rounded-[3.5rem] bg-zinc-900 dark:bg-white text-white dark:text-black text-center space-y-6 shadow-2xl animate-in flip-in-x duration-500">
             <ShieldCheck size={64} className="mx-auto" />
             <h2 className="text-2xl font-black uppercase tracking-widest">User Registered Successfully</h2>
             <p className="text-[10px] font-black uppercase tracking-[0.2em] opacity-80">Updating system permissions and finalizing...</p>
          </div>
        )}

        {!success && (
          <form onSubmit={handleSubmit} className="space-y-12 pb-20">
            {/* Form Section: Security Clearance & Role */}
            <section className="bg-white dark:bg-zinc-950 p-10 lg:p-14 rounded-[3.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl space-y-10">
               <div className="flex items-center gap-4 border-b border-zinc-100 dark:border-zinc-900 pb-6">
                  <div className="h-10 w-10 rounded-xl bg-zinc-100 dark:bg-zinc-900 flex items-center justify-center text-zinc-500">
                     <Briefcase size={20} />
                  </div>
                  <div>
                    <h3 className="text-sm font-black uppercase tracking-widest">Account Role</h3>
                    <p className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">Select user permissions and access</p>
                  </div>
               </div>

               <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  {[
                    { id: 'responder', label: 'RESPONDER', desc: 'Police/Medic/Rescue units' },
                    { id: 'barangay_head', label: 'BARANGAY HEAD', desc: 'Barangay administration' },
                    { id: 'admin', label: 'ADMINISTRATOR', desc: 'Full system control' },
                  ].map((role) => (
                    <button
                      key={role.id}
                      type="button"
                      onClick={() => setFormData({ ...formData, role: role.id })}
                      className={`p-6 rounded-3xl border transition-all text-left space-y-2 ${
                        formData.role === role.id 
                          ? 'bg-zinc-900 border-zinc-900 text-white shadow-2xl scale-105' 
                          : 'bg-zinc-50 dark:bg-zinc-900 border-zinc-200 dark:border-zinc-800 text-zinc-500 hover:border-zinc-900'
                      }`}
                    >
                       <p className="text-[10px] font-black uppercase tracking-widest">{role.label}</p>
                       <p className="text-[8px] font-bold opacity-60 uppercase tracking-widest">{role.desc}</p>
                    </button>
                  ))}
               </div>
            </section>

            {/* Form Section: Core ID */}
            <section className="bg-white dark:bg-zinc-950 p-10 lg:p-14 rounded-[3.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl space-y-10">
               <div className="flex items-center gap-4 border-b border-zinc-100 dark:border-zinc-900 pb-6">
                  <div className="h-10 w-10 rounded-xl bg-zinc-100 dark:bg-zinc-900 flex items-center justify-center text-zinc-500">
                     <User size={20} />
                  </div>
                  <div>
                    <h3 className="text-sm font-black uppercase tracking-widest">Personal Details</h3>
                    <p className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">Legal credentials for account access</p>
                  </div>
               </div>

               <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">First Name</label>
                     <input 
                       required
                       placeholder="ENTRY NAME..."
                       value={formData.firstName}
                       onChange={(e) => setFormData({...formData, firstName: e.target.value.toUpperCase()})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
                     />
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Last Name</label>
                     <input 
                       required
                       placeholder="ENTRY SURNAME..."
                       value={formData.lastName}
                       onChange={(e) => setFormData({...formData, lastName: e.target.value.toUpperCase()})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
                     />
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Email Terminal</label>
                     <div className="relative">
                        <Mail className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-400" size={16} />
                        <input 
                          type="email"
                          required
                          placeholder="AGENT@RISKQPH.GOV"
                          value={formData.email}
                          onChange={(e) => setFormData({...formData, email: e.target.value})}
                          className="w-full h-14 pl-14 pr-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
                        />
                     </div>
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Secured Password</label>
                     <div className="relative">
                        <Lock className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-400" size={16} />
                        <input 
                          type="password" 
                          required 
                          placeholder="••••••••"
                          value={formData.password}
                          onChange={(e) => setFormData({...formData, password: e.target.value})}
                          className="w-full h-14 pl-14 pr-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
                        />
                     </div>
                  </div>
                  <div className="md:col-span-2 space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Barangay Name</label>
                     <div className="relative">
                        <Globe className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-400" size={16} />
                        <input 
                          required
                          placeholder="ENTER BARANGAY NAME..."
                          value={formData.barangay}
                          onChange={(e) => setFormData({...formData, barangay: e.target.value.toUpperCase()})}
                          className="w-full h-14 pl-14 pr-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
                        />
                     </div>
                  </div>
               </div>
            </section>

            <button
              type="submit"
              disabled={loading}
              className="w-full h-20 rounded-[2rem] bg-red-600 text-white font-black uppercase tracking-[0.3em] text-xs hover:bg-zinc-900 transition-all flex items-center justify-center gap-4 shadow-2xl shadow-red-600/20"
            >
              {loading ? (
                <Loader2 className="animate-spin" />
              ) : (
                <>
                  <span>REGISTER USER</span>
                  <ChevronRight size={20} />
                </>
              )}
            </button>
          </form>
        )}
      </main>
    </div>
  );
}
