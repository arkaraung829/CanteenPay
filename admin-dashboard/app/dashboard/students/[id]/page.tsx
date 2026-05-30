'use client';

import { authFetch } from '@/lib/auth-fetch';

import { useState, useEffect, useRef, useCallback } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { ArrowLeft, Printer, Edit3, Save, X, RefreshCw, User, Download } from 'lucide-react';
import QRCode from 'qrcode';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';

interface StudentDetail {
  id: string;
  student_code: string;
  full_name: string;
  full_name_my: string | null;
  class_name: string | null;
  grade: string | null;
  is_active: boolean;
  qr_data: string;
  pin_code: string;
  daily_spending_limit: number | null;
  balance: number;
  school_name: string;
  date_of_birth: string | null;
  parent_phone: string | null;
  parent_email: string | null;
}

interface TransactionRow {
  id: string;
  type: string;
  amount: number;
  balance_before: number;
  balance_after: number;
  description: string | null;
  created_at: string;
}

interface ParentLink {
  id: string;
  full_name: string;
  phone: string | null;
  email: string | null;
}

export default function StudentDetailPage() {
  const params = useParams();
  const id = params.id as string;

  const [student, setStudent] = useState<StudentDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [editForm, setEditForm] = useState({ full_name: '', full_name_my: '', grade: '', class_name: '', daily_spending_limit: '', date_of_birth: '', parent_phone: '', parent_email: '', pin_code: '' });
  const [editLoading, setEditLoading] = useState(false);
  const [editError, setEditError] = useState('');

  const [transactions, setTransactions] = useState<TransactionRow[]>([]);
  const [txLoading, setTxLoading] = useState(true);

  const [parents, setParents] = useState<ParentLink[]>([]);

  const [regenerating, setRegenerating] = useState(false);
  const [showRegenConfirm, setShowRegenConfirm] = useState(false);

  // Link parent state
  const [showLinkParent, setShowLinkParent] = useState(false);
  const [linkParentPhone, setLinkParentPhone] = useState('');
  const [linkParentEmail, setLinkParentEmail] = useState('');
  const [linkLoading, setLinkLoading] = useState(false);
  const [linkError, setLinkError] = useState('');

  const qrCanvasRef = useRef<HTMLCanvasElement>(null);
  const printQrCanvasRef = useRef<HTMLCanvasElement>(null);

  const generateQR = useCallback(async (qrData: string) => {
    const deepLink = `paynowmm://pay/${qrData}`;
    if (qrCanvasRef.current) {
      await QRCode.toCanvas(qrCanvasRef.current, deepLink, {
        width: 200,
        margin: 2,
        color: { dark: '#000000', light: '#ffffff' },
      });
    }
    if (printQrCanvasRef.current) {
      await QRCode.toCanvas(printQrCanvasRef.current, deepLink, {
        width: 160,
        margin: 1,
        color: { dark: '#000000', light: '#ffffff' },
      });
    }
  }, []);

  const fetchStudent = useCallback(async () => {
    const { data, error } = await supabase
      .from('students')
      .select('id, student_code, full_name, full_name_my, class_name, grade, is_active, qr_data, pin_code, daily_spending_limit, date_of_birth, parent_phone, parent_email, wallets(balance), schools(name)')
      .eq('id', id)
      .single();

    if (error || !data) {
      console.error('Error fetching student:', error);
      setLoading(false);
      return;
    }

    const wallets = data.wallets as Array<{ balance: number }> | { balance: number } | null;
    let balance = 0;
    if (Array.isArray(wallets) && wallets.length > 0) {
      balance = wallets[0].balance || 0;
    } else if (wallets && !Array.isArray(wallets)) {
      balance = wallets.balance || 0;
    }

    const schoolsRaw = data.schools as unknown;
    let schoolName = 'Paynow MM School';
    if (Array.isArray(schoolsRaw) && schoolsRaw.length > 0) {
      schoolName = schoolsRaw[0].name || schoolName;
    } else if (schoolsRaw && typeof schoolsRaw === 'object' && 'name' in schoolsRaw) {
      schoolName = (schoolsRaw as { name: string }).name || schoolName;
    }

    const s: StudentDetail = {
      id: data.id as string,
      student_code: data.student_code as string,
      full_name: data.full_name as string,
      full_name_my: data.full_name_my as string | null,
      class_name: data.class_name as string | null,
      grade: data.grade as string | null,
      is_active: data.is_active as boolean,
      qr_data: data.qr_data as string,
      pin_code: (data.pin_code as string) || '',
      daily_spending_limit: data.daily_spending_limit as number | null,
      balance,
      school_name: schoolName,
      date_of_birth: data.date_of_birth as string | null,
      parent_phone: data.parent_phone as string | null,
      parent_email: data.parent_email as string | null,
    };

    setStudent(s);
    setEditForm({
      full_name: s.full_name,
      full_name_my: s.full_name_my || '',
      grade: s.grade || '',
      class_name: s.class_name || '',
      daily_spending_limit: s.daily_spending_limit ? String(s.daily_spending_limit) : '',
      date_of_birth: s.date_of_birth || '',
      parent_phone: s.parent_phone || '',
      parent_email: s.parent_email || '',
      pin_code: s.pin_code || '',
    });
    setLoading(false);
  }, [id]);

  // Fetch transactions
  const fetchTransactions = useCallback(async () => {
    setTxLoading(true);
    // First get wallet_id for this student
    const { data: walletData } = await supabase
      .from('wallets')
      .select('id')
      .eq('student_id', id)
      .single();

    if (!walletData) {
      setTxLoading(false);
      return;
    }

    const { data: txData } = await supabase
      .from('transactions')
      .select('id, type, amount, balance_before, balance_after, description, created_at')
      .eq('wallet_id', walletData.id)
      .order('created_at', { ascending: false })
      .limit(20);

    setTransactions((txData || []) as TransactionRow[]);
    setTxLoading(false);
  }, [id]);

  // Fetch linked parents
  const fetchParents = useCallback(async () => {
    const { data } = await supabase
      .from('parent_student_links')
      .select('parent_id, profiles!parent_student_links_parent_id_fkey(id, full_name, phone)')
      .eq('student_id', id);

    if (data) {
      const mapped: ParentLink[] = [];
      for (const row of data) {
        const profile = row.profiles as unknown;
        if (profile && typeof profile === 'object' && 'id' in profile) {
          const p = profile as { id: string; full_name: string; phone: string | null; email: string | null };
          mapped.push({ id: p.id, full_name: p.full_name, phone: p.phone, email: p.email });
        }
      }
      setParents(mapped);
    }
  }, [id]);

  useEffect(() => {
    fetchStudent();
    fetchTransactions();
    fetchParents();
  }, [fetchStudent, fetchTransactions, fetchParents]);

  useEffect(() => {
    if (student?.qr_data) {
      generateQR(student.qr_data);
    }
  }, [student, generateQR]);

  async function handleLinkParent() {
    if (!linkParentPhone && !linkParentEmail) {
      setLinkError('Enter at least a phone or email');
      return;
    }
    setLinkLoading(true);
    setLinkError('');

    try {
      const updates: Record<string, string | null> = {};
      if (linkParentPhone) {
        let ph = linkParentPhone.replace(/\s+/g, '');
        if (ph.startsWith('0')) ph = '+95' + ph.substring(1);
        else if (!ph.startsWith('+')) ph = '+' + ph;
        updates.parent_phone = ph;
      }
      if (linkParentEmail) {
        updates.parent_email = linkParentEmail.toLowerCase();
      }

      const { error } = await supabase
        .from('students')
        .update(updates)
        .eq('id', id);

      if (error) {
        setLinkError(error.message);
      } else {
        // Refresh student data
        if (student) {
          setStudent({
            ...student,
            parent_phone: updates.parent_phone || student.parent_phone,
            parent_email: updates.parent_email || student.parent_email,
          });
        }
        setShowLinkParent(false);
        setLinkParentPhone('');
        setLinkParentEmail('');
      }
    } catch {
      setLinkError('Failed to save');
    }
    setLinkLoading(false);
  }

  async function handleSaveEdit() {
    setEditLoading(true);
    setEditError('');

    try {
      const res = await authFetch('/api/students', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id,
          full_name: editForm.full_name,
          full_name_my: editForm.full_name_my || null,
          grade: editForm.grade || null,
          class_name: editForm.class_name || null,
          daily_spending_limit: editForm.daily_spending_limit ? parseInt(editForm.daily_spending_limit) : null,
          date_of_birth: editForm.date_of_birth || null,
          parent_phone: editForm.parent_phone || null,
          parent_email: editForm.parent_email ? editForm.parent_email.toLowerCase() : null,
          pin_code: editForm.pin_code || null,
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setEditError(json.error || 'Failed to update');
        setEditLoading(false);
        return;
      }
      setEditing(false);
      fetchStudent();
    } catch {
      setEditError('Network error');
    }
    setEditLoading(false);
  }

  async function handleRegenerateQR() {
    setRegenerating(true);
    const newQR = crypto.randomUUID();
    const { error } = await supabase
      .from('students')
      .update({ qr_data: newQR })
      .eq('id', id);

    if (!error) {
      fetchStudent();
    }
    setRegenerating(false);
    setShowRegenConfirm(false);
  }

  function handlePrint() {
    window.print();
  }

  if (loading) {
    return (
      <div>
        <div className="mb-6">
          <Link href="/dashboard/students" className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
            <ArrowLeft className="h-4 w-4" /> Back to Students
          </Link>
        </div>
        <div className="space-y-4">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-20 animate-pulse rounded-lg bg-gray-100" />
          ))}
        </div>
      </div>
    );
  }

  if (!student) {
    return (
      <div>
        <div className="mb-6">
          <Link href="/dashboard/students" className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
            <ArrowLeft className="h-4 w-4" /> Back to Students
          </Link>
        </div>
        <p className="text-gray-500">Student not found.</p>
      </div>
    );
  }

  return (
    <div>
      {/* Screen view */}
      <div className="print:hidden">
        <div className="mb-6">
          <Link href="/dashboard/students" className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
            <ArrowLeft className="h-4 w-4" /> Back to Students
          </Link>
        </div>

        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{student.full_name}</h1>
            {student.full_name_my && (
              <p className="text-sm text-gray-500">{student.full_name_my}</p>
            )}
          </div>
          <div className="flex gap-2">
            {!editing && (
              <button
                onClick={() => setEditing(true)}
                className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
              >
                <Edit3 className="h-4 w-4" /> Edit Student
              </button>
            )}
            <button
              onClick={handlePrint}
              className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
            >
              <Printer className="h-4 w-4" /> Print Card
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Student Info / Edit Form */}
          <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Student Information</h2>
            {editing ? (
              <div className="space-y-3">
                {editError && (
                  <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{editError}</div>
                )}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                  <input type="text" value={editForm.full_name} onChange={(e) => setEditForm(f => ({ ...f, full_name: e.target.value }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Full Name (Myanmar)</label>
                  <input type="text" value={editForm.full_name_my} onChange={(e) => setEditForm(f => ({ ...f, full_name_my: e.target.value }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Grade</label>
                    <select value={editForm.grade} onChange={(e) => setEditForm(f => ({ ...f, grade: e.target.value }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500">
                      <option value="">-</option>
                      {[1,2,3,4,5,6,7,8,9,10,11].map(g => (
                        <option key={g} value={g}>Grade {g}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Class</label>
                    <input type="text" value={editForm.class_name} onChange={(e) => setEditForm(f => ({ ...f, class_name: e.target.value }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="e.g. Grade 5-A" />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">PIN Code (4 digits)</label>
                  <input type="text" value={editForm.pin_code} onChange={(e) => setEditForm(f => ({ ...f, pin_code: e.target.value.replace(/\D/g, '').slice(0, 4) }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono tracking-widest focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="e.g. 1234" maxLength={4} />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Daily Spending Limit (MMK)</label>
                  <input type="number" value={editForm.daily_spending_limit} onChange={(e) => setEditForm(f => ({ ...f, daily_spending_limit: e.target.value }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="Leave empty for no limit" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Parent Phone</label>
                  <input type="tel" value={editForm.parent_phone} onChange={(e) => setEditForm(f => ({ ...f, parent_phone: e.target.value }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="09xxxxxxxxx" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Parent Email (for Google Sign-In)</label>
                  <input type="email" value={editForm.parent_email} onChange={(e) => setEditForm(f => ({ ...f, parent_email: e.target.value }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="parent@gmail.com" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Date of Birth</label>
                  <input type="text" value={editForm.date_of_birth} onChange={(e) => setEditForm(f => ({ ...f, date_of_birth: e.target.value }))} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="YYYYMMDD (e.g., 20150315)" maxLength={8} />
                </div>
                <div className="flex gap-3 pt-2">
                  <button onClick={() => { setEditing(false); setEditError(''); }} className="flex items-center gap-1 flex-1 justify-center rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50">
                    <X className="h-4 w-4" /> Cancel
                  </button>
                  <button onClick={handleSaveEdit} disabled={editLoading} className="flex items-center gap-1 flex-1 justify-center rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">
                    <Save className="h-4 w-4" /> {editLoading ? 'Saving...' : 'Save'}
                  </button>
                </div>
              </div>
            ) : (
              <dl className="space-y-3">
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">Student Code</dt>
                  <dd className="text-sm font-mono font-medium text-gray-900">{student.student_code}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">PIN Code</dt>
                  <dd className="text-sm font-mono font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded">{student.pin_code}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">Class</dt>
                  <dd className="text-sm text-gray-900">{student.class_name || '-'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">Grade</dt>
                  <dd className="text-sm text-gray-900">{student.grade ? `Grade ${student.grade}` : '-'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">Balance</dt>
                  <dd className={`text-sm font-medium ${student.balance < 1000 ? 'text-red-600' : 'text-gray-900'}`}>
                    {formatMMK(student.balance)}
                  </dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">Daily Spending Limit</dt>
                  <dd className="text-sm text-gray-900">{student.daily_spending_limit ? formatMMK(student.daily_spending_limit) : 'No limit'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">Parent Phone</dt>
                  <dd className="text-sm text-gray-900">{student.parent_phone || '-'}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">Parent Email</dt>
                  <dd className="text-sm text-gray-900">{student.parent_email || '-'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">Date of Birth</dt>
                  <dd className="text-sm text-gray-900">{student.date_of_birth || '-'}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-sm text-gray-500">Status</dt>
                  <dd>
                    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                      student.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                    }`}>
                      {student.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </dd>
                </div>
              </dl>
            )}
          </div>

          {/* QR Code */}
          <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm flex flex-col items-center">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">QR Code</h2>
            <canvas ref={qrCanvasRef} />
            <p className="mt-3 text-xs text-gray-400 font-mono break-all text-center max-w-[220px]">
              {student.qr_data}
            </p>
            <button
              onClick={() => {
                if (!qrCanvasRef.current) return;
                const url = qrCanvasRef.current.toDataURL('image/png');
                const a = document.createElement('a');
                a.href = url;
                a.download = `${student.student_code}-qr.png`;
                a.click();
              }}
              className="mt-4 flex items-center gap-2 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-sm font-medium text-blue-700 hover:bg-blue-100"
            >
              <Download className="h-4 w-4" /> Download QR
            </button>
            <button
              onClick={() => setShowRegenConfirm(true)}
              disabled={regenerating}
              className="mt-2 flex items-center gap-2 rounded-lg border border-orange-200 bg-orange-50 px-4 py-2 text-sm font-medium text-orange-700 hover:bg-orange-100 disabled:opacity-50"
            >
              <RefreshCw className={`h-4 w-4 ${regenerating ? 'animate-spin' : ''}`} />
              {regenerating ? 'Regenerating...' : 'Regenerate QR Code'}
            </button>
            <p className="mt-2 text-xs text-gray-400 text-center">Use this if the student&apos;s card is lost or stolen</p>
          </div>
        </div>

        {/* Linked Parents + Link New Parent */}
        <div className="mt-6 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Linked Parents</h2>
            <button
              onClick={() => setShowLinkParent(!showLinkParent)}
              className="flex items-center gap-1 text-sm font-medium text-blue-600 hover:text-blue-800"
            >
              {showLinkParent ? 'Cancel' : '+ Link Parent'}
            </button>
          </div>

          {/* Link Parent Form */}
          {showLinkParent && (
            <div className="mb-4 rounded-lg border border-blue-200 bg-blue-50 p-4 space-y-3">
              <p className="text-sm font-medium text-gray-700">
                Enter parent&apos;s phone or email. When they sign up with this info, they&apos;ll be auto-linked to this student.
              </p>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Parent Phone</label>
                  <input
                    type="tel"
                    value={linkParentPhone}
                    onChange={(e) => setLinkParentPhone(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                    placeholder="09xxxxxxxxx"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Parent Email</label>
                  <input
                    type="email"
                    value={linkParentEmail}
                    onChange={(e) => setLinkParentEmail(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                    placeholder="parent@gmail.com"
                  />
                </div>
              </div>
              {linkError && <p className="text-xs text-red-600">{linkError}</p>}
              <button
                onClick={handleLinkParent}
                disabled={linkLoading}
                className="w-full rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
              >
                {linkLoading ? 'Saving...' : 'Save Parent Info'}
              </button>
            </div>
          )}

          {/* Current parent info */}
          {(student.parent_phone || student.parent_email) && parents.length === 0 && (
            <div className="mb-3 rounded-lg bg-amber-50 border border-amber-200 p-3">
              <p className="text-xs font-medium text-amber-700 mb-1">Pre-registered (waiting for parent to sign up)</p>
              {student.parent_phone && <p className="text-xs text-amber-600">Phone: {student.parent_phone}</p>}
              {student.parent_email && <p className="text-xs text-amber-600">Email: {student.parent_email}</p>}
            </div>
          )}

          {/* Linked parents list */}
          {parents.length === 0 && !student.parent_phone && !student.parent_email ? (
            <div className="flex items-center gap-3 py-4 text-gray-400">
              <User className="h-5 w-5" />
              <span className="text-sm">No parents linked. Click &quot;+ Link Parent&quot; to add.</span>
            </div>
          ) : (
            <div className="divide-y divide-gray-100">
              {parents.map(parent => (
                <div key={parent.id} className="flex items-center justify-between py-3">
                  <div className="flex items-center gap-3">
                    <div className="flex h-9 w-9 items-center justify-center rounded-full bg-purple-100 text-sm font-bold text-purple-700">
                      {parent.full_name.charAt(0)}
                    </div>
                    <div>
                      <p className="text-sm font-medium text-gray-900">{parent.full_name}</p>
                      {parent.phone && <p className="text-xs text-gray-500">{parent.phone}</p>}
                      {parent.email && <p className="text-xs text-gray-500">{parent.email}</p>}
                    </div>
                  </div>
                  <span className="inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700">Linked</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Transaction History */}
        <div className="mt-6 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Recent Transactions</h2>
          {txLoading ? (
            <div className="space-y-2">
              {[1, 2, 3].map(i => (
                <div key={i} className="h-12 animate-pulse rounded-lg bg-gray-100" />
              ))}
            </div>
          ) : transactions.length === 0 ? (
            <p className="text-sm text-gray-400 py-4">No transactions yet</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-2 text-left text-xs font-semibold uppercase text-gray-500">Date</th>
                    <th className="px-4 py-2 text-left text-xs font-semibold uppercase text-gray-500">Type</th>
                    <th className="px-4 py-2 text-right text-xs font-semibold uppercase text-gray-500">Amount</th>
                    <th className="px-4 py-2 text-right text-xs font-semibold uppercase text-gray-500">Balance After</th>
                    <th className="px-4 py-2 text-left text-xs font-semibold uppercase text-gray-500">Description</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {transactions.map(tx => (
                    <tr key={tx.id} className="hover:bg-gray-50">
                      <td className="whitespace-nowrap px-4 py-2.5 text-gray-500">
                        {new Date(tx.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                      </td>
                      <td className="whitespace-nowrap px-4 py-2.5">
                        <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${
                          tx.type === 'deposit' ? 'bg-green-100 text-green-700' :
                          tx.type === 'purchase' ? 'bg-red-100 text-red-700' :
                          tx.type === 'refund' ? 'bg-blue-100 text-blue-700' :
                          'bg-gray-100 text-gray-700'
                        }`}>
                          {tx.type}
                        </span>
                      </td>
                      <td className={`whitespace-nowrap px-4 py-2.5 text-right font-medium ${
                        tx.type === 'purchase' ? 'text-red-600' : 'text-green-600'
                      }`}>
                        {tx.type === 'purchase' ? '-' : '+'}{formatMMK(tx.amount)}
                      </td>
                      <td className="whitespace-nowrap px-4 py-2.5 text-right text-gray-500">
                        {formatMMK(tx.balance_after)}
                      </td>
                      <td className="px-4 py-2.5 text-gray-500 max-w-[200px] truncate">
                        {tx.description || '-'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* Print view - credit card size: 85.6mm x 54mm */}
      <div className="hidden print:flex print:items-center print:justify-center print:min-h-screen">
        <div
          className="border border-gray-300 rounded-lg overflow-hidden flex flex-col items-center justify-between p-4"
          style={{ width: '85.6mm', height: '54mm' }}
        >
          <p className="text-xs font-bold text-gray-800 uppercase tracking-wider">
            {student.school_name}
          </p>
          <div className="flex flex-col items-center">
            <canvas ref={printQrCanvasRef} />
          </div>
          <div className="text-center">
            <p className="text-sm font-semibold text-gray-900">{student.full_name}</p>
            <p className="text-xs text-gray-500">{student.class_name || ''}</p>
            <p className="text-xs font-mono text-gray-400">{student.student_code}</p>
            <p className="text-xs font-mono font-bold text-gray-700 mt-0.5">PIN: {student.pin_code}</p>
          </div>
        </div>
      </div>

      {/* Regenerate QR Confirmation */}
      {showRegenConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowRegenConfirm(false)}>
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start gap-3 mb-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-orange-100 shrink-0">
                <RefreshCw className="h-5 w-5 text-orange-600" />
              </div>
              <div>
                <h3 className="text-base font-semibold text-gray-900">Regenerate QR Code</h3>
                <p className="mt-1 text-sm text-gray-500">This will invalidate the current QR code. The old card will stop working immediately. Are you sure?</p>
              </div>
            </div>
            <div className="flex gap-3 justify-end">
              <button onClick={() => setShowRegenConfirm(false)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
              <button onClick={handleRegenerateQR} disabled={regenerating} className="rounded-lg bg-orange-600 px-4 py-2 text-sm font-medium text-white hover:bg-orange-700 disabled:opacity-50">
                {regenerating ? 'Regenerating...' : 'Regenerate'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
