'use client';

import { authFetch } from '@/lib/auth-fetch';
import { useState, useEffect, useCallback } from 'react';
import { Banknote, Check, X, Loader2, CheckCircle } from 'lucide-react';
import { formatMMK } from '@/lib/types';

interface Payout {
  id: string;
  seller_id: string;
  amount: number;
  status: string;
  requested_at: string;
  approved_at: string | null;
  completed_at: string | null;
  rejection_reason: string | null;
  notes: string | null;
  canteen_sellers?: { stall_name: string; profiles?: { full_name: string } };
}

export default function PayoutsPage() {
  const [payouts, setPayouts] = useState<Payout[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const fetchPayouts = useCallback(async () => {
    const params = filter ? `?status=${filter}` : '';
    const res = await authFetch(`/api/payouts${params}`);
    const json = await res.json();
    if (json.success) setPayouts(json.data);
    setLoading(false);
  }, [filter]);

  useEffect(() => { fetchPayouts(); }, [fetchPayouts]);

  async function handleAction(id: string, action: string, rejectionReason?: string) {
    setActionLoading(id);
    await authFetch('/api/payouts', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, action, rejection_reason: rejectionReason }),
    });
    await fetchPayouts();
    setActionLoading(null);
  }

  function formatDate(d: string) {
    return new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  const statusColors: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-700',
    approved: 'bg-blue-100 text-blue-700',
    completed: 'bg-green-100 text-green-700',
    rejected: 'bg-red-100 text-red-700',
  };

  const pendingCount = payouts.filter(p => p.status === 'pending').length;

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <Banknote className="h-6 w-6 text-gray-400" />
            <h1 className="text-2xl font-bold text-gray-900">Seller Payouts</h1>
            {pendingCount > 0 && (
              <span className="rounded-full bg-yellow-100 px-2.5 py-0.5 text-xs font-medium text-yellow-700">
                {pendingCount} pending
              </span>
            )}
          </div>
          <p className="text-sm text-gray-500">Manage seller payout requests</p>
        </div>
        <div className="flex gap-2">
          {['', 'pending', 'approved', 'completed', 'rejected'].map(f => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`rounded-full px-3 py-1 text-sm font-medium ${filter === f ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
            >
              {f || 'All'}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><Loader2 className="h-6 w-6 animate-spin text-blue-600" /></div>
      ) : payouts.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12 text-center">
          <Banknote className="mx-auto h-12 w-12 text-gray-300" />
          <p className="mt-4 text-sm text-gray-400">No payout requests</p>
        </div>
      ) : (
        <div className="space-y-3">
          {payouts.map(p => {
            const seller = p.canteen_sellers;
            const sellerName = (seller?.profiles as Record<string, unknown>)?.full_name as string || 'Seller';
            const stallName = seller?.stall_name || '';

            return (
              <div key={p.id} className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
                <div className="flex items-center gap-4">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-sm font-semibold text-gray-900">{sellerName}</span>
                      <span className="text-xs text-gray-400">{stallName}</span>
                      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${statusColors[p.status] || ''}`}>
                        {p.status}
                      </span>
                    </div>
                    <p className="text-xs text-gray-400">{formatDate(p.requested_at)}</p>
                    {p.notes && <p className="text-xs text-gray-500 mt-1">Note: {p.notes}</p>}
                    {p.rejection_reason && <p className="text-xs text-red-500 mt-1">Reason: {p.rejection_reason}</p>}
                  </div>
                  <div className="text-right">
                    <p className="text-lg font-bold text-gray-900">{formatMMK(p.amount)}</p>
                  </div>
                  <div className="flex gap-2">
                    {p.status === 'pending' && (
                      <>
                        <button
                          onClick={() => handleAction(p.id, 'approve')}
                          disabled={actionLoading === p.id}
                          className="rounded-lg bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                        >
                          Approve
                        </button>
                        <button
                          onClick={() => {
                            const reason = prompt('Rejection reason (optional):');
                            handleAction(p.id, 'reject', reason || undefined);
                          }}
                          disabled={actionLoading === p.id}
                          className="rounded-lg border border-red-300 px-3 py-1.5 text-xs font-medium text-red-600 hover:bg-red-50 disabled:opacity-50"
                        >
                          Reject
                        </button>
                      </>
                    )}
                    {p.status === 'approved' && (
                      <button
                        onClick={() => handleAction(p.id, 'complete')}
                        disabled={actionLoading === p.id}
                        className="flex items-center gap-1 rounded-lg bg-green-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-green-700 disabled:opacity-50"
                      >
                        <CheckCircle className="h-3.5 w-3.5" /> Mark Paid
                      </button>
                    )}
                    {actionLoading === p.id && <Loader2 className="h-4 w-4 animate-spin" />}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
