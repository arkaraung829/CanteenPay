'use client';

import { useState, useEffect, useCallback } from 'react';
import { Plus, Store, X, Loader2 } from 'lucide-react';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';
import { useSchoolContext } from '@/lib/school-context';

interface SellerRow {
  id: string;
  stall_name: string;
  stall_number: string | null;
  phone: string | null;
  email: string | null;
  is_active: boolean;
  today_sales: number;
  today_count: number;
}

export default function SellersPage() {
  const { selectedSchoolId } = useSchoolContext();
  const [sellers, setSellers] = useState<SellerRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [addLoading, setAddLoading] = useState(false);
  const [addError, setAddError] = useState('');

  // Add form state
  const [newStallName, setNewStallName] = useState('');
  const [newStallNumber, setNewStallNumber] = useState('');
  const [newOperatorName, setNewOperatorName] = useState('');
  const [newPhone, setNewPhone] = useState('');
  const [newEmail, setNewEmail] = useState('');

  // Edit state
  const [editSeller, setEditSeller] = useState<SellerRow | null>(null);
  const [editStallName, setEditStallName] = useState('');
  const [editStallNumber, setEditStallNumber] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editEmail, setEditEmail] = useState('');
  const [editActive, setEditActive] = useState(true);
  const [editLoading, setEditLoading] = useState(false);
  const [editError, setEditError] = useState('');

  const fetchSellers = useCallback(async () => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayISO = today.toISOString();

    // Fetch sellers with profile info
    let sellersQuery = supabase
      .from('canteen_sellers')
      .select('id, stall_name, stall_number, is_active, phone, email, profile:profiles(full_name, phone)')
      .order('stall_name');

    if (selectedSchoolId) {
      sellersQuery = sellersQuery.eq('school_id', selectedSchoolId);
    }

    const { data: sellersData, error } = await sellersQuery;

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
        phone: (s.phone as string | null) || (profile?.phone as string | null) || null,
        email: (s.email as string | null) || null,
        is_active: s.is_active as boolean,
        today_sales: sales.total,
        today_count: sales.count,
      };
    });

    setSellers(mapped);
    setLoading(false);
  }, [selectedSchoolId]);

  useEffect(() => {
    fetchSellers();
  }, [fetchSellers]);

  async function handleAddSeller() {
    setAddLoading(true);
    setAddError('');

    // Get school id - use selected school or fall back to first school
    let schoolId = selectedSchoolId;
    if (!schoolId) {
      const { data: schools } = await supabase.from('schools').select('id').limit(1);
      schoolId = schools?.[0]?.id;
    }
    if (!schoolId) {
      setAddError('No school found. Please create a school first.');
      setAddLoading(false);
      return;
    }

    // Normalize phone
    let normalizedPhone: string | null = null;
    if (newPhone) {
      let ph = newPhone.replace(/\s+/g, '');
      if (ph.startsWith('0')) ph = '+95' + ph.substring(1);
      else if (!ph.startsWith('+')) ph = '+' + ph;
      normalizedPhone = ph;
    }

    const { error } = await supabase.from('canteen_sellers').insert({
      stall_name: newStallName,
      stall_number: newStallNumber || null,
      school_id: schoolId,
      phone: normalizedPhone,
      email: newEmail ? newEmail.toLowerCase() : null,
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

  function openEditModal(seller: SellerRow) {
    setEditSeller(seller);
    setEditStallName(seller.stall_name);
    setEditStallNumber(seller.stall_number || '');
    setEditPhone(seller.phone || '');
    setEditEmail(seller.email || '');
    setEditActive(seller.is_active);
    setEditError('');
  }

  async function handleEditSeller() {
    if (!editSeller) return;
    setEditLoading(true);
    setEditError('');

    let normalizedPhone: string | null = null;
    if (editPhone) {
      let ph = editPhone.replace(/\s+/g, '');
      if (ph.startsWith('0')) ph = '+95' + ph.substring(1);
      else if (!ph.startsWith('+')) ph = '+' + ph;
      normalizedPhone = ph;
    }

    try {
      const res = await fetch('/api/sellers', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: editSeller.id,
          stall_name: editStallName,
          stall_number: editStallNumber || null,
          phone: normalizedPhone,
          email: editEmail ? editEmail.toLowerCase() : null,
          is_active: editActive,
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setEditError(json.error || 'Failed to update seller');
        setEditLoading(false);
        return;
      }
    } catch {
      setEditError('Network error');
      setEditLoading(false);
      return;
    }

    setEditSeller(null);
    setEditLoading(false);
    fetchSellers();
  }

  async function handleDeleteSeller() {
    if (!editSeller || !confirm('Are you sure you want to delete this seller? This cannot be undone.')) return;
    setEditLoading(true);

    try {
      const res = await fetch('/api/sellers', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: editSeller.id }),
      });
      const json = await res.json();
      if (!json.success) {
        setEditError(json.error || 'Failed to delete seller');
        setEditLoading(false);
        return;
      }
    } catch {
      setEditError('Network error');
      setEditLoading(false);
      return;
    }

    setEditSeller(null);
    setEditLoading(false);
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
                      {seller.email ? ` \u00B7 ${seller.email}` : ''}
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
                <button
                  onClick={() => window.location.href = `/dashboard/transactions?seller=${seller.id}`}
                  className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
                >
                  View History
                </button>
                <button
                  onClick={() => openEditModal(seller)}
                  className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
                >
                  Edit
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Edit Seller Modal */}
      {editSeller && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setEditSeller(null)}>
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-gray-900">Edit Seller</h2>
              <button onClick={() => setEditSeller(null)} className="rounded-lg p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600">
                <X className="h-5 w-5" />
              </button>
            </div>
            {editError && (
              <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {editError}
              </div>
            )}
            <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); handleEditSeller(); }}>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Stall Name</label>
                <input
                  type="text"
                  required
                  value={editStallName}
                  onChange={(e) => setEditStallName(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Stall Number</label>
                <input
                  type="text"
                  value={editStallNumber}
                  onChange={(e) => setEditStallNumber(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="e.g., A-1"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                <input
                  type="tel"
                  value={editPhone}
                  onChange={(e) => setEditPhone(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="09xxxxxxxxx"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input
                  type="email"
                  value={editEmail}
                  onChange={(e) => setEditEmail(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  placeholder="seller@example.com"
                />
              </div>
              <div className="flex items-center justify-between">
                <label className="text-sm font-medium text-gray-700">Active</label>
                <button
                  type="button"
                  onClick={() => setEditActive(!editActive)}
                  className="shrink-0"
                >
                  <div className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                    editActive ? 'bg-green-500' : 'bg-gray-300'
                  }`}>
                    <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                      editActive ? 'translate-x-6' : 'translate-x-1'
                    }`} />
                  </div>
                </button>
              </div>
              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={handleDeleteSeller}
                  disabled={editLoading}
                  className="rounded-lg border border-red-300 px-4 py-2.5 text-sm font-medium text-red-600 hover:bg-red-50 disabled:opacity-50"
                >
                  Delete
                </button>
                <div className="flex-1" />
                <button
                  type="button"
                  onClick={() => setEditSeller(null)}
                  className="rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={editLoading || !editStallName.trim()}
                  className="rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                >
                  {editLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Save'}
                </button>
              </div>
            </form>
          </div>
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
