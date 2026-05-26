'use client';

import { useEffect, useState } from 'react';
import { BarChart3, TrendingUp, Calendar } from 'lucide-react';
import StatCard from '@/components/StatCard';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';

interface DailyData {
  day: string;
  date: string;
  deposits: number;
  purchases: number;
}

interface TopSeller {
  name: string;
  sales: number;
  count: number;
  percentage: number;
}

export default function ReportsPage() {
  const [dailyData, setDailyData] = useState<DailyData[]>([]);
  const [topSellers, setTopSellers] = useState<TopSeller[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchReports() {
      // Get last 7 days of data
      const days: DailyData[] = [];
      const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const now = new Date();

      for (let i = 6; i >= 0; i--) {
        const d = new Date(now);
        d.setDate(d.getDate() - i);
        const dateStr = d.toISOString().split('T')[0];
        days.push({
          day: dayNames[d.getDay()],
          date: dateStr,
          deposits: 0,
          purchases: 0,
        });
      }

      const weekStart = days[0].date + 'T00:00:00';
      const weekEnd = days[days.length - 1].date + 'T23:59:59';

      // Fetch all transactions for the week
      const { data: txData } = await supabase
        .from('transactions')
        .select('type, amount, created_at, seller_id')
        .gte('created_at', weekStart)
        .lte('created_at', weekEnd);

      const transactions = txData || [];

      // Group by day
      transactions.forEach((tx: Record<string, unknown>) => {
        const txDate = (tx.created_at as string).split('T')[0];
        const dayEntry = days.find(d => d.date === txDate);
        if (dayEntry) {
          if (tx.type === 'deposit') {
            dayEntry.deposits += tx.amount as number;
          } else if (tx.type === 'purchase') {
            dayEntry.purchases += tx.amount as number;
          }
        }
      });

      setDailyData(days);

      // Top sellers today
      const todayStr = now.toISOString().split('T')[0];
      const todayTx = transactions.filter((tx: Record<string, unknown>) =>
        (tx.created_at as string).startsWith(todayStr) && tx.type === 'purchase' && tx.seller_id
      );

      // Group by seller
      const sellerSales: Record<string, { total: number; count: number }> = {};
      todayTx.forEach((tx: Record<string, unknown>) => {
        const sid = tx.seller_id as string;
        if (!sellerSales[sid]) sellerSales[sid] = { total: 0, count: 0 };
        sellerSales[sid].total += tx.amount as number;
        sellerSales[sid].count += 1;
      });

      // Fetch seller names
      const sellerIds = Object.keys(sellerSales);
      let sellerNames: Record<string, string> = {};

      if (sellerIds.length > 0) {
        const { data: sellersData } = await supabase
          .from('canteen_sellers')
          .select('id, stall_name')
          .in('id', sellerIds);

        (sellersData || []).forEach((s: Record<string, unknown>) => {
          sellerNames[s.id as string] = s.stall_name as string;
        });
      }

      const totalSales = Object.values(sellerSales).reduce((s, v) => s + v.total, 0);
      const topSellersList: TopSeller[] = Object.entries(sellerSales)
        .map(([id, data]) => ({
          name: sellerNames[id] || 'Unknown',
          sales: data.total,
          count: data.count,
          percentage: totalSales > 0 ? Math.round((data.total / totalSales) * 100) : 0,
        }))
        .sort((a, b) => b.sales - a.sales)
        .slice(0, 5);

      setTopSellers(topSellersList);
      setLoading(false);
    }

    fetchReports();
  }, []);

  const totalDeposits = dailyData.reduce((sum, d) => sum + d.deposits, 0);
  const totalPurchases = dailyData.reduce((sum, d) => sum + d.purchases, 0);
  const maxValue = dailyData.length > 0
    ? Math.max(...dailyData.flatMap(d => [d.deposits, d.purchases]), 1)
    : 1;

  if (loading) {
    return (
      <div>
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Reports</h1>
            <p className="mt-1 text-sm text-gray-500">Loading...</p>
          </div>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3 mb-8">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-28 animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
          ))}
        </div>
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div className="h-64 animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
          <div className="h-64 animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
        </div>
      </div>
    );
  }

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
          {dailyData.every(d => d.deposits === 0 && d.purchases === 0) ? (
            <p className="py-8 text-center text-sm text-gray-400">No transaction data for this week</p>
          ) : (
            <div className="space-y-3">
              {dailyData.map((day) => (
                <div key={day.date} className="space-y-1">
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
          )}
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
          {topSellers.length === 0 ? (
            <p className="py-8 text-center text-sm text-gray-400">No sales data for today</p>
          ) : (
            <div className="space-y-4">
              {topSellers.map((seller, i) => (
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
          )}
        </div>
      </div>
    </div>
  );
}
