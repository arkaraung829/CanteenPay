'use client';

import { useState } from 'react';
import { Search, Filter, Download } from 'lucide-react';
import { formatMMK } from '@/lib/types';

const DEMO_TRANSACTIONS = [
  { id: 't1', student: 'Aung Kyaw Zin', type: 'purchase', amount: 1500, balance_after: 13500, description: 'Lunch', seller: 'Daw Aye - Stall #1', time: '2025-05-25 11:32', performed_by: 'Daw Aye' },
  { id: 't2', student: 'Thin Thin Aye', type: 'deposit', amount: 20000, balance_after: 28500, description: 'Cash deposit', seller: '-', time: '2025-05-25 11:15', performed_by: 'U Tin (Counter)' },
  { id: 't3', student: 'Min Thant Zaw', type: 'purchase', amount: 2000, balance_after: 1200, description: 'Snacks', seller: 'U Ko Ko - Stall #3', time: '2025-05-25 10:58', performed_by: 'U Ko Ko' },
  { id: 't4', student: 'Su Su Lwin', type: 'purchase', amount: 1000, balance_after: 21000, description: 'Drinks', seller: 'Daw Aye - Stall #1', time: '2025-05-25 10:45', performed_by: 'Daw Aye' },
  { id: 't5', student: 'Htet Aung', type: 'deposit', amount: 10000, balance_after: 10500, description: 'Cash deposit', seller: '-', time: '2025-05-25 10:30', performed_by: 'U Tin (Counter)' },
  { id: 't6', student: 'Phyu Phyu Win', type: 'refund', amount: 500, balance_after: 11700, description: 'Wrong charge refund', seller: 'U Ko Ko - Stall #3', time: '2025-05-25 10:22', performed_by: 'Admin' },
  { id: 't7', student: 'Aung Kyaw Zin', type: 'purchase', amount: 1800, balance_after: 15000, description: 'Lunch set', seller: 'Daw Ma Ma - Stall #2', time: '2025-05-25 10:10', performed_by: 'Daw Ma Ma' },
  { id: 't8', student: 'Hnin Si Thu', type: 'purchase', amount: 2500, balance_after: 5000, description: 'Rice and curry', seller: 'Daw Aye - Stall #1', time: '2025-05-25 09:55', performed_by: 'Daw Aye' },
];

export default function TransactionsPage() {
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');

  const filtered = DEMO_TRANSACTIONS.filter(tx => {
    const matchesSearch = search === '' ||
      tx.student.toLowerCase().includes(search.toLowerCase()) ||
      tx.description.toLowerCase().includes(search.toLowerCase());
    const matchesType = typeFilter === 'all' || tx.type === typeFilter;
    return matchesSearch && matchesType;
  });

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
          onChange={(e) => setTypeFilter(e.target.value)}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        >
          <option value="all">All Types</option>
          <option value="purchase">Purchases</option>
          <option value="deposit">Deposits</option>
          <option value="refund">Refunds</option>
        </select>
        <input
          type="date"
          defaultValue="2025-05-25"
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        />
      </div>

      {/* Transaction Table */}
      <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
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
            {filtered.map((tx) => (
              <tr key={tx.id} className="hover:bg-gray-50">
                <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 font-mono">
                  {tx.time.split(' ')[1]}
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
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
