'use client';

import { authFetch } from '@/lib/auth-fetch';

import { useState, useEffect, useCallback, useRef } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import {
  Search, Plus, Download, Upload, Printer,
  ChevronLeft, ChevronRight, ArrowUpDown, ArrowUp, ArrowDown,
  Check, X, AlertTriangle, Loader2, Users, FileText
} from 'lucide-react';
import { formatMMK } from '@/lib/types';
import { useSchoolContext } from '@/lib/school-context';

interface StudentRow {
  id: string;
  student_code: string;
  full_name: string;
  full_name_my: string | null;
  class_name: string | null;
  grade: string | null;
  is_active: boolean;
  daily_spending_limit: number | null;
  balance: number;
  parent_name: string | null;
}

interface Pagination {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
}

interface CsvPreviewRow {
  full_name: string;
  full_name_my?: string;
  grade?: string;
  class_name?: string;
  parent_phone?: string;
}

// --- Confirmation Dialog ---
function ConfirmDialog({
  open, title, message, confirmLabel, onConfirm, onCancel, variant = 'danger'
}: {
  open: boolean;
  title: string;
  message: string;
  confirmLabel: string;
  onConfirm: () => void;
  onCancel: () => void;
  variant?: 'danger' | 'warning' | 'info';
}) {
  if (!open) return null;
  const colors = {
    danger: 'bg-red-600 hover:bg-red-700',
    warning: 'bg-yellow-600 hover:bg-yellow-700',
    info: 'bg-blue-600 hover:bg-blue-700',
  };
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={onCancel}>
      <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start gap-3 mb-4">
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-red-100 shrink-0">
            <AlertTriangle className="h-5 w-5 text-red-600" />
          </div>
          <div>
            <h3 className="text-base font-semibold text-gray-900">{title}</h3>
            <p className="mt-1 text-sm text-gray-500">{message}</p>
          </div>
        </div>
        <div className="flex gap-3 justify-end">
          <button onClick={onCancel} className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
          <button onClick={onConfirm} className={`rounded-lg px-4 py-2 text-sm font-medium text-white ${colors[variant]}`}>{confirmLabel}</button>
        </div>
      </div>
    </div>
  );
}

// --- Table Skeleton ---
function TableSkeleton({ rows = 8 }: { rows?: number }) {
  return (
    <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
      <div className="bg-gray-50 px-6 py-3">
        <div className="flex gap-6">
          {[1, 2, 3, 4, 5, 6].map(i => (
            <div key={i} className="h-4 w-20 animate-pulse rounded bg-gray-200" />
          ))}
        </div>
      </div>
      <div className="divide-y divide-gray-200">
        {Array.from({ length: rows }).map((_, i) => (
          <div key={i} className="flex items-center gap-6 px-6 py-4">
            <div className="h-4 w-4 animate-pulse rounded bg-gray-200" />
            <div className="flex items-center gap-3 flex-1">
              <div className="h-9 w-9 animate-pulse rounded-full bg-gray-200" />
              <div className="h-4 w-32 animate-pulse rounded bg-gray-200" />
            </div>
            <div className="h-4 w-24 animate-pulse rounded bg-gray-200" />
            <div className="h-4 w-20 animate-pulse rounded bg-gray-200" />
            <div className="h-4 w-20 animate-pulse rounded bg-gray-200" />
            <div className="h-5 w-14 animate-pulse rounded-full bg-gray-200" />
            <div className="h-4 w-12 animate-pulse rounded bg-gray-200" />
          </div>
        ))}
      </div>
    </div>
  );
}

