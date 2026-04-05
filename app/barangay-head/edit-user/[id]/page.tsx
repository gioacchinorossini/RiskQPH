'use client';

import { useState, useEffect } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { 
  UserCircle, 
  ArrowLeft, 
  ShieldCheck, 
  Loader2, 
  Mail, 
  Lock, 
  User, 
  Calendar,
  ChevronRight,
  ShieldIcon,
  Globe,
  Briefcase,
  MapPin
} from 'lucide-react';

export default function EditUserPage() {
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const router = useRouter();
  const params = useParams();
  const userId = params.id as string;

  const [formData, setFormData] = useState({
    id: '',
    email: '',
    firstName: '',
    lastName: '',
    middleName: '',
    birthdate: '',
    gender: 'MALE',
    barangay: '',
    address: '',
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
    setCurrentUser(parsed);
    fetchUserDetails();
  }, [userId]);

  const fetchUserDetails = async () => {
    try {
      const res = await fetch(`/api/profile?id=${userId}`);
      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'Failed to fetch user');
      
      setFormData({
        id: data.user.id,
        email: data.user.email,
        firstName: data.user.firstName || '',
        lastName: data.user.lastName || '',
        middleName: data.user.middleName || '',
        birthdate: data.user.birthdate || '',
        gender: data.user.gender || 'MALE',
        barangay: data.user.barangay || '',
        address: data.user.address || '',
        role: data.user.role || 'resident',
      });
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setUpdating(true);
    setError('');
    
    try {
      const res = await fetch('/api/profile', {
        method: 'POST', // The generic profile endpoint was designed as POST for updates
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.message || 'Update failed');

      setSuccess(true);
      setTimeout(() => {
        router.push('/barangay-head');
      }, 2000);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setUpdating(false);
    }
  };

  if (loading) return (
    <div className="h-screen w-screen flex flex-col items-center justify-center gap-4 bg-zinc-50 dark:bg-black">
      <Loader2 className="animate-spin text-red-600" size={40} />
      <p className="text-[10px] font-black uppercase tracking-widest text-zinc-400">Loading Account Data...</p>
    </div>
  );

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-black font-sans selection:bg-red-600 selection:text-white pb-20">
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
             <div className="h-8 w-8 rounded-lg bg-zinc-900 dark:bg-white text-white dark:text-black flex items-center justify-center rotate-3">
               <UserCircle size={16} />
             </div>
             <p className="text-[10px] font-black tracking-widest uppercase opacity-40">Account Editor</p>
         </div>
      </nav>

      <main className="max-w-4xl mx-auto p-6 lg:py-20">
        <header className="mb-12 text-center space-y-4">
           <div className="h-20 w-20 rounded-3xl bg-zinc-900 dark:bg-white text-white dark:text-black flex items-center justify-center mx-auto shadow-2xl mb-6">
              <UserCircle size={40} strokeWidth={2.5} />
           </div>
           <h1 className="text-4xl lg:text-6xl font-black tracking-tighter uppercase leading-none">Modify <span className="text-red-600 italic">User</span></h1>
           <p className="text-xs font-black uppercase tracking-[0.3em] text-zinc-400">Resident ID: {formData.id.slice(-8).toUpperCase()}</p>
        </header>

        {error && (
          <div className="mb-8 p-6 rounded-3xl bg-red-50 border border-red-200 text-red-600 flex items-center gap-4 animate-in fade-in zoom-in-95 duration-300">
             <ShieldIcon size={24} />
             <p className="text-xs font-black uppercase tracking-widest">{error}</p>
          </div>
        )}

        {success && (
          <div className="mb-8 p-12 rounded-[3.5rem] bg-emerald-600 text-white text-center space-y-6 shadow-2xl animate-in flip-in-x duration-500">
             <ShieldCheck size={64} className="mx-auto" />
             <h2 className="text-2xl font-black uppercase tracking-widest">Update Successful</h2>
             <p className="text-[10px] font-black uppercase tracking-[0.2em] opacity-80">Synchronizing records and returning to dashboard...</p>
          </div>
        )}

        {!success && (
          <form onSubmit={handleSubmit} className="space-y-12">
            {/* Role Assignment */}
            <section className="bg-white dark:bg-zinc-950 p-10 lg:p-14 rounded-[3.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl space-y-10">
               <div className="flex items-center gap-4 border-b border-zinc-100 dark:border-zinc-900 pb-6">
                  <div className="h-10 w-10 rounded-xl bg-zinc-100 dark:bg-zinc-900 flex items-center justify-center text-zinc-500">
                     <Briefcase size={20} />
                  </div>
                  <div>
                    <h3 className="text-sm font-black uppercase tracking-widest">Account Permissions</h3>
                    <p className="text-[9px] font-black text-zinc-400 uppercase tracking-widest">Control user role and access level</p>
                  </div>
               </div>

               <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                  {[
                    { id: 'resident', label: 'Resident' },
                    { id: 'responder', label: 'Responder' },
                    { id: 'barangay_head', label: 'Bgy Head' },
                    { id: 'admin', label: 'Admin' },
                  ].map((role) => (
                    <button
                      key={role.id}
                      type="button"
                      onClick={() => setFormData({ ...formData, role: role.id })}
                      className={`h-14 rounded-2xl border transition-all text-[9px] font-black uppercase tracking-widest ${
                        formData.role === role.id 
                          ? 'bg-red-600 border-red-600 text-white shadow-xl shadow-red-600/20' 
                          : 'bg-zinc-50 dark:bg-zinc-900 border-zinc-200 dark:border-zinc-800 text-zinc-500 hover:border-red-600/30'
                      }`}
                    >
                       {role.label}
                    </button>
                  ))}
               </div>
            </section>

            {/* Personal ID */}
            <section className="bg-white dark:bg-zinc-950 p-10 lg:p-14 rounded-[3.5rem] border border-zinc-200 dark:border-zinc-800 shadow-2xl space-y-10">
               <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">First Name</label>
                     <input 
                       required
                       value={formData.firstName}
                       onChange={(e) => setFormData({...formData, firstName: e.target.value.toUpperCase()})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                     />
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Last Name</label>
                     <input 
                       required
                       value={formData.lastName}
                       onChange={(e) => setFormData({...formData, lastName: e.target.value.toUpperCase()})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                     />
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Middle Name</label>
                     <input 
                       value={formData.middleName}
                       onChange={(e) => setFormData({...formData, middleName: e.target.value.toUpperCase()})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 transition-all"
                     />
                  </div>
                  <div className="space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Gender</label>
                     <select 
                       value={formData.gender}
                       onChange={(e) => setFormData({...formData, gender: e.target.value})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-[10px] font-black uppercase tracking-widest focus:outline-none focus:ring-2 focus:ring-red-600/20"
                     >
                       <option value="MALE">MALE</option>
                       <option value="FEMALE">FEMALE</option>
                       <option value="OTHER">OTHER</option>
                     </select>
                  </div>
                  <div className="md:col-span-2 space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Birthdate</label>
                     <input 
                       type="date"
                       value={formData.birthdate}
                       onChange={(e) => setFormData({...formData, birthdate: e.target.value})}
                       className="w-full h-14 px-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-red-600/20"
                     />
                  </div>
                  <div className="md:col-span-3 space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Barangay Allocation</label>
                     <div className="relative">
                        <Globe className="absolute left-6 top-1/2 -translate-y-1/2 text-zinc-400" size={16} />
                        <input 
                          required
                          value={formData.barangay}
                          onChange={(e) => setFormData({...formData, barangay: e.target.value.toUpperCase()})}
                          className="w-full h-14 pl-14 pr-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase focus:outline-none focus:ring-2 focus:ring-red-600/20"
                        />
                     </div>
                  </div>
                  <div className="md:col-span-3 space-y-2">
                     <label className="text-[9px] font-black uppercase tracking-widest text-zinc-400 ml-1">Physical Address</label>
                     <textarea 
                       required
                       value={formData.address}
                       onChange={(e) => setFormData({...formData, address: e.target.value.toUpperCase()})}
                       className="w-full h-28 p-6 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-zinc-50 dark:bg-zinc-900 text-xs font-black uppercase transition-all resize-none shadow-inner"
                     />
                  </div>
               </div>
            </section>

            <button
              type="submit"
              disabled={updating}
              className="w-full h-20 rounded-[2rem] bg-zinc-900 dark:bg-white text-white dark:text-black font-black uppercase tracking-[0.3em] text-xs hover:bg-black dark:hover:bg-zinc-200 transition-all flex items-center justify-center gap-4 shadow-2xl relative"
            >
              {updating ? (
                <Loader2 className="animate-spin" />
              ) : (
                <>
                  <span>Save Record Changes</span>
                  <ShieldCheck size={20} />
                </>
              )}
            </button>
          </form>
        )}
      </main>
    </div>
  );
}
