'use client';

import { useState, useEffect, useCallback } from 'react';
import { Search, Download } from 'lucide-react';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';

interface TxRow {
  id: string;
  student: string;
  type: string;
  amount: number;
  balance_after: number;
  description: string;
  performed_by: string;
  time: string;
  created_at: string;
}

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState<TxRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [dateFilter, setDateFilter] = useState(() => new Date().toISOString().split('T')[0]);
  const [page, setPage] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const PAGE_SIZE = 20;

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
        wallet:wallets(student:students(full_name)),
        performer:profiles!transactions_performed_by_fkey(full_name)
      `)
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);

    if (typeFilter !== 'all') {
      query = query.eq('type', typeFilter);
    }

    if (dateFilter) {
      const dayStart = `${dateFilter}T00:00:00`;
      const dayEnd = `${dateFilter}T23:59:59`;
      query = query.gte('created_at', dayStart).lte('created_at', dayEnd);
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
          wallet:wallets(student:students(full_name))
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
  }, [typeFilter, dateFilter, page]);

  function processData(data: Record<string, unknown>[]) {
    const mapped: TxRow[] = data.map((tx) => {
      const wallet = tx.wallet as Record<string, unknown> | null;
      const student = wallet?.student as Record<string, unknown> | null;
      const performer = tx.performer as Record<string, unknown> | null;
      const createdAt = tx.created_at as string;
      return {
        id: tx.id as string,
        student: (student?.full_name as string) || 'Unknown',
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
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Type</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Amount</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Balance After</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Description</th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">By</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-8 text-center text-sm text-gray-400">
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
                    <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-400">{tx.performed_by}</td>
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
    </div>
  );
}
