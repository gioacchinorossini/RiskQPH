'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function AddBarangayHead() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [barangay, setBarangay] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess(false);

    try {
      const response = await fetch('/api/admin/barangay-head', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, firstName, lastName, barangay }),
      });

      if (response.ok) {
        setSuccess(true);
        // Clear form
        setEmail('');
        setPassword('');
        setFirstName('');
        setLastName('');
        setBarangay('');
      } else {
        const data = await response.json();
        setError(data.message || 'Something went wrong');
      }
    } catch (err) {
      setError('Failed to connect to the server');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white dark:bg-black p-6 font-sans antialiased flex items-center justify-center">
      <div className="w-full max-w-lg">
        <header className="mb-12 text-center">
          <div className="h-12 w-12 rounded bg-red-600 flex items-center justify-center mx-auto mb-4 shadow-lg">
            <span className="text-white font-bold italic tracking-tighter text-xl">RQ</span>
          </div>
          <h1 className="text-3xl font-black tracking-tight text-zinc-900 dark:text-zinc-50 mb-2 uppercase">
            ADMIN <span className="text-red-600">COMMAND CENTER</span>
          </h1>
          <p className="text-sm font-medium text-zinc-500 dark:text-zinc-400">REGISTER NEW BARANGAY HEADS</p>
        </header>

        <form onSubmit={handleSubmit} className="space-y-6 bg-zinc-50 dark:bg-zinc-900/50 p-8 rounded-3xl border border-zinc-100 dark:border-zinc-800 shadow-xl backdrop-blur-sm">
          {error && <div className="bg-red-50 text-red-600 p-4 rounded-xl text-sm font-bold border border-red-100">{error}</div>}
          {success && <div className="bg-emerald-50 text-emerald-600 p-4 rounded-xl text-sm font-bold border border-emerald-100">Barangay Head Added Successfully!</div>}

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-black uppercase tracking-widest text-zinc-400 ml-1">First Name</label>
              <input
                type="text"
                required
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className="w-full h-11 px-4 rounded-xl border border-zinc-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-red-600 focus:border-transparent dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50 transition-all shadow-sm"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-black uppercase tracking-widest text-zinc-400 ml-1">Last Name</label>
              <input
                type="text"
                required
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className="w-full h-11 px-4 rounded-xl border border-zinc-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-red-600 focus:border-transparent dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50 transition-all shadow-sm"
              />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-black uppercase tracking-widest text-zinc-400 ml-1">Barangay Jurisdiction</label>
            <input
              type="text"
              required
              value={barangay}
              onChange={(e) => setBarangay(e.target.value)}
              className="w-full h-11 px-4 rounded-xl border border-zinc-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-red-600 focus:border-transparent dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50 transition-all shadow-sm"
              placeholder="Enter Barangay Name"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-black uppercase tracking-widest text-zinc-400 ml-1">Official Email</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full h-11 px-4 rounded-xl border border-zinc-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-red-600 focus:border-transparent dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50 transition-all shadow-sm"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-black uppercase tracking-widest text-zinc-400 ml-1">Secure Password</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full h-11 px-4 rounded-xl border border-zinc-200 bg-white text-sm focus:outline-none focus:ring-2 focus:ring-red-600 focus:border-transparent dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50 transition-all shadow-sm"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full h-12 bg-red-600 hover:bg-red-700 text-white rounded-xl text-sm font-black uppercase tracking-widest transition-all disabled:opacity-50 mt-4 shadow-lg shadow-red-600/20 active:scale-[0.98]"
          >
            {loading ? 'PROCESSING...' : 'REGISTER BARANGAY HEAD'}
          </button>
          
          <button 
            type="button"
            onClick={() => router.push('/')}
            className="w-full text-zinc-400 text-[10px] font-black uppercase tracking-widest hover:text-zinc-900 transition-colors py-2"
          >
            Return to Command Center
          </button>
        </form>
      </div>
    </div>
  );
}