export default function StudentsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { selectedSchoolId } = useSchoolContext();

  // State from URL params
  const [page, setPage] = useState(parseInt(searchParams.get('page') || '0'));
  const [search, setSearch] = useState(searchParams.get('search') || '');
  const [gradeFilter, setGradeFilter] = useState(searchParams.get('grade') || '');
  const [classFilter, setClassFilter] = useState(searchParams.get('class_name') || '');
  const [statusFilter, setStatusFilter] = useState(searchParams.get('status') || '');
  const [sortBy, setSortBy] = useState(searchParams.get('sort_by') || 'full_name');
  const [sortDir, setSortDir] = useState(searchParams.get('sort_dir') || 'asc');

  // Data state
  const [students, setStudents] = useState<StudentRow[]>([]);
  const [pagination, setPagination] = useState<Pagination | null>(null);
  const [grades, setGrades] = useState<string[]>([]);
  const [classes, setClasses] = useState<string[]>([]);
  const [stats, setStats] = useState({ active: 0, inactive: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Selection state for bulk actions
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  // Modal states
  const [showAddModal, setShowAddModal] = useState(false);
  const [showCsvModal, setShowCsvModal] = useState(false);
  const [showBulkConfirm, setShowBulkConfirm] = useState<{ action: string; count: number } | null>(null);
  const [showBulkLinkParent, setShowBulkLinkParent] = useState(false);
  const [bulkParentPhone, setBulkParentPhone] = useState('');
  const [bulkParentEmail, setBulkParentEmail] = useState('');
  const [bulkLinkLoading, setBulkLinkLoading] = useState(false);
  const [showToggleConfirm, setShowToggleConfirm] = useState<StudentRow | null>(null);

  // Deposit modal
  const [depositStudent, setDepositStudent] = useState<StudentRow | null>(null);
  const [depositAmount, setDepositAmount] = useState('');
  const [depositNote, setDepositNote] = useState('');
  const [depositLoading, setDepositLoading] = useState(false);
  const [depositError, setDepositError] = useState('');

  // Dynamic grades/sections from settings
  const [dynamicGrades, setDynamicGrades] = useState<{ id: string; name: string }[]>([]);
  const [dynamicSections, setDynamicSections] = useState<{ id: string; name: string }[]>([]);

  // Add student form
  const [addLoading, setAddLoading] = useState(false);
  const [addError, setAddError] = useState('');
  const [newName, setNewName] = useState('');
  const [newNameMy, setNewNameMy] = useState('');
  const [newGrade, setNewGrade] = useState('');
  const [newSection, setNewSection] = useState('');
  const [newPhone, setNewPhone] = useState('');
  const [newDob, setNewDob] = useState('');

  // CSV import state
  const [csvFile, setCsvFile] = useState<File | null>(null);
  const [csvPreview, setCsvPreview] = useState<CsvPreviewRow[] | null>(null);
  const [csvErrors, setCsvErrors] = useState<string[]>([]);
  const [csvImporting, setCsvImporting] = useState(false);
  const [csvProgress, setCsvProgress] = useState(0);
  const [csvResult, setCsvResult] = useState<{ imported: number; skipped: number; invalid: number; errors: string[]; skippedDetails: { row: number; reason: string }[] } | null>(null);

  // Debounce timer ref
  const searchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [debouncedSearch, setDebouncedSearch] = useState(search);

  // Debounce search input
  useEffect(() => {
    if (searchTimerRef.current) clearTimeout(searchTimerRef.current);
    searchTimerRef.current = setTimeout(() => {
      setDebouncedSearch(search);
      setPage(0); // Reset to first page on search
    }, 300);
    return () => {
      if (searchTimerRef.current) clearTimeout(searchTimerRef.current);
    };
  }, [search]);

  // Fetch dynamic grades and sections from settings
  useEffect(() => {
    async function fetchGradesSections() {
      try {
        const gradeParams = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
        const sectionParams = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
        const [gradesRes, sectionsRes] = await Promise.all([
          authFetch(`/api/settings/grades${gradeParams}`),
          authFetch(`/api/settings/sections${sectionParams}`),
        ]);
        const gradesJson = await gradesRes.json();
        const sectionsJson = await sectionsRes.json();
        if (gradesJson.success) {
          const active = (gradesJson.data || []).filter((g: { is_active: boolean }) => g.is_active);
          setDynamicGrades(active);
          if (active.length > 0 && !newGrade) setNewGrade(active[0].name);
        }
        if (sectionsJson.success) {
          const active = (sectionsJson.data || []).filter((s: { is_active: boolean }) => s.is_active);
          setDynamicSections(active);
          if (active.length > 0 && !newSection) setNewSection(active[0].name);
        }
      } catch {
        // Fall back to existing behavior
      }
    }
    fetchGradesSections();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedSchoolId]);

  // Sync URL params
  useEffect(() => {
    const params = new URLSearchParams();
    if (page > 0) params.set('page', String(page));
    if (debouncedSearch) params.set('search', debouncedSearch);
    if (gradeFilter) params.set('grade', gradeFilter);
    if (classFilter) params.set('class_name', classFilter);
    if (statusFilter) params.set('status', statusFilter);
    if (sortBy !== 'full_name') params.set('sort_by', sortBy);
    if (sortDir !== 'asc') params.set('sort_dir', sortDir);
    const qs = params.toString();
    router.replace(`/dashboard/students${qs ? `?${qs}` : ''}`, { scroll: false });
  }, [page, debouncedSearch, gradeFilter, classFilter, statusFilter, sortBy, sortDir, router]);

  // Fetch students from API
  const fetchStudents = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({
        page: String(page),
        limit: '50',
        search: debouncedSearch,
        grade: gradeFilter,
        class_name: classFilter,
        status: statusFilter,
        sort_by: sortBy,
        sort_dir: sortDir,
      });
      if (selectedSchoolId) {
        params.set('school_id', selectedSchoolId);
      }
      const res = await authFetch(`/api/students?${params}`);
      const json = await res.json();
      if (!json.success) {
        setError(json.error || 'Failed to fetch students');
        setLoading(false);
        return;
      }
      setStudents(json.data);
      setPagination(json.pagination);
      setGrades(json.grades || []);
      setClasses(json.classes || []);
      setStats(json.stats || { active: 0, inactive: 0 });
    } catch {
      setError('Network error fetching students');
    }
    setLoading(false);
  }, [page, debouncedSearch, gradeFilter, classFilter, statusFilter, sortBy, sortDir, selectedSchoolId]);

  useEffect(() => {
    fetchStudents();
  }, [fetchStudents]);

  // Clear selections on page/filter change
  useEffect(() => {
    setSelectedIds(new Set());
  }, [page, debouncedSearch, gradeFilter, classFilter, statusFilter]);

  // --- Handlers ---

  function handleSort(field: string) {
    if (sortBy === field) {
      setSortDir(sortDir === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortDir('asc');
    }
    setPage(0);
  }

  function renderSortIcon(field: string) {
    if (sortBy !== field) return <ArrowUpDown className="h-3.5 w-3.5 text-gray-400" />;
    return sortDir === 'asc' ? <ArrowUp className="h-3.5 w-3.5 text-blue-600" /> : <ArrowDown className="h-3.5 w-3.5 text-blue-600" />;
  }

  function toggleSelectAll() {
    if (selectedIds.size === students.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(students.map(s => s.id)));
    }
  }

  function toggleSelect(id: string) {
    setSelectedIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function handleToggleActive(student: StudentRow) {
    // If deactivating, show confirmation first
    if (student.is_active) {
      setShowToggleConfirm(student);
      return;
    }
    // Activating - no confirmation needed
    await performToggle(student);
  }

  async function performToggle(student: StudentRow) {
    try {
      const res = await authFetch('/api/students', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: student.id, is_active: !student.is_active }),
      });
      const json = await res.json();
      if (json.success) {
        fetchStudents();
      }
    } catch {
      // silently fail
    }
    setShowToggleConfirm(null);
  }

  async function handleBulkAction(action: string) {
    if (selectedIds.size === 0) return;
    setShowBulkConfirm({ action, count: selectedIds.size });
  }

  async function performBulkAction() {
    if (!showBulkConfirm) return;
    try {
      const res = await authFetch('/api/students/bulk', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: showBulkConfirm.action, studentIds: [...selectedIds] }),
      });
      const json = await res.json();
      if (json.success) {
        setSelectedIds(new Set());
        fetchStudents();
      }
    } catch {
      // silently fail
    }
    setShowBulkConfirm(null);
  }

  async function handleAddStudent() {
    setAddLoading(true);
    setAddError('');

    try {
      const className = `${newGrade}-${newSection}`;

      const res = await authFetch('/api/students', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          full_name: newName,
          full_name_my: newNameMy || null,
          grade: newGrade,
          class_name: className,
          parent_phone: newPhone || null,
          date_of_birth: newDob || null,
          school_id: selectedSchoolId || undefined,
        }),
      });

      const json = await res.json();
      if (!json.success) {
        setAddError(json.error || 'Failed to add student');
        setAddLoading(false);
        return;
      }

      setShowAddModal(false);
      setNewName('');
      setNewNameMy('');
      setNewGrade('1');
      setNewSection('A');
      setNewPhone('');
      setNewDob('');
      fetchStudents();
    } catch {
      setAddError('Network error');
    }
    setAddLoading(false);
  }

  // --- CSV handlers ---
  async function handleCsvPreview() {
    if (!csvFile) return;
    const formData = new FormData();
    formData.append('file', csvFile);
    formData.append('preview', 'true');

    try {
      const res = await authFetch('/api/students/import', { method: 'POST', body: formData });
      const json = await res.json();
      if (json.success) {
        setCsvPreview(json.data);
        setCsvErrors(json.errors || []);
      } else {
        setCsvErrors([json.error]);
      }
    } catch {
      setCsvErrors(['Network error during preview']);
    }
  }

  async function handleCsvImport() {
    if (!csvFile) return;
    setCsvImporting(true);
    setCsvProgress(10);

    const formData = new FormData();
    formData.append('file', csvFile);

    // Simulate progress
    const progressInterval = setInterval(() => {
      setCsvProgress(prev => Math.min(prev + 15, 90));
    }, 500);

    try {
      const res = await authFetch('/api/students/import', { method: 'POST', body: formData });
      const json = await res.json();
      clearInterval(progressInterval);
      setCsvProgress(100);

      if (json.success) {
        setCsvResult({
          imported: json.stats.imported,
          skipped: json.stats.skipped,
          invalid: json.stats.invalid,
          errors: json.errors || [],
          skippedDetails: json.skipped || [],
        });
        fetchStudents();
      } else {
        setCsvErrors([json.error]);
      }
    } catch {
      clearInterval(progressInterval);
      setCsvErrors(['Network error during import']);
    }
    setCsvImporting(false);
  }

  function resetCsvModal() {
    setCsvFile(null);
    setCsvPreview(null);
    setCsvErrors([]);
    setCsvImporting(false);
    setCsvProgress(0);
    setCsvResult(null);
    setShowCsvModal(false);
  }

  async function handleExport() {
    try {
      const res = await authFetch('/api/students/export');
      const blob = await res.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `students-export-${new Date().toISOString().split('T')[0]}.csv`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } catch {
      // silently fail
    }
  }

  async function handleDeposit() {
    if (!depositStudent || !depositAmount) return;
    const amount = parseInt(depositAmount);
    if (isNaN(amount) || amount <= 0) {
      setDepositError('Enter a valid amount');
      return;
    }
    setDepositLoading(true);
    setDepositError('');
    try {
      const res = await authFetch('/api/deposits', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          student_id: depositStudent.id,
          amount,
          note: depositNote || 'Admin deposit',
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setDepositError(json.error || 'Deposit failed');
        setDepositLoading(false);
        return;
      }
      setDepositStudent(null);
      setDepositAmount('');
      setDepositNote('');
      fetchStudents();
    } catch {
      setDepositError('Network error');
    }
    setDepositLoading(false);
  }

  const totalStudents = stats.active + stats.inactive;

  return (
    <div>
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-6 gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Students</h1>
          <div className="mt-1 flex items-center gap-3">
            <p className="text-sm text-gray-500">{totalStudents} registered students</p>
            <span className="inline-flex items-center gap-1 rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-700">
              <Users className="h-3 w-3" /> {stats.active} active
            </span>
            <span className="inline-flex items-center gap-1 rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-500">
              {stats.inactive} inactive
            </span>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          <Link
            href="/dashboard/students/print"
            className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50"
          >
            <Printer className="h-4 w-4" /> Print QR
          </Link>
          <button onClick={() => setShowCsvModal(true)} className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
            <Upload className="h-4 w-4" /> CSV Import
          </button>
          <button onClick={handleExport} className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
            <Download className="h-4 w-4" /> Export
          </button>
          <button onClick={() => setShowAddModal(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
            <Plus className="h-4 w-4" /> Add Student
          </button>
        </div>
      </div>

      {/* Status tab pills */}
      <div className="mb-4 flex items-center gap-1 rounded-lg bg-gray-100 p-1 w-fit">
        {[
          { value: '', label: 'All' },
          { value: 'active', label: 'Active' },
          { value: 'inactive', label: 'Inactive' },
        ].map(tab => (
          <button
            key={tab.value}
            onClick={() => { setStatusFilter(tab.value); setPage(0); }}
            className={`rounded-md px-4 py-1.5 text-sm font-medium transition-colors ${
              statusFilter === tab.value
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Filters row */}
      <div className="mb-4 flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name or student code..."
            className="w-full rounded-lg border border-gray-300 py-2 pl-10 pr-4 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>
        <select
          value={gradeFilter}
          onChange={(e) => { setGradeFilter(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        >
          <option value="">All Grades</option>
          {dynamicGrades.length > 0 ? (
            dynamicGrades.map(g => (
              <option key={g.id} value={g.name}>{g.name}</option>
            ))
          ) : (
            grades.map(g => (
              <option key={g} value={g}>Grade {g}</option>
            ))
          )}
        </select>
        <select
          value={classFilter}
          onChange={(e) => { setClassFilter(e.target.value); setPage(0); }}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        >
          <option value="">All Classes</option>
          {classes.map(c => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
      </div>

      {/* Bulk actions bar */}
      {selectedIds.size > 0 && (
        <div className="mb-4 flex items-center gap-3 rounded-lg bg-blue-50 border border-blue-200 px-4 py-3">
          <span className="text-sm font-medium text-blue-700">{selectedIds.size} selected</span>
          <div className="flex gap-2">
            <button onClick={() => handleBulkAction('activate')} className="rounded-md bg-green-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-green-700">Activate</button>
            <button onClick={() => handleBulkAction('deactivate')} className="rounded-md bg-yellow-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-yellow-700">Deactivate</button>
            <button onClick={() => setShowBulkLinkParent(true)} className="rounded-md bg-purple-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-purple-700">Link Parent</button>
            <button onClick={() => handleBulkAction('delete')} className="rounded-md bg-red-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-red-700">Delete</button>
          </div>
          <button onClick={() => setSelectedIds(new Set())} className="ml-auto text-sm text-blue-600 hover:text-blue-800">Clear selection</button>
        </div>
      )}

      {/* Error state */}
      {error && (
        <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Table */}
      {loading ? (
        <TableSkeleton />
      ) : students.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="flex flex-col items-center justify-center py-16 px-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 mb-4">
              <Users className="h-8 w-8 text-gray-400" />
            </div>
            <h3 className="text-base font-semibold text-gray-900 mb-1">No students found</h3>
            <p className="text-sm text-gray-500 text-center max-w-sm">
              {debouncedSearch || gradeFilter || classFilter || statusFilter
                ? 'No students match your current filters. Try adjusting your search or filters.'
                : 'Get started by adding your first student or importing from CSV.'}
            </p>
            {!debouncedSearch && !gradeFilter && !classFilter && !statusFilter && (
              <div className="mt-4 flex gap-2">
                <button onClick={() => setShowCsvModal(true)} className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50">
                  <Upload className="h-4 w-4" /> Import CSV
                </button>
                <button onClick={() => setShowAddModal(true)} className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
                  <Plus className="h-4 w-4" /> Add Student
                </button>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left">
                    <input
                      type="checkbox"
                      checked={selectedIds.size === students.length && students.length > 0}
                      onChange={toggleSelectAll}
                      className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                  </th>
                  <th className="px-4 py-3 text-left">
                    <button onClick={() => handleSort('full_name')} className="flex items-center gap-1 text-xs font-semibold uppercase tracking-wider text-gray-500 hover:text-gray-700">
                      Student {renderSortIcon('full_name')}
                    </button>
                  </th>
                  <th className="px-4 py-3 text-left">
                    <button onClick={() => handleSort('student_code')} className="flex items-center gap-1 text-xs font-semibold uppercase tracking-wider text-gray-500 hover:text-gray-700">
                      ID {renderSortIcon('student_code')}
                    </button>
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Class</th>
                  <th className="px-4 py-3 text-left">
                    <button onClick={() => handleSort('balance')} className="flex items-center gap-1 text-xs font-semibold uppercase tracking-wider text-gray-500 hover:text-gray-700">
                      Balance {renderSortIcon('balance')}
                    </button>
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Status</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {students.map((student) => (
                  <tr key={student.id} className={`hover:bg-gray-50 ${!student.is_active ? 'opacity-60' : ''}`}>
                    <td className="whitespace-nowrap px-4 py-4">
                      <input
                        type="checkbox"
                        checked={selectedIds.has(student.id)}
                        onChange={() => toggleSelect(student.id)}
                        className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                    </td>
                    <td className="whitespace-nowrap px-4 py-4">
                      <div className="flex items-center gap-3">
                        <div className={`flex h-9 w-9 items-center justify-center rounded-full text-sm font-bold ${
                          student.is_active ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-400'
                        }`}>
                          {student.full_name.charAt(0)}
                        </div>
                        <div>
                          <span className="text-sm font-medium text-gray-900">{student.full_name}</span>
                          {student.parent_name && (
                            <p className="text-xs text-gray-400">Parent: {student.parent_name}</p>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="whitespace-nowrap px-4 py-4 text-sm text-gray-500 font-mono">{student.student_code}</td>
                    <td className="whitespace-nowrap px-4 py-4 text-sm text-gray-500">{student.class_name || '-'}</td>
                    <td className={`whitespace-nowrap px-4 py-4 text-sm font-medium ${
                      student.balance < 1000 ? 'text-red-600' : 'text-gray-900'
                    }`}>
                      {formatMMK(student.balance)}
                    </td>
                    <td className="whitespace-nowrap px-4 py-4">
                      <button
                        onClick={() => handleToggleActive(student)}
                        className="group flex items-center gap-2"
                        title={student.is_active ? 'Click to deactivate' : 'Click to activate'}
                      >
                        <div className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                          student.is_active ? 'bg-green-500' : 'bg-gray-300'
                        }`}>
                          <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                            student.is_active ? 'translate-x-4' : 'translate-x-1'
                          }`} />
                        </div>
                        <span className={`text-xs font-medium ${
                          student.is_active ? 'text-green-700' : 'text-gray-500'
                        }`}>
                          {student.is_active ? 'Active' : 'Inactive'}
                        </span>
                      </button>
                    </td>
                    <td className="whitespace-nowrap px-4 py-4 flex items-center gap-3">
                      <Link href={`/dashboard/students/${student.id}`} className="text-sm text-blue-600 hover:text-blue-800 font-medium">View</Link>
                      <button
                        onClick={() => { setDepositStudent(student); setDepositAmount(''); setDepositNote(''); setDepositError(''); }}
                        className="text-sm text-green-600 hover:text-green-800 font-medium"
                      >
                        + Balance
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Pagination */}
      {pagination && pagination.totalPages > 0 && (
        <div className="mt-4 flex flex-col sm:flex-row items-center justify-between gap-3">
          <p className="text-sm text-gray-500">
            Showing {page * pagination.limit + 1} - {Math.min((page + 1) * pagination.limit, pagination.total)} of {pagination.total} students
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage(Math.max(0, page - 1))}
              disabled={page === 0}
              className="flex items-center gap-1 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <ChevronLeft className="h-4 w-4" /> Prev
            </button>
            <span className="text-sm text-gray-700 font-medium px-2">
              Page {page + 1} of {pagination.totalPages}
            </span>
            <button
              onClick={() => setPage(page + 1)}
              disabled={!pagination.hasMore}
              className="flex items-center gap-1 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      )}

      {/* Toggle Confirm Dialog */}
      <ConfirmDialog
        open={!!showToggleConfirm}
        title="Deactivate Student"
        message={`Are you sure you want to deactivate ${showToggleConfirm?.full_name}? Their QR code will stop working for purchases.`}
        confirmLabel="Deactivate"
        variant="warning"
        onConfirm={() => showToggleConfirm && performToggle(showToggleConfirm)}
        onCancel={() => setShowToggleConfirm(null)}
      />

      {/* Bulk Action Confirm Dialog */}
      <ConfirmDialog
        open={!!showBulkConfirm}
        title={`Bulk ${showBulkConfirm?.action || ''}`}
        message={`Are you sure you want to ${showBulkConfirm?.action} ${showBulkConfirm?.count} student(s)?${showBulkConfirm?.action === 'delete' ? ' This action cannot be undone.' : ''}`}
        confirmLabel={showBulkConfirm?.action === 'delete' ? 'Delete' : (showBulkConfirm?.action || '')}
        variant={showBulkConfirm?.action === 'delete' ? 'danger' : 'warning'}
        onConfirm={performBulkAction}
        onCancel={() => setShowBulkConfirm(null)}
      />

      {/* Bulk Link Parent Modal */}
      {showBulkLinkParent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowBulkLinkParent(false)}>
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-2">Link Parent to {selectedIds.size} Student(s)</h2>
            <p className="text-sm text-gray-500 mb-4">Enter the parent&apos;s phone or email. When they sign up, they&apos;ll be auto-linked.</p>
            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Parent Phone</label>
                <input type="tel" value={bulkParentPhone} onChange={(e) => setBulkParentPhone(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="09xxxxxxxxx" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Parent Email</label>
                <input type="email" value={bulkParentEmail} onChange={(e) => setBulkParentEmail(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="parent@gmail.com" />
              </div>
              <div className="flex gap-3 pt-2">
                <button onClick={() => { setShowBulkLinkParent(false); setBulkParentPhone(''); setBulkParentEmail(''); }} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button
                  disabled={bulkLinkLoading || (!bulkParentPhone && !bulkParentEmail)}
                  onClick={async () => {
                    setBulkLinkLoading(true);
                    const updates: Record<string, string | null> = {};
                    if (bulkParentPhone) {
                      let ph = bulkParentPhone.replace(/\s+/g, '');
                      if (ph.startsWith('0')) ph = '+95' + ph.substring(1);
                      else if (!ph.startsWith('+')) ph = '+' + ph;
                      updates.parent_phone = ph;
                    }
                    if (bulkParentEmail) updates.parent_email = bulkParentEmail.toLowerCase();
                    for (const sid of selectedIds) {
                      await authFetch('/api/students', {
                        method: 'PATCH',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ id: sid, ...updates }),
                      });
                    }
                    setBulkLinkLoading(false);
                    setShowBulkLinkParent(false);
                    setBulkParentPhone('');
                    setBulkParentEmail('');
                    setSelectedIds(new Set());
                    fetchStudents();
                  }}
                  className="flex-1 rounded-lg bg-purple-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-purple-700 disabled:opacity-50"
                >
                  {bulkLinkLoading ? 'Saving...' : 'Link Parent'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Deposit Modal */}
      {depositStudent && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setDepositStudent(null)}>
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-1">Add Balance</h2>
            <p className="text-sm text-gray-500 mb-4">
              {depositStudent.full_name} — Current: {formatMMK(depositStudent.balance)}
            </p>
            {depositError && (
              <div className="mb-3 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{depositError}</div>
            )}
            <form onSubmit={(e) => { e.preventDefault(); handleDeposit(); }}>
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">Amount (MMK)</label>
                <input
                  type="number"
                  min="1"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-green-500 focus:outline-none focus:ring-1 focus:ring-green-500"
                  placeholder="e.g. 5000"
                  autoFocus
                />
              </div>
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-1">Depositor Name (optional)</label>
                <input
                  type="text"
                  value={depositNote}
                  onChange={(e) => setDepositNote(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-green-500 focus:outline-none focus:ring-1 focus:ring-green-500"
                  placeholder="e.g. U Kyaw (parent)"
                />
              </div>
              <div className="flex gap-3 mb-3">
                {[10000, 20000, 30000, 40000].map(amt => (
                  <button
                    key={amt}
                    type="button"
                    onClick={() => setDepositAmount(String(amt))}
                    className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition-colors ${
                      depositAmount === String(amt)
                        ? 'border-green-500 bg-green-50 text-green-700'
                        : 'border-gray-200 text-gray-600 hover:bg-gray-50'
                    }`}
                  >
                    {formatMMK(amt)}
                  </button>
                ))}
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setDepositStudent(null)} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button type="submit" disabled={depositLoading || !depositAmount} className="flex-1 rounded-lg bg-green-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50">
                  {depositLoading ? 'Processing...' : `Deposit ${depositAmount ? formatMMK(parseInt(depositAmount) || 0) : ''}`}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Student Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setShowAddModal(false)}>
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-gray-900 mb-4">Add New Student</h2>
            {addError && (
              <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {addError}
              </div>
            )}
            <form className="space-y-4" onSubmit={(e) => { e.preventDefault(); handleAddStudent(); }}>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                <input type="text" required value={newName} onChange={(e) => setNewName(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="Enter student name" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name (Myanmar)</label>
                <input type="text" value={newNameMy} onChange={(e) => setNewNameMy(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="Enter Myanmar name" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Grade</label>
                  <select value={newGrade} onChange={(e) => setNewGrade(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500">
                    {dynamicGrades.length > 0 ? (
                      dynamicGrades.map(g => (
                        <option key={g.id} value={g.name}>{g.name}</option>
                      ))
                    ) : (
                      [1,2,3,4,5,6,7,8,9,10,11].map(g => (
                        <option key={g} value={String(g)}>Grade {g}</option>
                      ))
                    )}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Section</label>
                  <select value={newSection} onChange={(e) => setNewSection(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500">
                    {dynamicSections.length > 0 ? (
                      dynamicSections.map(s => (
                        <option key={s.id} value={s.name}>{s.name}</option>
                      ))
                    ) : (
                      ['A','B','C','D'].map(s => (
                        <option key={s} value={s}>{s}</option>
                      ))
                    )}
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Parent Phone (optional)</label>
                <input type="tel" value={newPhone} onChange={(e) => setNewPhone(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="09xxxxxxxxx" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Date of Birth (optional)</label>
                <input type="text" value={newDob} onChange={(e) => setNewDob(e.target.value)} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500" placeholder="YYYYMMDD (e.g., 20150315)" maxLength={8} />
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => { setShowAddModal(false); setAddError(''); }} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button type="submit" disabled={addLoading} className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">
                  {addLoading ? 'Adding...' : 'Add Student'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CSV Import Modal */}
      {showCsvModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={resetCsvModal}>
          <div className="w-full max-w-2xl max-h-[80vh] overflow-y-auto rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-gray-900">CSV Import</h2>
              <button onClick={resetCsvModal} className="text-gray-400 hover:text-gray-600"><X className="h-5 w-5" /></button>
            </div>

            {csvResult ? (
              // Import complete - show results
              <div className="space-y-4">
                <div className="rounded-lg bg-green-50 border border-green-200 p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <Check className="h-5 w-5 text-green-600" />
                    <span className="text-sm font-semibold text-green-700">Import Complete</span>
                  </div>
                  <div className="grid grid-cols-3 gap-4 mt-3">
                    <div className="text-center">
                      <p className="text-2xl font-bold text-green-700">{csvResult.imported}</p>
                      <p className="text-xs text-green-600">Imported</p>
                    </div>
                    <div className="text-center">
                      <p className="text-2xl font-bold text-yellow-700">{csvResult.skipped}</p>
                      <p className="text-xs text-yellow-600">Skipped</p>
                    </div>
                    <div className="text-center">
                      <p className="text-2xl font-bold text-red-700">{csvResult.invalid}</p>
                      <p className="text-xs text-red-600">Invalid</p>
                    </div>
                  </div>
                </div>
                {csvResult.skippedDetails.length > 0 && (
                  <div className="rounded-lg border border-yellow-200 bg-yellow-50 p-3">
                    <p className="text-sm font-medium text-yellow-700 mb-1">Skipped rows:</p>
                    <ul className="text-xs text-yellow-600 space-y-1">
                      {csvResult.skippedDetails.map((s, i) => (
                        <li key={i}>Row {s.row}: {s.reason}</li>
                      ))}
                    </ul>
                  </div>
                )}
                {csvResult.errors.length > 0 && (
                  <div className="rounded-lg border border-red-200 bg-red-50 p-3">
                    <p className="text-sm font-medium text-red-700 mb-1">Validation errors:</p>
                    <ul className="text-xs text-red-600 space-y-1">
                      {csvResult.errors.map((e, i) => (
                        <li key={i}>{e}</li>
                      ))}
                    </ul>
                  </div>
                )}
                <button onClick={resetCsvModal} className="w-full rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700">Done</button>
              </div>
            ) : csvImporting ? (
              // Importing - show progress
              <div className="space-y-4 py-8">
                <div className="flex justify-center">
                  <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
                </div>
                <p className="text-center text-sm text-gray-600">Importing students...</p>
                <div className="mx-auto w-64">
                  <div className="h-2 rounded-full bg-gray-200">
                    <div className="h-2 rounded-full bg-blue-600 transition-all duration-500" style={{ width: `${csvProgress}%` }} />
                  </div>
                  <p className="mt-1 text-center text-xs text-gray-400">{csvProgress}%</p>
                </div>
              </div>
            ) : csvPreview ? (
              // Preview parsed data
              <div className="space-y-4">
                <p className="text-sm text-gray-600">{csvPreview.length} valid records found. Review and confirm import.</p>
                {csvErrors.length > 0 && (
                  <div className="rounded-lg border border-red-200 bg-red-50 p-3">
                    <p className="text-sm font-medium text-red-700 mb-1">Validation errors:</p>
                    <ul className="text-xs text-red-600 space-y-1">
                      {csvErrors.map((e, i) => (
                        <li key={i}>{e}</li>
                      ))}
                    </ul>
                  </div>
                )}
                <div className="overflow-x-auto max-h-64 rounded-lg border border-gray-200">
                  <table className="min-w-full divide-y divide-gray-200 text-sm">
                    <thead className="bg-gray-50 sticky top-0">
                      <tr>
                        <th className="px-3 py-2 text-left text-xs font-semibold text-gray-500">#</th>
                        <th className="px-3 py-2 text-left text-xs font-semibold text-gray-500">Name</th>
                        <th className="px-3 py-2 text-left text-xs font-semibold text-gray-500">Name (MY)</th>
                        <th className="px-3 py-2 text-left text-xs font-semibold text-gray-500">Grade</th>
                        <th className="px-3 py-2 text-left text-xs font-semibold text-gray-500">Class</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {csvPreview.map((row, i) => (
                        <tr key={i}>
                          <td className="px-3 py-2 text-gray-400">{i + 1}</td>
                          <td className="px-3 py-2 text-gray-900">{row.full_name}</td>
                          <td className="px-3 py-2 text-gray-500">{row.full_name_my || '-'}</td>
                          <td className="px-3 py-2 text-gray-500">{row.grade || '-'}</td>
                          <td className="px-3 py-2 text-gray-500">{row.class_name || '-'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <div className="flex gap-3">
                  <button onClick={() => { setCsvPreview(null); setCsvFile(null); setCsvErrors([]); }} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Back</button>
                  <button onClick={handleCsvImport} disabled={csvPreview.length === 0} className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">
                    Import {csvPreview.length} Students
                  </button>
                </div>
              </div>
            ) : (
              // File upload step
              <div className="space-y-4">
                <p className="text-sm text-gray-600">
                  Upload a CSV file with columns: <code className="text-xs bg-gray-100 px-1 py-0.5 rounded">full_name</code>, <code className="text-xs bg-gray-100 px-1 py-0.5 rounded">full_name_my</code>, <code className="text-xs bg-gray-100 px-1 py-0.5 rounded">grade</code>, <code className="text-xs bg-gray-100 px-1 py-0.5 rounded">class_name</code>, <code className="text-xs bg-gray-100 px-1 py-0.5 rounded">parent_phone</code>
                </p>
                <div className="flex flex-col items-center justify-center rounded-lg border-2 border-dashed border-gray-300 p-8">
                  <FileText className="h-10 w-10 text-gray-400 mb-3" />
                  <label className="cursor-pointer rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700">
                    Choose CSV File
                    <input type="file" accept=".csv" className="hidden" onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (file) setCsvFile(file);
                    }} />
                  </label>
                  {csvFile && <p className="mt-2 text-sm text-gray-600">{csvFile.name}</p>}
                </div>
                {csvErrors.length > 0 && (
                  <div className="rounded-lg border border-red-200 bg-red-50 p-3">
                    {csvErrors.map((e, i) => (
                      <p key={i} className="text-sm text-red-700">{e}</p>
                    ))}
                  </div>
                )}
                <div className="flex gap-3">
                  <button onClick={resetCsvModal} className="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                  <button onClick={handleCsvPreview} disabled={!csvFile} className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">Preview</button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
