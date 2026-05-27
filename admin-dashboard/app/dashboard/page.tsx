'use client';

import { useEffect, useState } from 'react';
import StatCard from '@/components/StatCard';
import { Users, Banknote, ArrowLeftRight, Store, TrendingUp, TrendingDown } from 'lucide-react';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';
import { useSchoolContext } from '@/lib/school-context';

interface DashboardStats {
  totalStudents: number;
  totalBalance: number;
  todayTransactions: number;
  activeSellers: number;
  todayDeposits: number;
  todayDepositCount: number;
  todayPurchases: number;
  todayPurchaseCount: number;
}

interface RecentTx {
  id: string;
  student: string;
  type: string;
  amount: number;
  seller: string;
  time: string;
}

export default function DashboardPage() {
  const { selectedSchoolId, loading: schoolLoading } = useSchoolContext();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [recentTransactions, setRecentTransactions] = useState<RecentTx[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (schoolLoading) return;

    async function fetchDashboard() {
      setLoading(true);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayISO = today.toISOString();

      // Build queries with optional school_id filter
      let studentsQuery = supabase.from('students').select('id', { count: 'exact', head: true });
      let sellersQuery = supabase.from('canteen_sellers').select('id', { count: 'exact', head: true }).eq('is_active', true);

      if (selectedSchoolId) {
        studentsQuery = studentsQuery.eq('school_id', selectedSchoolId);
        sellersQuery = sellersQuery.eq('school_id', selectedSchoolId);
      }

      // For wallets and transactions, we need to filter via student/seller school_id
      let walletsQuery = supabase.from('wallets').select('balance, student:students(school_id)');
      let todayTxQuery = supabase.from('transactions').select('type, amount, wallet:wallets(student:students(school_id))').gte('created_at', todayISO);
      let recentTxQuery = supabase.from('transactions').select(`
        id,
        type,
        amount,
        created_at,
        wallet:wallets(student:students(full_name, school_id)),
        seller:canteen_sellers(stall_name)
      `).order('created_at', { ascending: false }).limit(10);

      const [
        studentsRes,
        walletsRes,
        todayTxRes,
        sellersRes,
        recentTxRes,
      ] = await Promise.all([
        studentsQuery,
        walletsQuery,
        todayTxQuery,
        sellersQuery,
        recentTxQuery,
      ]);

      // Filter wallets by school_id client-side (join filtering)
      let walletData = walletsRes.data || [];
      if (selectedSchoolId) {
        walletData = walletData.filter((w: Record<string, unknown>) => {
          const student = w.student as Record<string, unknown> | null;
          return student?.school_id === selectedSchoolId;
        });
      }
      const totalBalance = walletData.reduce((sum: number, w: Record<string, unknown>) => sum + ((w.balance as number) || 0), 0);

      // Filter today's transactions by school_id
      let todayTxData = todayTxRes.data || [];
      if (selectedSchoolId) {
        todayTxData = todayTxData.filter((tx: Record<string, unknown>) => {
          const wallet = tx.wallet as Record<string, unknown> | null;
          const student = wallet?.student as Record<string, unknown> | null;
          return student?.school_id === selectedSchoolId;
        });
      }
      const todayDeposits = todayTxData.filter((t: Record<string, unknown>) => t.type === 'deposit').reduce((s: number, t: Record<string, unknown>) => s + (t.amount as number), 0);
      const todayDepositCount = todayTxData.filter((t: Record<string, unknown>) => t.type === 'deposit').length;
      const todayPurchases = todayTxData.filter((t: Record<string, unknown>) => t.type === 'purchase').reduce((s: number, t: Record<string, unknown>) => s + (t.amount as number), 0);
      const todayPurchaseCount = todayTxData.filter((t: Record<string, unknown>) => t.type === 'purchase').length;

      setStats({
        totalStudents: studentsRes.count || 0,
        totalBalance,
        todayTransactions: todayTxData.length,
        activeSellers: sellersRes.count || 0,
        todayDeposits,
        todayDepositCount,
        todayPurchases,
        todayPurchaseCount,
      });

      // Filter recent transactions by school_id
      let recentData = recentTxRes.data || [];
      if (selectedSchoolId) {
        recentData = recentData.filter((tx: Record<string, unknown>) => {
          const wallet = tx.wallet as Record<string, unknown> | null;
          const student = wallet?.student as Record<string, unknown> | null;
          return student?.school_id === selectedSchoolId;
        });
      }

      const mapped: RecentTx[] = recentData.map((tx: Record<string, unknown>) => {
        const wallet = tx.wallet as Record<string, unknown> | null;
        const student = wallet?.student as Record<string, unknown> | null;
        const seller = tx.seller as Record<string, unknown> | null;
        const createdAt = tx.created_at as string;
        const elapsed = getTimeAgo(createdAt);
        return {
          id: tx.id as string,
          student: (student?.full_name as string) || 'Unknown',
          type: tx.type as string,
          amount: tx.amount as number,
          seller: (seller?.stall_name as string) || (tx.type === 'deposit' ? 'Counter' : '-'),
          time: elapsed,
        };
      });
      setRecentTransactions(mapped);
      setLoading(false);
    }

    fetchDashboard();
  }, [selectedSchoolId, schoolLoading]);

  function getTimeAgo(dateStr: string): string {
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'just now';
    if (mins < 60) return `${mins} min ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs} hr ago`;
    return `${Math.floor(hrs / 24)}d ago`;
  }

  if (loading) {
    return (
      <div>
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="mt-1 text-sm text-gray-500">Overview of today&apos;s activity</p>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="h-28 animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
          ))}
        </div>
        <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-3">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-24 animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
          ))}
        </div>
        <div className="mt-8 h-64 animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
      </div>
    );
  }

  const s = stats!;

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="mt-1 text-sm text-gray-500">Overview of today&apos;s activity</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Total Students"
          value={s.totalStudents.toString()}
          change="Registered students"
          changeType="neutral"
          icon={Users}
          iconColor="text-blue-600"
          iconBg="bg-blue-100"
        />
        <StatCard
          title="Total Balance"
          value={formatMMK(s.totalBalance)}
          change="Across all wallets"
          changeType="neutral"
          icon={Banknote}
          iconColor="text-green-600"
          iconBg="bg-green-100"
        />
        <StatCard
          title="Today's Transactions"
          value={s.todayTransactions.toString()}
          change="Today"
          changeType="neutral"
          icon={ArrowLeftRight}
          iconColor="text-purple-600"
          iconBg="bg-purple-100"
        />
        <StatCard
          title="Active Sellers"
          value={s.activeSellers.toString()}
          change="Active stalls"
          changeType="neutral"
          icon={Store}
          iconColor="text-amber-600"
          iconBg="bg-amber-100"
        />
      </div>

      {/* Today's Summary */}
      <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <div className="flex items-center gap-2">
            <TrendingUp className="h-4 w-4 text-green-500" />
            <h3 className="text-sm font-semibold text-gray-900">Deposits Today</h3>
          </div>
          <p className="mt-2 text-2xl font-bold text-green-600">{formatMMK(s.todayDeposits)}</p>
          <p className="mt-1 text-xs text-gray-500">{s.todayDepositCount} deposits</p>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <div className="flex items-center gap-2">
            <TrendingDown className="h-4 w-4 text-red-500" />
            <h3 className="text-sm font-semibold text-gray-900">Purchases Today</h3>
          </div>
          <p className="mt-2 text-2xl font-bold text-red-500">{formatMMK(s.todayPurchases)}</p>
          <p className="mt-1 text-xs text-gray-500">{s.todayPurchaseCount} purchases</p>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <div className="flex items-center gap-2">
            <Banknote className="h-4 w-4 text-blue-500" />
            <h3 className="text-sm font-semibold text-gray-900">Net Flow</h3>
          </div>
          <p className="mt-2 text-2xl font-bold text-blue-600">{formatMMK(s.todayDeposits - s.todayPurchases)}</p>
          <p className="mt-1 text-xs text-gray-500">Deposits minus purchases</p>
        </div>
      </div>

      {/* Recent Transactions */}
      <div className="mt-8">
        <h2 className="mb-4 text-lg font-semibold text-gray-900">Recent Transactions</h2>
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Student</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Type</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Amount</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Seller/Source</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Time</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {recentTransactions.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center text-sm text-gray-400">No transactions yet</td>
                </tr>
              ) : (
                recentTransactions.map((tx) => (
                  <tr key={tx.id} className="hover:bg-gray-50">
                    <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-gray-900">{tx.student}</td>
                    <td className="whitespace-nowrap px-6 py-4">
                      <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                        tx.type === 'deposit' ? 'bg-green-100 text-green-700' :
                        tx.type === 'purchase' ? 'bg-red-100 text-red-700' :
                        'bg-amber-100 text-amber-700'
                      }`}>
                        {tx.type}
                      </span>
                    </td>
                    <td className={`whitespace-nowrap px-6 py-4 text-sm font-medium ${
                      tx.type === 'deposit' ? 'text-green-600' :
                      tx.type === 'refund' ? 'text-amber-600' :
                      'text-red-600'
                    }`}>
                      {tx.type === 'purchase' ? '-' : '+'}{formatMMK(tx.amount)}
                    </td>
                    <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500">{tx.seller}</td>
                    <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-400">{tx.time}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
