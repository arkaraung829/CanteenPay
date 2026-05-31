'use client';

import { authFetch } from '@/lib/auth-fetch';

import { useState, useEffect, useCallback } from 'react';
import { Search, Download } from 'lucide-react';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';
import { useSchoolContext } from '@/lib/school-context';

interface TxRow {
  id: string;
  student: string;
  student_code: string;
  seller_name: string;
  type: string;
  amount: number;
  balance_after: number;
  description: string;
  performed_by: string;
  time: string;
  created_at: string;
}

export default function TransactionsPage() {
  const { selectedSchoolId } = useSchoolContext();
  const [transactions, setTransactions] = useState<TxRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [dateFilter, setDateFilter] = useState(() => {
    const today = new Date();
    return `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  });
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const PAGE_SIZE = 20;

  // Refund state
  const [refundTx, setRefundTx] = useState<TxRow | null>(null);
  const [refundReason, setRefundReason] = useState('');
  const [refundLoading, setRefundLoading] = useState(false);
  const [refundError, setRefundError] = useState('');

  const fetchTransactions = useCallback(async () => {
    setLoading(true);

    let query = supabase
      .from('transactions')
      .select(`
        id,
        type,
        amount,
        balance_after,
        description,
        created_at,
        performed_by,
        wallet:wallets(student:students(full_name, student_code, school_id)),
        performer:profiles!transactions_performed_by_fkey(full_name)
      `)
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);

    if (typeFilter !== 'all') {
      query = query.eq('type', typeFilter);
    }

    if (dateFilter) {
      // Convert local date boundaries to UTC for querying UTC timestamps.
      // Myanmar timezone is UTC+6:30, so local midnight = previous day 17:30 UTC.
      const localStart = new Date(`${dateFilter}T00:00:00`);
      const localEnd = new Date(`${dateFilter}T23:59:59`);
      const dayStartUTC = localStart.toISOString();
      const dayEndUTC = localEnd.toISOString();
      query = query.gte('created_at', dayStartUTC).lte('created_at', dayEndUTC);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching transactions:', error);
      // Try simpler query without performer join (in case foreign key name differs)
      const { data: simpleData } = await supabase
        .from('transactions')
        .select(`
          id,
          type,
          amount,
          balance_after,
          description,
          created_at,
          performed_by,
          wallet:wallets(student:students(full_name, school_id))
        `)
        .order('created_at', { ascending: false })
        .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);

      if (simpleData) {
        processData(simpleData);
      }
      setLoading(false);
      return;
    }

    processData(data || []);
    setLoading(false);
  }, [typeFilter, dateFilter, page, selectedSchoolId]);

  function processData(data: Record<string, unknown>[]) {
    // Filter by school_id if selected
    let filtered = data;
    if (selectedSchoolId) {
      filtered = data.filter((tx) => {
        const wallet = tx.wallet as Record<string, unknown> | null;
        const student = wallet?.student as Record<string, unknown> | null;
        return student?.school_id === selectedSchoolId;
      });
    }
    const mapped: TxRow[] = filtered.map((tx) => {
      const wallet = tx.wallet as Record<string, unknown> | null;
      const student = wallet?.student as Record<string, unknown> | null;
      const performer = tx.performer as Record<string, unknown> | null;
      const createdAt = tx.created_at as string;
      return {
        id: tx.id as string,
        student: (student?.full_name as string) || 'Unknown',
        student_code: (student?.student_code as string) || '',
        seller_name: (performer?.full_name as string) || '-',
        type: tx.type as string,
        amount: tx.amount as number,
        balance_after: tx.balance_after as number,
        description: (tx.description as string) || '-',
        performed_by: (performer?.full_name as string) || '-',
        time: createdAt,
        created_at: createdAt,
      };
    });

    setHasMore(mapped.length > PAGE_SIZE);
    setTransactions(mapped.slice(0, PAGE_SIZE));
  }

  useEffect(() => {
    fetchTransactions();
  }, [fetchTransactions]);

  async function handleRefund() {
    if (!refundTx) return;
    setRefundLoading(true);
    setRefundError('');
    try {
      const res = await authFetch('/api/refunds', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          transaction_id: refundTx.id,
          reason: refundReason || 'Admin refund',
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setRefundError(json.error || 'Refund failed');
        setRefundLoading(false);
        return;
      }
      setRefundTx(null);
      setRefundReason('');
      if (json.pending) {
        alert('Refund request sent to seller for approval.');
      } else {
        alert('Refund processed directly.');
      }
      fetchTransactions();
    } catch {
      setRefundError('Network error');
    }
    setRefundLoading(false);
  }

  const filtered = transactions.filter(tx => {
    if (search === '') return true;
    return tx.student.toLowerCase().includes(search.toLowerCase()) ||
      tx.description.toLowerCase().includes(search.toLowerCase());
  });

  function formatTime(isoStr: string): string {
    try {
      const d = new Date(isoStr);
      return d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false });
    } catch {
      return '-';
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Transactions</h1>
          <p className="mt-1 text-sm text-gray-500">All financial activity</p>
        </div>
        <button className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
          <Download className="h-4 w-4" /> Export CSV
        </button>
      </div>

      {/* Filters */}
      <div className="mb-4 flex gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by student or description..."
            className="w-full rounded-lg border border-gray-300 py-2 pl-10 pr-4 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>
        <select
          value={typeFilter}
          onChange={(e) => { setTypeFilter(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        >
          <option value="all">All Types</option>
          <option value="purchase">Purchases</option>
          <option value="deposit">Deposits</option>
          <option value="refund">Refunds</option>
        </select>
        <input
          type="date"
          value={dateFilter}
          onChange={(e) => { setDateFilter(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        />
      </div>

      {/* Transaction Table */}
      <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
        {loading ? (
          <div className="p-8 text-center">
            <svg className="mx-auto h-8 w-8 animate-spin text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
          </div>
        ) : (
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Time</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Student</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Student ID</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Type</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Amount</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Balance After</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Description</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Seller</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={9} className="px-6 py-8 text-center text-sm text-gray-400">
                    No transactions found
                  </td>
                </tr>
              ) : (
                filtered.map((tx) => (
                  <tr key={tx.id} className="hover:bg-gray-50">
                    <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 font-mono">
                      {formatTime(tx.time)}
                    </td>
                    <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-gray-900">{tx.student}</td>
                    <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 font-mono">{tx.student_code}</td>
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
                      tx.type === 'deposit' || tx.type === 'refund' ? 'text-green-600' : 'text-red-600'
                    }`}>
                      {tx.type === 'purchase' ? '-' : '+'}{formatMMK(tx.amount)}
                    </td>
                    <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500">{formatMMK(tx.balance_after)}</td>
                    <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500">{tx.description}</td>
                    <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-400">{tx.seller_name}</td>
                    <td className="whitespace-nowrap px-6 py-4">
                      {tx.type === 'purchase' && (
                        <button
                          onClick={() => { setRefundTx(tx); setRefundReason(''); setRefundError(''); }}
                          className="text-xs font-medium text-orange-600 hover:text-orange-800"
                        >
                          Refund
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination */}
      {!loading && (
        <div className="mt-4 flex items-center justify-between">
          <button
            onClick={() => setPage(p => Math.max(0, p - 1))}
            disabled={page === 0}
            className="rounded-lg border border-gray-200 px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50"
          >
            Previous
          </button>
          <span className="text-sm text-gray-500">Page {page + 1}</span>
          <button
            onClick={() => setPage(p => p + 1)}
            disabled={!hasMore && filtered.length < PAGE_SIZE}
            className="rounded-lg border border-gray-200 px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50"
          >
            Next
          </button>
        </div>
      )}
      {/* Refund Confirmation Modal */}
      {refundTx && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setRefundTx(null)}>
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start gap-3 mb-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-100 shrink-0">
                <svg className="h-5 w-5 text-orange-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
                </svg>
              </div>
              <div>
                <h3 className="text-base font-semibold text-gray-900">Refund Purchase</h3>
                <p className="mt-1 text-sm text-gray-500">
                  Refund <span className="font-medium text-gray-700">{formatMMK(refundTx.amount)}</span> to <span className="font-medium text-gray-700">{refundTx.student}</span> ({refundTx.student_code})?
                </p>
              </div>
            </div>
            {refundError && (
              <div className="mb-3 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{refundError}</div>
            )}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-1">Reason (optional)</label>
              <input
                type="text"
                value={refundReason}
                onChange={(e) => setRefundReason(e.target.value)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
                placeholder="e.g. Wrong amount charged"
              />
            </div>
            <div className="flex gap-3">
              <button onClick={() => setRefundTx(null)} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
              <button
                onClick={handleRefund}
                disabled={refundLoading}
                className="flex-1 rounded-lg bg-orange-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-orange-700 disabled:opacity-50"
              >
                {refundLoading ? 'Processing...' : 'Confirm Refund'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
