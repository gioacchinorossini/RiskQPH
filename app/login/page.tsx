'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Shield, Lock, Mail, ChevronRight, AlertCircle, Loader2 } from 'lucide-react';
import ThemeToggle from '../../components/ThemeToggle';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();

  // Removed auto-redirect to allow re-login or switching accounts
  // useEffect(() => {
  //   const user = localStorage.getItem('user');
  //   if (user) {
  //     const parsed = JSON.parse(user);
  //     if (parsed.role === 'barangay_head') router.push('/barangay-head');
  //     else router.push('/');
  //   }
  // }, [router]);

  const performLogin = async (loginEmail?: string, loginPassword?: string) => {
    const finalEmail = loginEmail || email;
    const finalPassword = loginPassword || password;

    setLoading(true);
    setError('');

    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: finalEmail, password: finalPassword }),
      });

      const data = await response.json();
      if (response.ok) {
        localStorage.setItem('user', JSON.stringify(data.user));
        if (data.user.role === 'barangay_head') {
          router.push('/barangay-head');
        } else {
          router.push('/');
        }
      } else {
        setError(data.message || 'Authentication failed');
      }
    } catch (err) {
      setError('Connection error. Please check your network.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    performLogin();
  };

  return (
    <div className="min-h-screen bg-white dark:bg-black font-sans antialiased flex flex-col items-center justify-center p-6 lg:p-12 overflow-hidden relative">
      {/* Dynamic Background Elements */}
      <div className="absolute top-0 left-0 w-full h-full overflow-hidden -z-10 pointer-events-none">
        <div className="absolute top-[-10%] right-[-10%] w-[50%] h-[50%] bg-red-500/5 blur-[120px] rounded-full animate-pulse" />
        <div className="absolute bottom-[-10%] left-[-10%] w-[50%] h-[50%] bg-red-600/5 blur-[120px] rounded-full" />
      </div>

      <div className="absolute top-6 right-6 z-10">
        <ThemeToggle />
      </div>

      <div className="w-full max-w-md relative">
        <header className="mb-12 text-center space-y-4">
          <div className="h-16 w-16 rounded-2xl bg-red-600 flex items-center justify-center mx-auto mb-6 shadow-[0_0_40px_rgba(220,38,38,0.3)] rotate-3 hover:rotate-0 transition-all duration-500 group">
            <span className="text-white font-black italic tracking-tighter text-2xl group-hover:scale-110 transition-transform">RQ</span>
          </div>
          <div className="space-y-1">
            <h1 className="text-4xl font-black tracking-tight text-zinc-900 dark:text-zinc-50 uppercase leading-none">
              RISK<span className="text-red-600">QPH</span>
            </h1>
            <p className="text-xs font-bold text-zinc-400 uppercase tracking-[0.2em]">login to dashboard</p>
          </div>
        </header>

        <div className="bg-zinc-50/50 dark:bg-zinc-900/50 backdrop-blur-xl p-8 lg:p-10 rounded-[2.5rem] border border-zinc-200/50 dark:border-zinc-800/50 shadow-2xl relative">
          <form onSubmit={handleLogin} className="space-y-6">
            <div className="space-y-4">
              <div className="relative group">
                <div className="absolute inset-y-0 left-4 flex items-center pointer-events-none text-zinc-400 group-focus-within:text-red-600 transition-colors">
                  <Mail size={18} strokeWidth={2.5} />
                </div>
                <input
                  type="email"
                  required
                  placeholder="Enter Email Address"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full h-14 pl-12 pr-4 rounded-2xl border border-zinc-200 bg-white text-sm font-medium focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50 transition-all shadow-sm placeholder:text-zinc-400 placeholder:font-bold placeholder:uppercase placeholder:tracking-wider placeholder:text-[10px]"
                />
              </div>

              <div className="relative group">
                <div className="absolute inset-y-0 left-4 flex items-center pointer-events-none text-zinc-400 group-focus-within:text-red-600 transition-colors">
                  <Lock size={18} strokeWidth={2.5} />
                </div>
                <input
                  type="password"
                  required
                  placeholder="Enter Password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full h-14 pl-12 pr-4 rounded-2xl border border-zinc-200 bg-white text-sm font-medium focus:outline-none focus:ring-2 focus:ring-red-600/20 focus:border-red-600 dark:border-zinc-800 dark:bg-zinc-950 dark:text-zinc-50 transition-all shadow-sm placeholder:text-zinc-400 placeholder:font-bold placeholder:uppercase placeholder:tracking-wider placeholder:text-[10px]"
                />
              </div>
            </div>

            {error && (
              <div className="flex items-center gap-3 bg-red-500/10 border border-red-500/20 text-red-500 p-4 rounded-2xl animate-in fade-in slide-in-from-top-2 duration-300">
                <AlertCircle size={18} strokeWidth={2.5} className="shrink-0" />
                <p className="text-xs font-black uppercase tracking-wider">{error}</p>
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full h-14 bg-red-600 hover:bg-zinc-900 dark:hover:bg-white dark:hover:text-black text-white rounded-2xl font-black uppercase tracking-[0.2em] text-xs transition-all duration-300 disabled:opacity-50 shadow-lg shadow-red-600/20 active:scale-[0.98] group flex items-center justify-center gap-2"
            >
              {loading ? (
                <Loader2 className="animate-spin" size={20} />
              ) : (
                <>
                  login
                  <ChevronRight size={16} strokeWidth={3} className="group-hover:translate-x-1 transition-transform" />
                </>
              )}
            </button>
          </form>

          {/* Quick Login for Developers */}
          <div className="mt-8 pt-8 border-t border-zinc-200 dark:border-zinc-800">
            <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-400 mb-4 text-center">Quick Developer Access</p>
            <div className="grid grid-cols-1 gap-2">
              <button
                onClick={() => {
                  setEmail('head@test.com');
                  setPassword('password123');
                  performLogin('longnoxian4@gmail.com', 'gwapoko4321');
                }}
                className="flex items-center justify-between p-3 rounded-xl bg-zinc-100 hover:bg-zinc-200 dark:bg-zinc-800 dark:hover:bg-zinc-700 transition-all group"
              >
                <div className="flex items-center gap-3">
                  <Shield size={16} className="text-red-600" />
                  <span className="text-[10px] font-black uppercase tracking-wider">Barangay Head</span>
                </div>
                <span className="text-[9px] font-bold text-zinc-400 group-hover:text-red-600 dark:group-hover:text-red-500 transition-colors uppercase">Login</span>
              </button>
              <button
                onClick={() => {
                  setEmail('resident@test.com');
                  setPassword('password123');
                  performLogin('longnoxian5@gmail.com', 'gwapoko4321');
                }}
                className="flex items-center justify-between p-3 rounded-xl bg-zinc-100 hover:bg-zinc-200 dark:bg-zinc-800 dark:hover:bg-zinc-700 transition-all group"
              >
                <div className="flex items-center gap-3">
                  <Mail size={16} className="text-blue-500" />
                  <span className="text-[10px] font-black uppercase tracking-wider">Resident</span>
                </div>
                <span className="text-[9px] font-bold text-zinc-400 group-hover:text-red-600 dark:group-hover:text-red-500 transition-colors uppercase">Login</span>
              </button>
            </div>
          </div>
        </div>

        <footer className="mt-12 text-center text-zinc-400">
          <p className="text-[10px] font-black uppercase tracking-[0.3em] opacity-50">
            © 2026 RISKQPH
          </p>
        </footer>

      </div>
    </div>
  );
}
