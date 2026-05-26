'use client';

import { BarChart3, TrendingUp, Calendar } from 'lucide-react';
import StatCard from '@/components/StatCard';
import { formatMMK } from '@/lib/types';

const DAILY_DATA = [
  { day: 'Mon', deposits: 280000, purchases: 195000 },
  { day: 'Tue', deposits: 320000, purchases: 210000 },
  { day: 'Wed', deposits: 150000, purchases: 180000 },
  { day: 'Thu', deposits: 450000, purchases: 230000 },
  { day: 'Fri', deposits: 350000, purchases: 128500 },
];

const TOP_SELLERS = [
  { name: 'Daw Aye Kitchen', sales: 45000, count: 28, percentage: 35 },
  { name: 'Daw Ma Ma Rice', sales: 38000, count: 22, percentage: 29 },
  { name: 'U Ko Ko Snacks', sales: 25500, count: 18, percentage: 20 },
  { name: 'Drinks Corner', sales: 20000, count: 19, percentage: 16 },
];

export default function ReportsPage() {
  const totalDeposits = DAILY_DATA.reduce((sum, d) => sum + d.deposits, 0);
  const totalPurchases = DAILY_DATA.reduce((sum, d) => sum + d.purchases, 0);
  const maxValue = Math.max(...DAILY_DATA.flatMap(d => [d.deposits, d.purchases]));

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Reports</h1>
          <p className="mt-1 text-sm text-gray-500">Weekly financial summary</p>
        </div>
        <div className="flex gap-2">
          <button className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
            <Calendar className="h-4 w-4" /> This Week
          </button>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3 mb-8">
        <StatCard
          title="Week's Deposits"
          value={formatMMK(totalDeposits)}
          icon={TrendingUp}
          iconColor="text-green-600"
          iconBg="bg-green-100"
        />
        <StatCard
          title="Week's Purchases"
          value={formatMMK(totalPurchases)}
          icon={BarChart3}
          iconColor="text-red-600"
          iconBg="bg-red-100"
        />
        <StatCard
          title="Net Balance Change"
          value={formatMMK(totalDeposits - totalPurchases)}
          change="Money retained in system"
          changeType="positive"
          icon={TrendingUp}
          iconColor="text-blue-600"
          iconBg="bg-blue-100"
        />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Daily Chart */}
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <h3 className="text-sm font-semibold text-gray-900 mb-4">Daily Activity (This Week)</h3>
          <div className="space-y-3">
            {DAILY_DATA.map((day) => (
              <div key={day.day} className="space-y-1">
                <div className="flex items-center justify-between text-xs text-gray-500">
                  <span className="w-8 font-medium">{day.day}</span>
                  <span>D: {formatMMK(day.deposits)} | P: {formatMMK(day.purchases)}</span>
                </div>
                <div className="flex gap-1">
                  <div
                    className="h-4 rounded-l bg-green-400"
                    style={{ width: `${(day.deposits / maxValue) * 100}%` }}
                  />
                  <div
                    className="h-4 rounded-r bg-red-400"
                    style={{ width: `${(day.purchases / maxValue) * 100}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
          <div className="mt-4 flex gap-4 text-xs text-gray-500">
            <div className="flex items-center gap-1">
              <div className="h-3 w-3 rounded bg-green-400" /> Deposits
            </div>
            <div className="flex items-center gap-1">
              <div className="h-3 w-3 rounded bg-red-400" /> Purchases
            </div>
          </div>
        </div>

        {/* Top Sellers */}
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <h3 className="text-sm font-semibold text-gray-900 mb-4">Top Sellers Today</h3>
          <div className="space-y-4">
            {TOP_SELLERS.map((seller, i) => (
              <div key={seller.name}>
                <div className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <span className="flex h-6 w-6 items-center justify-center rounded-full bg-gray-100 text-xs font-bold text-gray-600">
                      {i + 1}
                    </span>
                    <span className="font-medium text-gray-900">{seller.name}</span>
                  </div>
                  <div className="text-right">
                    <span className="font-medium text-gray-900">{formatMMK(seller.sales)}</span>
                    <span className="ml-2 text-xs text-gray-400">({seller.count} txns)</span>
                  </div>
                </div>
                <div className="mt-1 ml-8 h-2 rounded-full bg-gray-100">
                  <div
                    className="h-2 rounded-full bg-blue-500"
                    style={{ width: `${seller.percentage}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
