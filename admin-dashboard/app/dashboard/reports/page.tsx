'use client';

import { useEffect, useState } from 'react';
import { BarChart3, TrendingUp, Calendar, Download } from 'lucide-react';
import StatCard from '@/components/StatCard';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';
import { useSchoolContext } from '@/lib/school-context';

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

interface SellerDailySale {
  name: string;
  sales: number;
  count: number;
  avg: number;
}

interface SellerOption {
  id: string;
  stall_name: string;
}

/** Format a Date as YYYY-MM-DD using local timezone */
function toLocalDateStr(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Convert a local date string to the start-of-day UTC ISO string */
function localDateToUTCStart(dateStr: string): string {
  return new Date(`${dateStr}T00:00:00`).toISOString();
}

/** Convert a local date string to the end-of-day UTC ISO string */
function localDateToUTCEnd(dateStr: string): string {
  return new Date(`${dateStr}T23:59:59.999`).toISOString();
}

function downloadCSV(filename: string, csvContent: string) {
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export default function ReportsPage() {
  const { selectedSchoolId } = useSchoolContext();
  const [dailyData, setDailyData] = useState<DailyData[]>([]);
  const [topSellers, setTopSellers] = useState<TopSeller[]>([]);
  const [loading, setLoading] = useState(true);

  // Seller Daily Sales state - date range
  const [sellerDateFrom, setSellerDateFrom] = useState(() => toLocalDateStr(new Date()));
  const [sellerDateTo, setSellerDateTo] = useState(() => toLocalDateStr(new Date()));
  const [sellerFilter, setSellerFilter] = useState('all');
  const [sellerOptions, setSellerOptions] = useState<SellerOption[]>([]);
  const [sellerDailySales, setSellerDailySales] = useState<SellerDailySale[]>([]);
  const [sellerDailyLoading, setSellerDailyLoading] = useState(false);
  const [sellerDailyTotal, setSellerDailyTotal] = useState(0);
  const [sellerDailyTotalCount, setSellerDailyTotalCount] = useState(0);

  // Fetch seller options for the filter dropdown
  useEffect(() => {
    async function fetchSellerOptions() {
      let query = supabase
        .from('canteen_sellers')
        .select('id, stall_name')
        .eq('is_active', true)
        .order('stall_name');
      if (selectedSchoolId) {
        query = query.eq('school_id', selectedSchoolId);
      }
      const { data } = await query;
      setSellerOptions(data || []);
    }
    fetchSellerOptions();
  }, [selectedSchoolId]);

  useEffect(() => {
    async function fetchReports() {
      // Get last 7 days of data
      const days: DailyData[] = [];
      const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const now = new Date();

      for (let i = 6; i >= 0; i--) {
        const d = new Date(now);
        d.setDate(d.getDate() - i);
        const dateStr = toLocalDateStr(d);
        days.push({
          day: dayNames[d.getDay()],
          date: dateStr,
          deposits: 0,
          purchases: 0,
        });
      }

      // Convert local date boundaries to UTC for Supabase query
      const weekStart = localDateToUTCStart(days[0].date);
      const weekEnd = localDateToUTCEnd(days[days.length - 1].date);

      // Fetch all transactions for the week
      const { data: txData } = await supabase
        .from('transactions')
        .select('type, amount, created_at, seller_id, wallet:wallets(student:students(school_id))')
        .gte('created_at', weekStart)
        .lte('created_at', weekEnd);

      let transactions = txData || [];

      // Filter by school_id if selected
      if (selectedSchoolId) {
        transactions = transactions.filter((tx: Record<string, unknown>) => {
          const wallet = tx.wallet as Record<string, unknown> | null;
          const student = wallet?.student as Record<string, unknown> | null;
          return student?.school_id === selectedSchoolId;
        });
      }

      // Group by day (convert UTC created_at to local date for correct grouping)
      transactions.forEach((tx: Record<string, unknown>) => {
        const txLocalDate = toLocalDateStr(new Date(tx.created_at as string));
        const dayEntry = days.find(d => d.date === txLocalDate);
        if (dayEntry) {
          if (tx.type === 'deposit') {
            dayEntry.deposits += tx.amount as number;
          } else if (tx.type === 'purchase') {
            dayEntry.purchases += tx.amount as number;
          }
        }
      });

      setDailyData(days);

      // Top sellers today (use local date)
      const todayStr = toLocalDateStr(now);
      const todayTx = transactions.filter((tx: Record<string, unknown>) =>
        toLocalDateStr(new Date(tx.created_at as string)) === todayStr && tx.type === 'purchase' && tx.seller_id
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
        let sellersQuery = supabase
          .from('canteen_sellers')
          .select('id, stall_name')
          .in('id', sellerIds);
        if (selectedSchoolId) {
          sellersQuery = sellersQuery.eq('school_id', selectedSchoolId);
        }
        const { data: sellersData } = await sellersQuery;

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
  }, [selectedSchoolId]);

  // Fetch seller daily sales for settlement (date range + seller filter)
  useEffect(() => {
    async function fetchSellerDailySales() {
      setSellerDailyLoading(true);
      try {
        const dayStartUTC = localDateToUTCStart(sellerDateFrom);
        const dayEndUTC = localDateToUTCEnd(sellerDateTo);

        let query = supabase
          .from('transactions')
          .select('type, amount, created_at, seller_id, wallet:wallets(student:students(school_id))')
          .eq('type', 'purchase')
          .gte('created_at', dayStartUTC)
          .lte('created_at', dayEndUTC);

        // If a specific seller is selected, filter at query level
        if (sellerFilter !== 'all') {
          query = query.eq('seller_id', sellerFilter);
        }

        const { data: txData } = await query;

        let transactions = txData || [];

        // Filter by school
        if (selectedSchoolId) {
          transactions = transactions.filter((tx: Record<string, unknown>) => {
            const wallet = tx.wallet as Record<string, unknown> | null;
            const student = wallet?.student as Record<string, unknown> | null;
            return student?.school_id === selectedSchoolId;
          });
        }

        // Group by seller
        const sellerSales: Record<string, { total: number; count: number }> = {};
        transactions.forEach((tx: Record<string, unknown>) => {
          const sid = tx.seller_id as string;
          if (!sid) return;
          if (!sellerSales[sid]) sellerSales[sid] = { total: 0, count: 0 };
          sellerSales[sid].total += tx.amount as number;
          sellerSales[sid].count += 1;
        });

        // Fetch seller names
        const sellerIds = Object.keys(sellerSales);
        let sellerNames: Record<string, string> = {};

        if (sellerIds.length > 0) {
          let sellersQuery = supabase
            .from('canteen_sellers')
            .select('id, stall_name')
            .in('id', sellerIds);
          if (selectedSchoolId) {
            sellersQuery = sellersQuery.eq('school_id', selectedSchoolId);
          }
          const { data: sellersData } = await sellersQuery;

          (sellersData || []).forEach((s: Record<string, unknown>) => {
            sellerNames[s.id as string] = s.stall_name as string;
          });
        }

        const salesList: SellerDailySale[] = Object.entries(sellerSales)
          .map(([id, data]) => ({
            name: sellerNames[id] || 'Unknown',
            sales: data.total,
            count: data.count,
            avg: data.count > 0 ? Math.round(data.total / data.count) : 0,
          }))
          .sort((a, b) => b.sales - a.sales);

        setSellerDailySales(salesList);
        const totalAmount = salesList.reduce((sum, s) => sum + s.sales, 0);
        const totalCount = salesList.reduce((sum, s) => sum + s.count, 0);
        setSellerDailyTotal(totalAmount);
        setSellerDailyTotalCount(totalCount);
      } catch (e) {
        console.error('Error fetching seller daily sales:', e);
      }
      setSellerDailyLoading(false);
    }

    fetchSellerDailySales();
  }, [sellerDateFrom, sellerDateTo, sellerFilter, selectedSchoolId]);

  // Export seller report as CSV
  function exportSellerCSV() {
    if (sellerDailySales.length === 0) return;

    const dateRange = sellerDateFrom === sellerDateTo
      ? sellerDateFrom
      : `${sellerDateFrom} to ${sellerDateTo}`;

    const lines: string[] = [];
    lines.push('Date Range,Seller Name,Sales Count,Total Amount (MMK),Average Per Sale (MMK)');

    sellerDailySales.forEach((s) => {
      lines.push(`"${dateRange}","${s.name}",${s.count},${s.sales},${s.avg}`);
    });

    // Totals row
    const grandAvg = sellerDailyTotalCount > 0 ? Math.round(sellerDailyTotal / sellerDailyTotalCount) : 0;
    lines.push(`"${dateRange}","GRAND TOTAL",${sellerDailyTotalCount},${sellerDailyTotal},${grandAvg}`);

    // Summary section
    lines.push('');
    lines.push('--- Summary ---');
    lines.push(`Grand Total Amount,${sellerDailyTotal} MMK`);
    lines.push(`Date Range,"${dateRange}"`);
    lines.push(`Generated,${new Date().toLocaleString()}`);

    const csv = lines.join('\n');
    const filename = `seller-report-${sellerDateFrom}${sellerDateFrom !== sellerDateTo ? '-to-' + sellerDateTo : ''}.csv`;
    downloadCSV(filename, csv);
  }

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

      {/* Seller Daily Sales - for settlement */}
      <div className="mt-6 rounded-xl border border-gray-200 bg-white p-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-4 gap-3">
          <div>
            <h3 className="text-sm font-semibold text-gray-900">Seller Daily Sales</h3>
            <p className="text-xs text-gray-500 mt-0.5">For daily settlement with each seller</p>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            {sellerDailySales.length > 0 && (
              <button
                onClick={exportSellerCSV}
                className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-sm font-medium text-gray-600 hover:bg-gray-50"
              >
                <Download className="h-4 w-4" /> Export CSV
              </button>
            )}
            {sellerDailySales.length > 0 && (
              <span className="text-sm font-medium text-gray-700">
                Total: {formatMMK(sellerDailyTotal)}
              </span>
            )}
          </div>
        </div>

        {/* Filters row */}
        <div className="mb-4 flex flex-wrap items-end gap-3">
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">From</label>
            <input
              type="date"
              value={sellerDateFrom}
              onChange={(e) => {
                setSellerDateFrom(e.target.value);
                // Ensure TO is not before FROM
                if (e.target.value > sellerDateTo) {
                  setSellerDateTo(e.target.value);
                }
              }}
              className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">To</label>
            <input
              type="date"
              value={sellerDateTo}
              min={sellerDateFrom}
              onChange={(e) => setSellerDateTo(e.target.value)}
              className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Seller</label>
            <select
              value={sellerFilter}
              onChange={(e) => setSellerFilter(e.target.value)}
              className="rounded-lg border border-gray-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              <option value="all">All Sellers</option>
              {sellerOptions.map((s) => (
                <option key={s.id} value={s.id}>{s.stall_name}</option>
              ))}
            </select>
          </div>
        </div>

        {sellerDailyLoading ? (
          <div className="py-8 text-center">
            <svg className="mx-auto h-6 w-6 animate-spin text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
          </div>
        ) : sellerDailySales.length === 0 ? (
          <p className="py-8 text-center text-sm text-gray-400">No sales data for this date range</p>
        ) : (
          <div className="overflow-hidden rounded-lg border border-gray-200">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">#</th>
                  <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Seller</th>
                  <th className="px-6 py-3 text-right text-xs font-semibold uppercase tracking-wider text-gray-500">No. of Sales</th>
                  <th className="px-6 py-3 text-right text-xs font-semibold uppercase tracking-wider text-gray-500">Total Amount</th>
                  <th className="px-6 py-3 text-right text-xs font-semibold uppercase tracking-wider text-gray-500">Avg / Sale</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 bg-white">
                {sellerDailySales.map((seller, i) => (
                  <tr key={seller.name} className="hover:bg-gray-50">
                    <td className="whitespace-nowrap px-6 py-3 text-sm text-gray-400">{i + 1}</td>
                    <td className="whitespace-nowrap px-6 py-3 text-sm font-medium text-gray-900">{seller.name}</td>
                    <td className="whitespace-nowrap px-6 py-3 text-sm text-gray-600 text-right">{seller.count}</td>
                    <td className="whitespace-nowrap px-6 py-3 text-sm font-medium text-gray-900 text-right">{formatMMK(seller.sales)}</td>
                    <td className="whitespace-nowrap px-6 py-3 text-sm text-gray-600 text-right">{formatMMK(seller.avg)}</td>
                  </tr>
                ))}
                <tr className="bg-gray-50 font-medium">
                  <td className="px-6 py-3 text-sm text-gray-500" colSpan={2}>Grand Total</td>
                  <td className="px-6 py-3 text-sm text-gray-700 text-right">{sellerDailyTotalCount}</td>
                  <td className="px-6 py-3 text-sm font-semibold text-gray-900 text-right">{formatMMK(sellerDailyTotal)}</td>
                  <td className="px-6 py-3 text-sm text-gray-700 text-right">
                    {formatMMK(sellerDailyTotalCount > 0 ? Math.round(sellerDailyTotal / sellerDailyTotalCount) : 0)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
