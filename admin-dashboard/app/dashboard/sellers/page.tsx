'use client';

import { useState, useEffect, useCallback } from 'react';
import { Plus, Store } from 'lucide-react';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';

interface SellerRow {
  id: string;
  stall_name: string;
  stall_number: string | null;
  phone: string | null;
  is_active: boolean;
  today_sales: number;
  today_count: number;
}

export default function SellersPage() {
  const [sellers, setSellers] = useState<SellerRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [addLoading, setAddLoading] = useState(false);
  const [addError, setAddError] = useState('');

  // Form state
  const [newStallName, setNewStallName] = useState('');
  const [newStallNumber, setNewStallNumber] = useState('');
  const [newOperatorName, setNewOperatorName] = useState('');
  const [newPhone, setNewPhone] = useState('');
  const [newEmail, setNewEmail] = useState('');

  const fetchSellers = useCallback(async () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayISO = today.toISOString();

    // Fetch sellers with profile info
    const { data: sellersData, error } = await supabase
      .from('canteen_sellers')
      .select('id, stall_name, stall_number, is_active, profile:profiles(full_name, phone)')
      .order('stall_name');

    if (error) {
      console.error('Error fetching sellers:', error);
      setLoading(false);
      return;
    }

    // Fetch today's transactions grouped by seller
    const { data: txData } = await supabase
      .from('transactions')
      .select('seller_id, amount')
      .eq('type', 'purchase')
      .gte('created_at', todayISO)
      .not('seller_id', 'is', null);

    const salesMap: Record<string, { total: number; count: number }> = {};
    (txData || []).forEach((tx: Record<string, unknown>) => {
      const sellerId = tx.seller_id as string;
      if (!salesMap[sellerId]) salesMap[sellerId] = { total: 0, count: 0 };
      salesMap[sellerId].total += tx.amount as number;
      salesMap[sellerId].count += 1;
    });

    const mapped: SellerRow[] = (sellersData || []).map((s: Record<string, unknown>) => {
      const profile = s.profile as Record<string, unknown> | null;
      const sales = salesMap[s.id as string] || { total: 0, count: 0 };
      return {
        id: s.id as string,
        stall_name: s.stall_name as string,
        stall_number: s.stall_number as string | null,
        phone: (profile?.phone as string | null) || null,
        is_active: s.is_active as boolean,
        today_sales: sales.total,
        today_count: sales.count,
      };
    });

    setSellers(mapped);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchSellers();
  }, [fetchSellers]);

  async function handleAddSeller() {
    setAddLoading(true);
    setAddError('');

    // Get school id
    const { data: schools } = await supabase.from('schools').select('id').limit(1);
    const schoolId = schools?.[0]?.id;
    if (!schoolId) {
      setAddError('No school found. Please create a school first.');
      setAddLoading(false);
      return;
    }

    // Get current user as fallback profile_id
    const { data: { user } } = await supabase.auth.getUser();

    const { error } = await supabase.from('canteen_sellers').insert({
      stall_name: newStallName,
      stall_number: newStallNumber || null,
      school_id: schoolId,
      profile_id: user?.id || '',
      is_active: true,
    });

    if (error) {
      setAddError(error.message);
      setAddLoading(false);
      return;
    }

    setShowAddModal(false);
    setNewStallName('');
    setNewStallNumber('');
    setNewOperatorName('');
    setNewPhone('');
    setNewEmail('');
    setAddLoading(false);
    fetchSellers();
  }

  if (loading) {
    return (
      <div>
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Canteen Sellers</h1>
            <p className="mt-1 text-sm text-gray-500">Loading...</p>
          </div>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="h-48 animate-pulse rounded-xl border border-gray-200 bg-gray-100" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Canteen Sellers</h1>
          <p className="mt-1 text-sm text-gray-500">Manage canteen stall operators</p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> Add Seller
        </button>
      </div>

      {sellers.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12 text-center">
          <Store className="mx-auto h-12 w-12 text-gray-300" />
          <p className="mt-4 text-sm text-gray-400">No sellers registered yet</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {sellers.map((seller) => (
            <div key={seller.id} className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className={`flex h-12 w-12 items-center justify-center rounded-xl ${
                    seller.is_active ? 'bg-amber-100' : 'bg-gray-100'
                  }`}>
                    <Store className={`h-6 w-6 ${seller.is_active ? 'text-amber-600' : 'text-gray-400'}`} />
                  </div>
                  <div>
                    <h3 className="text-sm font-semibold text-gray-900">{seller.stall_name}</h3>
                    <p className="text-xs text-gray-500">
                      {seller.stall_number ? `Stall ${seller.stall_number}` : 'No stall number'}
                      {seller.phone ? ` \u00B7 ${seller.phone}` : ''}
                    </p>
                  </div>
                </div>
                <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                  seller.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                }`}>
                  {seller.is_active ? 'Active' : 'Closed'}
                </span>
              </div>

              <div className="mt-4 grid grid-cols-2 gap-4">
                <div className="rounded-lg bg-gray-50 p-3">
                  <p className="text-xs text-gray-500">Today&apos;s Sales</p>
                  <p className="mt-1 text-lg font-bold text-gray-900">{formatMMK(seller.today_sales)}</p>
                </div>
                <div className="rounded-lg bg-gray-50 p-3">
                  <p className="text-xs text-gray-500">Transactions</p>
                  <p className="mt-1 text-lg font-bold text-gray-900">{seller.today_count}</p>
                </div>
              </div>

              <div className="mt-4 flex gap-2">
                <button className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
                  View History
                </button>
                <button className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
                  Edit
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add Seller Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowAddModal(false)}>
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-4">Add Canteen Seller</h2>
            {addError && (
              <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {addError}
              </div>
            )}
            <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); handleAddSeller(); }}>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Stall Name</label>
                <input
                  type="text"
                  required
                  value={newStallName}
                  onChange={(e) => setNewStallName(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="e.g., Daw Aye Kitchen"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Stall Number</label>
                <input
                  type="text"
                  value={newStallNumber}
                  onChange={(e) => setNewStallNumber(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="e.g., #5"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Operator Name</label>
                <input
                  type="text"
                  value={newOperatorName}
                  onChange={(e) => setNewOperatorName(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="Full name"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                <input
                  type="tel"
                  value={newPhone}
                  onChange={(e) => setNewPhone(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="09xxxxxxxxx"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email (for login)</label>
                <input
                  type="email"
                  value={newEmail}
                  onChange={(e) => setNewEmail(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="seller@example.com"
                />
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => { setShowAddModal(false); setAddError(''); }} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button type="submit" disabled={addLoading} className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">
                  {addLoading ? 'Adding...' : 'Add Seller'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
