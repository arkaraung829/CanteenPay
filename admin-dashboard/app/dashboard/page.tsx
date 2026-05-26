import StatCard from '@/components/StatCard';
import { Users, Banknote, ArrowLeftRight, Store, TrendingUp, TrendingDown } from 'lucide-react';
import { formatMMK } from '@/lib/types';

// Demo data for prototype
const recentTransactions = [
  { id: '1', student: 'Aung Kyaw Zin', type: 'purchase', amount: 1500, seller: 'Daw Aye - Stall #1', time: '2 min ago' },
  { id: '2', student: 'Thin Thin Aye', type: 'deposit', amount: 20000, seller: 'Counter', time: '15 min ago' },
  { id: '3', student: 'Min Thant Zaw', type: 'purchase', amount: 2000, seller: 'U Ko Ko - Stall #3', time: '22 min ago' },
  { id: '4', student: 'Su Su Lwin', type: 'purchase', amount: 1000, seller: 'Daw Aye - Stall #1', time: '35 min ago' },
  { id: '5', student: 'Htet Aung', type: 'deposit', amount: 10000, seller: 'Counter', time: '1 hr ago' },
  { id: '6', student: 'Phyu Phyu Win', type: 'refund', amount: 500, seller: 'U Ko Ko - Stall #3', time: '1 hr ago' },
];

export default function DashboardPage() {
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
          value="342"
          change="+12 this month"
          changeType="positive"
          icon={Users}
          iconColor="text-blue-600"
          iconBg="bg-blue-100"
        />
        <StatCard
          title="Total Balance"
          value={formatMMK(4850000)}
          change="Across all wallets"
          changeType="neutral"
          icon={Banknote}
          iconColor="text-green-600"
          iconBg="bg-green-100"
        />
        <StatCard
          title="Today's Transactions"
          value="87"
          change="+23% vs yesterday"
          changeType="positive"
          icon={ArrowLeftRight}
          iconColor="text-purple-600"
          iconBg="bg-purple-100"
        />
        <StatCard
          title="Active Sellers"
          value="8"
          change="All stalls open"
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
          <p className="mt-2 text-2xl font-bold text-green-600">{formatMMK(350000)}</p>
          <p className="mt-1 text-xs text-gray-500">14 deposits</p>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <div className="flex items-center gap-2">
            <TrendingDown className="h-4 w-4 text-red-500" />
            <h3 className="text-sm font-semibold text-gray-900">Purchases Today</h3>
          </div>
          <p className="mt-2 text-2xl font-bold text-red-500">{formatMMK(128500)}</p>
          <p className="mt-1 text-xs text-gray-500">73 purchases</p>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <div className="flex items-center gap-2">
            <Banknote className="h-4 w-4 text-blue-500" />
            <h3 className="text-sm font-semibold text-gray-900">Net Flow</h3>
          </div>
          <p className="mt-2 text-2xl font-bold text-blue-600">{formatMMK(221500)}</p>
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
              {recentTransactions.map((tx) => (
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
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
