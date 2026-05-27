'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { Plus, School, Users, Banknote, Loader2, X, Pencil, Check } from 'lucide-react';
import { useSchoolContext } from '@/lib/school-context';
import { formatMMK } from '@/lib/types';

interface SchoolRow {
  id: string;
  name: string;
  name_my: string | null;
  code: string;
  address: string | null;
  phone: string | null;
  is_active: boolean;
  student_count: number;
  total_balance: number;
}

export default function SchoolsPage() {
  const { userRole } = useSchoolContext();
  const router = useRouter();
  const [schools, setSchools] = useState<SchoolRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [addLoading, setAddLoading] = useState(false);
  const [addError, setAddError] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editData, setEditData] = useState<Partial<SchoolRow>>({});
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  // Add form state
  const [newName, setNewName] = useState('');
  const [newNameMy, setNewNameMy] = useState('');
  const [newCode, setNewCode] = useState('');
  const [newAddress, setNewAddress] = useState('');
  const [newPhone, setNewPhone] = useState('');

  // Redirect non-super_admin users
  useEffect(() => {
    if (userRole !== 'super_admin') {
      router.push('/dashboard');
    }
  }, [userRole, router]);

  const fetchSchools = useCallback(async () => {
    try {
      const res = await fetch('/api/schools');
      const json = await res.json();
      if (json.success) {
        setSchools(json.data);
      }
    } catch {
      // silently fail
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchSchools();
  }, [fetchSchools]);

  async function handleAddSchool() {
    setAddLoading(true);
    setAddError('');

    try {
      const res = await fetch('/api/schools', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: newName,
          name_my: newNameMy || null,
          code: newCode,
          address: newAddress || null,
          phone: newPhone || null,
        }),
      });

      const json = await res.json();
      if (!json.success) {
        setAddError(json.error || 'Failed to add school');
        setAddLoading(false);
        return;
      }

      setShowAddModal(false);
      setNewName('');
      setNewNameMy('');
      setNewCode('');
      setNewAddress('');
      setNewPhone('');
      fetchSchools();
    } catch {
      setAddError('Network error');
    }
    setAddLoading(false);
  }

  async function handleToggleActive(school: SchoolRow) {
    setActionLoading(school.id);
    try {
      await fetch('/api/schools', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: school.id, is_active: !school.is_active }),
      });
      await fetchSchools();
    } catch {
      // silently fail
    }
    setActionLoading(null);
  }

  async function handleSaveEdit(id: string) {
    setActionLoading(id);
    try {
      await fetch('/api/schools', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, ...editData }),
      });
      setEditingId(null);
      setEditData({});
      await fetchSchools();
    } catch {
      // silently fail
    }
    setActionLoading(null);
  }

  if (userRole !== 'super_admin') {
    return null;
  }

  if (loading) {
    return (
      <div>
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Schools</h1>
            <p className="mt-1 text-sm text-gray-500">Loading...</p>
          </div>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {[1, 2, 3].map(i => (
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
          <h1 className="text-2xl font-bold text-gray-900">Schools</h1>
          <p className="mt-1 text-sm text-gray-500">{schools.length} registered schools</p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> Add School
        </button>
      </div>

      {schools.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12 text-center">
          <School className="mx-auto h-12 w-12 text-gray-300" />
          <p className="mt-4 text-sm text-gray-400">No schools registered yet</p>
          <button
            onClick={() => setShowAddModal(true)}
            className="mt-4 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Plus className="h-4 w-4" /> Add School
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {schools.map((school) => (
            <div key={school.id} className={`rounded-xl border border-gray-200 bg-white p-6 shadow-sm ${!school.is_active ? 'opacity-60' : ''}`}>
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-3">
                  <div className={`flex h-12 w-12 items-center justify-center rounded-xl ${
                    school.is_active ? 'bg-blue-100' : 'bg-gray-100'
                  }`}>
                    <School className={`h-6 w-6 ${school.is_active ? 'text-blue-600' : 'text-gray-400'}`} />
                  </div>
                  <div>
                    {editingId === school.id ? (
                      <input
                        type="text"
                        value={editData.name ?? school.name}
                        onChange={(e) => setEditData({ ...editData, name: e.target.value })}
                        className="w-full rounded border border-gray-300 px-2 py-1 text-sm font-semibold focus:border-blue-500 focus:outline-none"
                      />
                    ) : (
                      <h3 className="text-sm font-semibold text-gray-900">{school.name}</h3>
                    )}
                    <p className="text-xs text-gray-500">
                      Code: {school.code}
                      {school.phone ? ` \u00B7 ${school.phone}` : ''}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  {editingId === school.id ? (
                    <>
                      <button
                        onClick={() => handleSaveEdit(school.id)}
                        disabled={actionLoading === school.id}
                        className="rounded p-1 text-green-600 hover:bg-green-50"
                      >
                        {actionLoading === school.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
                      </button>
                      <button
                        onClick={() => { setEditingId(null); setEditData({}); }}
                        className="rounded p-1 text-gray-400 hover:bg-gray-100"
                      >
                        <X className="h-4 w-4" />
                      </button>
                    </>
                  ) : (
                    <button
                      onClick={() => { setEditingId(school.id); setEditData({ name: school.name }); }}
                      className="rounded p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600"
                    >
                      <Pencil className="h-4 w-4" />
                    </button>
                  )}
                </div>
              </div>

              {school.address && editingId !== school.id && (
                <p className="mt-2 text-xs text-gray-400 truncate">{school.address}</p>
              )}

              <div className="mt-4 grid grid-cols-2 gap-3">
                <div className="rounded-lg bg-gray-50 p-3">
                  <div className="flex items-center gap-1.5">
                    <Users className="h-3.5 w-3.5 text-gray-400" />
                    <p className="text-xs text-gray-500">Students</p>
                  </div>
                  <p className="mt-1 text-lg font-bold text-gray-900">{school.student_count}</p>
                </div>
                <div className="rounded-lg bg-gray-50 p-3">
                  <div className="flex items-center gap-1.5">
                    <Banknote className="h-3.5 w-3.5 text-gray-400" />
                    <p className="text-xs text-gray-500">Balance</p>
                  </div>
                  <p className="mt-1 text-lg font-bold text-gray-900">{formatMMK(school.total_balance)}</p>
                </div>
              </div>

              <div className="mt-4 flex items-center justify-between">
                <button
                  onClick={() => handleToggleActive(school)}
                  disabled={actionLoading === school.id}
                  className="flex items-center gap-2"
                >
                  <div className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                    school.is_active ? 'bg-green-500' : 'bg-gray-300'
                  }`}>
                    <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                      school.is_active ? 'translate-x-4' : 'translate-x-1'
                    }`} />
                  </div>
                  <span className={`text-xs font-medium ${
                    school.is_active ? 'text-green-700' : 'text-gray-500'
                  }`}>
                    {school.is_active ? 'Active' : 'Inactive'}
                  </span>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add School Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowAddModal(false)}>
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-4">Add New School</h2>
            {addError && (
              <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {addError}
              </div>
            )}
            <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); handleAddSchool(); }}>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">School Name</label>
                <input type="text" required value={newName} onChange={(e) => setNewName(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="Enter school name" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">School Name (Myanmar)</label>
                <input type="text" value={newNameMy} onChange={(e) => setNewNameMy(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="Enter Myanmar name" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">School Code</label>
                <input type="text" required value={newCode} onChange={(e) => setNewCode(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="e.g., SCH-001" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Address</label>
                <input type="text" value={newAddress} onChange={(e) => setNewAddress(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="School address" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                <input type="tel" value={newPhone} onChange={(e) => setNewPhone(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="09xxxxxxxxx" />
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => { setShowAddModal(false); setAddError(''); }} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button type="submit" disabled={addLoading} className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">
                  {addLoading ? 'Adding...' : 'Add School'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
