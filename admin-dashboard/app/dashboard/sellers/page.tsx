'use client';

import { useState } from 'react';
import { Plus, Store } from 'lucide-react';
import { formatMMK } from '@/lib/types';

const DEMO_SELLERS = [
  { id: '1', stall_name: 'Daw Aye Kitchen', stall_number: '#1', phone: '09-123-456789', is_active: true, today_sales: 45000, today_count: 28 },
  { id: '2', stall_name: 'Daw Ma Ma Rice', stall_number: '#2', phone: '09-987-654321', is_active: true, today_sales: 38000, today_count: 22 },
  { id: '3', stall_name: 'U Ko Ko Snacks', stall_number: '#3', phone: '09-111-222333', is_active: true, today_sales: 25500, today_count: 18 },
  { id: '4', stall_name: 'Noodle Corner', stall_number: '#4', phone: '09-444-555666', is_active: false, today_sales: 0, today_count: 0 },
];

export default function SellersPage() {
  const [showAddModal, setShowAddModal] = useState(false);

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

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        {DEMO_SELLERS.map((seller) => (
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
                  <p className="text-xs text-gray-500">Stall {seller.stall_number} &middot; {seller.phone}</p>
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

      {/* Add Seller Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowAddModal(false)}>
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-4">Add Canteen Seller</h2>
            <form className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Stall Name</label>
                <input type="text" className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="e.g., Daw Aye Kitchen" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Stall Number</label>
                <input type="text" className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="e.g., #5" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Operator Name</label>
                <input type="text" className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="Full name" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                <input type="tel" className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="09xxxxxxxxx" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email (for login)</label>
                <input type="email" className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="seller@example.com" />
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setShowAddModal(false)} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button type="button" onClick={() => setShowAddModal(false)} className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700">Add Seller</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
