'use client';

import { authFetch } from '@/lib/auth-fetch';

import { useState, useEffect, useCallback } from 'react';
import {
  Settings, Plus, Trash2, ChevronUp, ChevronDown,
  Loader2, Pencil, Check, X, GripVertical,
  Users, School, Eye, EyeOff,
  Clock, BookOpen, DollarSign, Building2, Save, Award,
} from 'lucide-react';
import { useSchoolContext } from '@/lib/school-context';

type SettingsTab = 'school' | 'users';

interface GradeItem {
  id: string;
  school_id: string;
  name: string;
  display_order: number;
  is_active: boolean;
}

interface SectionItem {
  id: string;
  school_id: string;
  name: string;
  display_order: number;
  is_active: boolean;
}

interface SubjectItem {
  id: string;
  school_id: string;
  name: string;
  name_my: string | null;
  grade_levels: string[];
  full_marks: number;
  pass_marks: number;
  display_order: number;
  is_active: boolean;
}

interface ExamTypeItem {
  id: string;
  school_id: string;
  name: string;
  name_my: string | null;
  weight: number;
  term: string | null;
  display_order: number;
  is_active: boolean;
}

interface UserItem {
  id: string;
  email: string;
  full_name: string;
  role: string;
  phone?: string;
  is_active: boolean;
  created_at: string;
}

// --- Grading Scale Types ---
interface GradeScaleEntry {
  letter: string;
  label: string;
  min: number;
  color: string;
}

const GRADE_COLORS = ['green', 'blue', 'purple', 'yellow', 'orange', 'pink', 'teal', 'red'] as const;

const GRADE_COLOR_CLASSES: Record<string, { bg: string; text: string }> = {
  green: { bg: 'bg-green-100', text: 'text-green-700' },
  blue: { bg: 'bg-blue-100', text: 'text-blue-700' },
  purple: { bg: 'bg-purple-100', text: 'text-purple-700' },
  yellow: { bg: 'bg-yellow-100', text: 'text-yellow-700' },
  orange: { bg: 'bg-orange-100', text: 'text-orange-700' },
  pink: { bg: 'bg-pink-100', text: 'text-pink-700' },
  teal: { bg: 'bg-teal-100', text: 'text-teal-700' },
  red: { bg: 'bg-red-100', text: 'text-red-700' },
};

const DEFAULT_GRADING_SCALE: GradeScaleEntry[] = [
  { letter: 'A', label: 'Distinction', min: 80, color: 'green' },
  { letter: 'B', label: 'Credit', min: 65, color: 'blue' },
  { letter: 'C', label: 'Pass', min: 40, color: 'yellow' },
  { letter: 'F', label: 'Fail', min: 0, color: 'red' },
];

/** Convert old { a_min, b_min, c_min } format to new array format */
function normalizeGradingScale(raw: unknown): GradeScaleEntry[] {
  if (Array.isArray(raw)) return raw as GradeScaleEntry[];
  if (raw && typeof raw === 'object' && 'a_min' in (raw as Record<string, unknown>)) {
    const obj = raw as { a_min?: number; b_min?: number; c_min?: number };
    return [
      { letter: 'A', label: 'Distinction', min: obj.a_min ?? 80, color: 'green' },
      { letter: 'B', label: 'Credit', min: obj.b_min ?? 65, color: 'blue' },
      { letter: 'C', label: 'Pass', min: obj.c_min ?? 40, color: 'yellow' },
      { letter: 'F', label: 'Fail', min: 0, color: 'red' },
    ];
  }
  return DEFAULT_GRADING_SCALE;
}

// --- School Settings Types ---
interface SchoolSettingsData {
  // Direct school columns
  name: string;
  name_my: string;
  code: string;
  address: string;
  phone: string;
  // JSONB settings
  school_start_time: string;
  school_end_time: string;
  canteen_open_time: string;
  canteen_close_time: string;
  academic_year_start: string;
  academic_year_end: string;
  term_semester: string;
  default_daily_spending_limit: string;
  low_balance_alert_threshold: string;
  // Grading scale (new array format)
  grading_scale: GradeScaleEntry[];
}

const DEFAULT_SETTINGS: SchoolSettingsData = {
  name: '',
  name_my: '',
  code: '',
  address: '',
  phone: '',
  school_start_time: '08:00',
  school_end_time: '15:30',
  canteen_open_time: '07:30',
  canteen_close_time: '14:00',
  academic_year_start: '6',
  academic_year_end: '3',
  term_semester: '',
  default_daily_spending_limit: '5000',
  low_balance_alert_threshold: '1000',
  grading_scale: DEFAULT_GRADING_SCALE,
};

const MONTHS = [
  { value: '1', label: 'January' },
  { value: '2', label: 'February' },
  { value: '3', label: 'March' },
  { value: '4', label: 'April' },
  { value: '5', label: 'May' },
  { value: '6', label: 'June' },
  { value: '7', label: 'July' },
  { value: '8', label: 'August' },
  { value: '9', label: 'September' },
  { value: '10', label: 'October' },
  { value: '11', label: 'November' },
  { value: '12', label: 'December' },
];

// --- Collapsible Section Wrapper ---
function SettingsSection({
  icon: Icon,
  title,
  children,
  defaultOpen = true,
}: {
  icon: React.ElementType;
  title: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
      <button
        onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between px-6 py-4 text-left"
      >
        <div className="flex items-center gap-3">
          <Icon className="h-5 w-5 text-gray-400" />
          <h3 className="text-base font-semibold text-gray-900">{title}</h3>
        </div>
        <ChevronDown
          className={`h-5 w-5 text-gray-400 transition-transform ${open ? 'rotate-180' : ''}`}
        />
      </button>
      {open && <div className="border-t border-gray-200 px-6 py-5">{children}</div>}
    </div>
  );
}

// --- School Settings Component ---
function SchoolSettingsPanel({ schoolId }: { schoolId: string }) {
  const [settings, setSettings] = useState<SchoolSettingsData>(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fetchSettings = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    try {
      const res = await authFetch(`/api/settings/school?school_id=${schoolId}`);
      const json = await res.json();
      if (json.success && json.data) {
        const d = json.data;
        const s = d.settings || {};
        setSettings({
          name: d.name || '',
          name_my: d.name_my || '',
          code: d.code || '',
          address: d.address || '',
          phone: d.phone || '',
          school_start_time: s.school_start_time || DEFAULT_SETTINGS.school_start_time,
          school_end_time: s.school_end_time || DEFAULT_SETTINGS.school_end_time,
          canteen_open_time: s.canteen_open_time || DEFAULT_SETTINGS.canteen_open_time,
          canteen_close_time: s.canteen_close_time || DEFAULT_SETTINGS.canteen_close_time,
          academic_year_start: s.academic_year_start || DEFAULT_SETTINGS.academic_year_start,
          academic_year_end: s.academic_year_end || DEFAULT_SETTINGS.academic_year_end,
          term_semester: s.term_semester || DEFAULT_SETTINGS.term_semester,
          default_daily_spending_limit: s.default_daily_spending_limit?.toString() || DEFAULT_SETTINGS.default_daily_spending_limit,
          low_balance_alert_threshold: s.low_balance_alert_threshold?.toString() || DEFAULT_SETTINGS.low_balance_alert_threshold,
          grading_scale: normalizeGradingScale(s.grading_scale),
        });
      }
    } catch {
      setError('Failed to load school settings');
    }
    setLoading(false);
  }, [schoolId]);

  useEffect(() => {
    fetchSettings();
  }, [fetchSettings]);

  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => setToast(null), 3000);
      return () => clearTimeout(timer);
    }
  }, [toast]);

  function updateField(field: Exclude<keyof SchoolSettingsData, 'grading_scale'>, value: string) {
    setSettings((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSave() {
    setSaving(true);
    setError(null);
    try {
      const res = await authFetch('/api/settings/school', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          school_id: schoolId,
          name: settings.name,
          name_my: settings.name_my || null,
          address: settings.address || null,
          phone: settings.phone || null,
          settings: {
            school_start_time: settings.school_start_time,
            school_end_time: settings.school_end_time,
            canteen_open_time: settings.canteen_open_time,
            canteen_close_time: settings.canteen_close_time,
            academic_year_start: settings.academic_year_start,
            academic_year_end: settings.academic_year_end,
            term_semester: settings.term_semester,
            default_daily_spending_limit: parseInt(settings.default_daily_spending_limit) || 0,
            low_balance_alert_threshold: parseInt(settings.low_balance_alert_threshold) || 0,
            grading_scale: settings.grading_scale,
          },
        }),
      });
      const json = await res.json();
      if (json.success) {
        setToast('Settings saved successfully');
      } else {
        setError(json.error || 'Failed to save settings');
      }
    } catch {
      setError('Network error while saving');
    }
    setSaving(false);
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
      </div>
    );
  }

  const inputClass =
    'w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500';
  const labelClass = 'block text-sm font-medium text-gray-700 mb-1';
  const readOnlyClass =
    'w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-500 cursor-not-allowed';

  return (
    <div className="space-y-6">
      {/* Toast */}
      {toast && (
        <div className="fixed right-6 top-6 z-50 rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm font-medium text-green-800 shadow-lg">
          {toast}
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
          <button onClick={() => setError(null)} className="ml-2 font-medium hover:underline">
            Dismiss
          </button>
        </div>
      )}

      {/* School Profile */}
      <SettingsSection icon={Building2} title="School Profile">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelClass}>School Name</label>
            <input
              type="text"
              value={settings.name}
              onChange={(e) => updateField('name', e.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>School Name (Myanmar)</label>
            <input
              type="text"
              value={settings.name_my}
              onChange={(e) => updateField('name_my', e.target.value)}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass}>School Code</label>
            <input type="text" value={settings.code} readOnly className={readOnlyClass} />
          </div>
          <div>
            <label className={labelClass}>Phone</label>
            <input
              type="text"
              value={settings.phone}
              onChange={(e) => updateField('phone', e.target.value)}
              placeholder="e.g. 09-123456789"
              className={inputClass}
            />
          </div>
          <div className="sm:col-span-2">
            <label className={labelClass}>Address</label>
            <input
              type="text"
              value={settings.address}
              onChange={(e) => updateField('address', e.target.value)}
              placeholder="School address"
              className={inputClass}
            />
          </div>
        </div>
      </SettingsSection>

      {/* Academic Settings */}
      <SettingsSection icon={BookOpen} title="Academic Settings">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelClass}>Academic Year Start</label>
            <select
              value={settings.academic_year_start}
              onChange={(e) => updateField('academic_year_start', e.target.value)}
              className={inputClass}
            >
              {MONTHS.map((m) => (
                <option key={m.value} value={m.value}>
                  {m.label}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className={labelClass}>Academic Year End</label>
            <select
              value={settings.academic_year_end}
              onChange={(e) => updateField('academic_year_end', e.target.value)}
              className={inputClass}
            >
              {MONTHS.map((m) => (
                <option key={m.value} value={m.value}>
                  {m.label}
                </option>
              ))}
            </select>
          </div>
          <div className="sm:col-span-2">
            <label className={labelClass}>Term / Semester</label>
            <input
              type="text"
              value={settings.term_semester}
              onChange={(e) => updateField('term_semester', e.target.value)}
              placeholder="e.g. Term 1 2026-2027"
              className={inputClass}
            />
          </div>
        </div>
      </SettingsSection>

      {/* Grading Scale */}
      <SettingsSection icon={Award} title="Grading Scale">
        <p className="text-sm text-gray-500 mb-4">
          Configure letter grades, labels, minimum percentage thresholds, and colors.
          Rows are auto-sorted by minimum % descending. The bottom row (0%) cannot be removed.
        </p>
        <div className="space-y-3">
          {[...settings.grading_scale]
            .sort((a, b) => b.min - a.min)
            .map((entry, idx) => {
              const isBottom = entry.min === 0;
              const colorClasses = GRADE_COLOR_CLASSES[entry.color] || GRADE_COLOR_CLASSES.red;
              return (
                <div key={idx} className="flex items-center gap-3 flex-wrap sm:flex-nowrap">
                  {/* Color dot */}
                  <span className={`inline-flex items-center justify-center h-8 w-8 rounded-full ${colorClasses.bg} ${colorClasses.text} text-sm font-bold shrink-0`}>
                    {entry.letter}
                  </span>
                  {/* Letter input */}
                  <input
                    type="text"
                    value={entry.letter}
                    onChange={(e) => {
                      const val = e.target.value.toUpperCase().slice(0, 2);
                      setSettings(prev => ({
                        ...prev,
                        grading_scale: prev.grading_scale.map(g =>
                          g === entry ? { ...g, letter: val } : g
                        ),
                      }));
                    }}
                    maxLength={2}
                    className={inputClass + ' !w-16'}
                    placeholder="A"
                  />
                  {/* Label input */}
                  <input
                    type="text"
                    value={entry.label}
                    onChange={(e) => {
                      setSettings(prev => ({
                        ...prev,
                        grading_scale: prev.grading_scale.map(g =>
                          g === entry ? { ...g, label: e.target.value } : g
                        ),
                      }));
                    }}
                    className={inputClass + ' !w-32'}
                    placeholder="Label"
                  />
                  {/* Min % input */}
                  <div className="flex items-center gap-1">
                    <label className="text-xs text-gray-500 shrink-0">Min %</label>
                    <input
                      type="number"
                      value={entry.min}
                      onChange={(e) => {
                        const val = Math.max(0, Math.min(100, parseInt(e.target.value) || 0));
                        setSettings(prev => ({
                          ...prev,
                          grading_scale: prev.grading_scale.map(g =>
                            g === entry ? { ...g, min: val } : g
                          ),
                        }));
                      }}
                      min="0"
                      max="100"
                      disabled={isBottom}
                      className={(isBottom ? readOnlyClass : inputClass) + ' !w-20'}
                    />
                  </div>
                  {/* Color picker */}
                  <select
                    value={entry.color}
                    onChange={(e) => {
                      setSettings(prev => ({
                        ...prev,
                        grading_scale: prev.grading_scale.map(g =>
                          g === entry ? { ...g, color: e.target.value } : g
                        ),
                      }));
                    }}
                    className={inputClass + ' !w-24'}
                  >
                    {GRADE_COLORS.map(c => (
                      <option key={c} value={c}>{c.charAt(0).toUpperCase() + c.slice(1)}</option>
                    ))}
                  </select>
                  {/* Delete button (not for the bottom 0% row) */}
                  {!isBottom ? (
                    <button
                      onClick={() => {
                        setSettings(prev => ({
                          ...prev,
                          grading_scale: prev.grading_scale.filter(g => g !== entry),
                        }));
                      }}
                      className="shrink-0 rounded p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                      title="Remove grade"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  ) : (
                    <div className="w-[30px] shrink-0" />
                  )}
                </div>
              );
            })}
        </div>
        {/* Add Grade button */}
        <button
          onClick={() => {
            setSettings(prev => {
              const sorted = [...prev.grading_scale].sort((a, b) => b.min - a.min);
              // Find a gap for the new grade's min %
              const secondLowest = sorted.length >= 2 ? sorted[sorted.length - 2].min : 50;
              const newMin = Math.max(1, Math.round(secondLowest / 2));
              // Pick a color not yet used
              const usedColors = new Set(prev.grading_scale.map(g => g.color));
              const availColor = GRADE_COLORS.find(c => !usedColors.has(c)) || 'blue';
              return {
                ...prev,
                grading_scale: [
                  ...prev.grading_scale,
                  { letter: '', label: '', min: newMin, color: availColor },
                ],
              };
            });
          }}
          className="mt-4 flex items-center gap-2 text-sm font-medium text-blue-600 hover:text-blue-800"
        >
          <Plus className="h-4 w-4" />
          Add Grade
        </button>
      </SettingsSection>

      {/* Financial Settings */}
      <SettingsSection icon={DollarSign} title="Financial Settings">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelClass}>Default Daily Spending Limit (MMK)</label>
            <input
              type="number"
              value={settings.default_daily_spending_limit}
              onChange={(e) => updateField('default_daily_spending_limit', e.target.value)}
              placeholder="e.g. 5000"
              min="0"
              className={inputClass}
            />
            <p className="mt-1 text-xs text-gray-400">Applied to new students by default</p>
          </div>
          <div>
            <label className={labelClass}>Low Balance Alert Threshold (MMK)</label>
            <input
              type="number"
              value={settings.low_balance_alert_threshold}
              onChange={(e) => updateField('low_balance_alert_threshold', e.target.value)}
              placeholder="e.g. 1000"
              min="0"
              className={inputClass}
            />
            <p className="mt-1 text-xs text-gray-400">Triggers parent notification</p>
          </div>
          <div>
            <label className={labelClass}>Currency</label>
            <input type="text" value="MMK" readOnly className={readOnlyClass} />
          </div>
        </div>
      </SettingsSection>

      {/* Save Button */}
      <div className="flex justify-end">
        <button
          onClick={handleSave}
          disabled={saving}
          className="flex items-center gap-2 rounded-lg bg-green-600 px-6 py-2.5 text-sm font-medium text-white shadow-sm hover:bg-green-700 disabled:opacity-50 transition-colors"
        >
          {saving ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Save className="h-4 w-4" />
          )}
          {saving ? 'Saving...' : 'Save Settings'}
        </button>
      </div>
    </div>
  );
}

// --- Reusable list management component ---
function ManageableList({
  title,
  items,
  loading,
  onAdd,
  onDelete,
  onToggleActive,
  onRename,
  onMoveUp,
  onMoveDown,
  addPlaceholder,
}: {
  title: string;
  items: GradeItem[] | SectionItem[];
  loading: boolean;
  onAdd: (name: string) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onToggleActive: (id: string, isActive: boolean) => Promise<void>;
  onRename: (id: string, name: string) => Promise<void>;
  onMoveUp: (index: number) => Promise<void>;
  onMoveDown: (index: number) => Promise<void>;
  addPlaceholder: string;
}) {
  const [newName, setNewName] = useState('');
  const [adding, setAdding] = useState(false);
  const [showInput, setShowInput] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  async function handleAdd() {
    if (!newName.trim()) return;
    setAdding(true);
    await onAdd(newName.trim());
    setNewName('');
    setShowInput(false);
    setAdding(false);
  }

  async function handleRename(id: string) {
    if (!editName.trim()) return;
    setActionLoading(id);
    await onRename(id, editName.trim());
    setEditingId(null);
    setEditName('');
    setActionLoading(null);
  }

  async function handleDelete(id: string) {
    setActionLoading(id);
    await onDelete(id);
    setActionLoading(null);
  }

  async function handleToggle(id: string, currentActive: boolean) {
    setActionLoading(id);
    await onToggleActive(id, !currentActive);
    setActionLoading(null);
  }

  return (
    <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
      <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
        <h2 className="text-lg font-semibold text-gray-900">{title}</h2>
        <span className="text-sm text-gray-500">{items.length} items</span>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
        </div>
      ) : (
        <div className="divide-y divide-gray-100">
          {items.length === 0 && (
            <div className="px-6 py-8 text-center text-sm text-gray-400">
              No items yet. Add one below.
            </div>
          )}
          {items.map((item, index) => (
            <div
              key={item.id}
              className={`flex items-center gap-3 px-6 py-3 transition-colors hover:bg-gray-50 ${
                !item.is_active ? 'opacity-50' : ''
              }`}
            >
              <GripVertical className="h-4 w-4 text-gray-300 shrink-0" />

              {/* Name / Edit */}
              <div className="flex-1 min-w-0">
                {editingId === item.id ? (
                  <div className="flex items-center gap-2">
                    <input
                      type="text"
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handleRename(item.id);
                        if (e.key === 'Escape') { setEditingId(null); setEditName(''); }
                      }}
                      className="w-full rounded-md border border-gray-300 px-2 py-1 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                      autoFocus
                    />
                    <button
                      onClick={() => handleRename(item.id)}
                      disabled={actionLoading === item.id}
                      className="rounded p-1 text-green-600 hover:bg-green-50"
                    >
                      <Check className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => { setEditingId(null); setEditName(''); }}
                      className="rounded p-1 text-gray-400 hover:bg-gray-100"
                    >
                      <X className="h-4 w-4" />
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={() => { setEditingId(item.id); setEditName(item.name); }}
                    className="group flex items-center gap-2 text-sm font-medium text-gray-900"
                  >
                    {item.name}
                    <Pencil className="h-3 w-3 text-gray-300 opacity-0 group-hover:opacity-100 transition-opacity" />
                  </button>
                )}
              </div>

              {/* Active toggle */}
              <button
                onClick={() => handleToggle(item.id, item.is_active)}
                disabled={actionLoading === item.id}
                className="shrink-0"
                title={item.is_active ? 'Click to deactivate' : 'Click to activate'}
              >
                <div className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                  item.is_active ? 'bg-green-500' : 'bg-gray-300'
                }`}>
                  <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                    item.is_active ? 'translate-x-4' : 'translate-x-1'
                  }`} />
                </div>
              </button>

              {/* Reorder buttons */}
              <div className="flex flex-col shrink-0">
                <button
                  onClick={() => onMoveUp(index)}
                  disabled={index === 0}
                  className="rounded p-0.5 text-gray-400 hover:text-gray-600 disabled:opacity-30 disabled:cursor-not-allowed"
                >
                  <ChevronUp className="h-3.5 w-3.5" />
                </button>
                <button
                  onClick={() => onMoveDown(index)}
                  disabled={index === items.length - 1}
                  className="rounded p-0.5 text-gray-400 hover:text-gray-600 disabled:opacity-30 disabled:cursor-not-allowed"
                >
                  <ChevronDown className="h-3.5 w-3.5" />
                </button>
              </div>

              {/* Delete */}
              <button
                onClick={() => handleDelete(item.id)}
                disabled={actionLoading === item.id}
                className="shrink-0 rounded p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                title="Delete"
              >
                {actionLoading === item.id ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Trash2 className="h-4 w-4" />
                )}
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Add new item */}
      <div className="border-t border-gray-200 px-6 py-4">
        {showInput ? (
          <div className="flex items-center gap-2">
            <input
              type="text"
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleAdd();
                if (e.key === 'Escape') { setShowInput(false); setNewName(''); }
              }}
              placeholder={addPlaceholder}
              className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              autoFocus
            />
            <button
              onClick={handleAdd}
              disabled={adding || !newName.trim()}
              className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
            >
              {adding ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Add'}
            </button>
            <button
              onClick={() => { setShowInput(false); setNewName(''); }}
              className="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-600 hover:bg-gray-50"
            >
              Cancel
            </button>
          </div>
        ) : (
          <button
            onClick={() => setShowInput(true)}
            className="flex items-center gap-2 text-sm font-medium text-blue-600 hover:text-blue-800"
          >
            <Plus className="h-4 w-4" />
            Add {title.replace(/s$/, '')}
          </button>
        )}
      </div>
    </div>
  );
}

// --- Subject Management Component ---
function SubjectManagement({ schoolId, grades }: { schoolId: string; grades: GradeItem[] }) {
  const [subjects, setSubjects] = useState<SubjectItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingSubject, setEditingSubject] = useState<SubjectItem | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [error, setError] = useState('');

  // Form state
  const [formName, setFormName] = useState('');
  const [formNameMy, setFormNameMy] = useState('');
  const [formGradeLevels, setFormGradeLevels] = useState<string[]>([]);
  const [formFullMarks, setFormFullMarks] = useState('100');
  const [formPassMarks, setFormPassMarks] = useState('40');
  const [formSaving, setFormSaving] = useState(false);

  const fetchSubjects = useCallback(async () => {
    try {
      const params = schoolId ? `?school_id=${schoolId}` : '';
      const res = await authFetch(`/api/subjects${params}`);
      const json = await res.json();
      if (json.success) setSubjects(json.data);
    } catch { /* silently fail */ }
    setLoading(false);
  }, [schoolId]);

  useEffect(() => { fetchSubjects(); }, [fetchSubjects]);

  function resetForm() {
    setFormName('');
    setFormNameMy('');
    setFormGradeLevels([]);
    setFormFullMarks('100');
    setFormPassMarks('40');
    setEditingSubject(null);
  }

  function openEdit(subject: SubjectItem) {
    setEditingSubject(subject);
    setFormName(subject.name);
    setFormNameMy(subject.name_my || '');
    setFormGradeLevels(subject.grade_levels || []);
    setFormFullMarks(String(subject.full_marks));
    setFormPassMarks(String(subject.pass_marks));
    setShowAddModal(true);
  }

  function toggleGradeLevel(gradeName: string) {
    setFormGradeLevels(prev =>
      prev.includes(gradeName)
        ? prev.filter(g => g !== gradeName)
        : [...prev, gradeName]
    );
  }

  async function handleSaveSubject() {
    if (!formName.trim()) return;
    setFormSaving(true);
    setError('');
    try {
      if (editingSubject) {
        await authFetch('/api/subjects', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            id: editingSubject.id,
            name: formName.trim(),
            name_my: formNameMy.trim() || null,
            grade_levels: formGradeLevels,
            full_marks: parseInt(formFullMarks) || 100,
            pass_marks: parseInt(formPassMarks) || 40,
          }),
        });
      } else {
        await authFetch('/api/subjects', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            school_id: schoolId,
            name: formName.trim(),
            name_my: formNameMy.trim() || null,
            grade_levels: formGradeLevels,
            full_marks: parseInt(formFullMarks) || 100,
            pass_marks: parseInt(formPassMarks) || 40,
          }),
        });
      }
      setShowAddModal(false);
      resetForm();
      await fetchSubjects();
    } catch {
      setError('Failed to save subject');
    }
    setFormSaving(false);
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this subject? Existing grade records referencing it may be affected.')) return;
    setActionLoading(id);
    await authFetch('/api/subjects', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    await fetchSubjects();
    setActionLoading(null);
  }

  async function handleToggleActive(id: string, isActive: boolean) {
    setActionLoading(id);
    await authFetch('/api/subjects', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, is_active: !isActive }),
    });
    await fetchSubjects();
    setActionLoading(null);
  }

  const activeGrades = grades.filter(g => g.is_active);

  return (
    <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
      <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
        <h2 className="text-lg font-semibold text-gray-900">Subjects</h2>
        <span className="text-sm text-gray-500">{subjects.length} subjects</span>
      </div>

      {error && (
        <div className="mx-6 mt-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
          <button onClick={() => setError('')} className="ml-2 font-medium hover:underline">Dismiss</button>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
        </div>
      ) : (
        <div className="divide-y divide-gray-100">
          {subjects.length === 0 && (
            <div className="px-6 py-8 text-center text-sm text-gray-400">
              No subjects yet. Add one below.
            </div>
          )}
          {subjects.map((subject) => (
            <div
              key={subject.id}
              className={`px-6 py-3 flex items-center gap-3 transition-colors hover:bg-gray-50 ${!subject.is_active ? 'opacity-50' : ''}`}
            >
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="text-sm font-medium text-gray-900">{subject.name}</span>
                  {subject.name_my && <span className="text-xs text-gray-500">({subject.name_my})</span>}
                </div>
                <div className="flex items-center gap-1.5 mt-1 flex-wrap">
                  {(subject.grade_levels || []).map(gl => (
                    <span key={gl} className="inline-block rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-700">
                      {gl}
                    </span>
                  ))}
                  <span className="text-xs text-gray-400 ml-1">
                    Full: {subject.full_marks} | Pass: {subject.pass_marks}
                  </span>
                </div>
              </div>

              {/* Active toggle */}
              <button
                onClick={() => handleToggleActive(subject.id, subject.is_active)}
                disabled={actionLoading === subject.id}
                className="shrink-0"
              >
                <div className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                  subject.is_active ? 'bg-green-500' : 'bg-gray-300'
                }`}>
                  <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                    subject.is_active ? 'translate-x-4' : 'translate-x-1'
                  }`} />
                </div>
              </button>

              {/* Edit */}
              <button
                onClick={() => openEdit(subject)}
                className="shrink-0 rounded p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
              >
                <Pencil className="h-4 w-4" />
              </button>

              {/* Delete */}
              <button
                onClick={() => handleDelete(subject.id)}
                disabled={actionLoading === subject.id}
                className="shrink-0 rounded p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
              >
                {actionLoading === subject.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Add button */}
      <div className="border-t border-gray-200 px-6 py-4">
        <button
          onClick={() => { resetForm(); setShowAddModal(true); }}
          className="flex items-center gap-2 text-sm font-medium text-blue-600 hover:text-blue-800"
        >
          <Plus className="h-4 w-4" />
          Add Subject
        </button>
      </div>

      {/* Add/Edit Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              {editingSubject ? 'Edit Subject' : 'Add Subject'}
            </h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Subject Name</label>
                <input
                  type="text"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="e.g. Mathematics"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  autoFocus
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Grade Levels</label>
                <div className="flex flex-wrap gap-2">
                  {activeGrades.map(g => (
                    <label key={g.id} className="flex items-center gap-1.5 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={formGradeLevels.includes(g.name)}
                        onChange={() => toggleGradeLevel(g.name)}
                        className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <span className="text-sm text-gray-700">{g.name}</span>
                    </label>
                  ))}
                  {activeGrades.length === 0 && (
                    <span className="text-xs text-gray-400">No grades configured. Add grades first.</span>
                  )}
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Full Marks</label>
                  <input
                    type="number"
                    value={formFullMarks}
                    onChange={(e) => setFormFullMarks(e.target.value)}
                    min="1"
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Pass Marks</label>
                  <input
                    type="number"
                    value={formPassMarks}
                    onChange={(e) => setFormPassMarks(e.target.value)}
                    min="0"
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
              </div>
            </div>
            <div className="mt-6 flex items-center gap-2 justify-end">
              <button
                onClick={() => { setShowAddModal(false); resetForm(); }}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-600 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveSubject}
                disabled={formSaving || !formName.trim()}
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
              >
                {formSaving ? <Loader2 className="h-4 w-4 animate-spin" /> : editingSubject ? 'Update' : 'Add'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// --- Exam Type Management Component ---
function ExamTypeManagement({ schoolId }: { schoolId: string }) {
  const [examTypes, setExamTypes] = useState<ExamTypeItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingExamType, setEditingExamType] = useState<ExamTypeItem | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [error, setError] = useState('');

  // Form state
  const [formName, setFormName] = useState('');
  const [formNameMy, setFormNameMy] = useState('');
  const [formWeight, setFormWeight] = useState('100');
  const [formTerm, setFormTerm] = useState('');
  const [formSaving, setFormSaving] = useState(false);

  const fetchExamTypes = useCallback(async () => {
    try {
      const params = schoolId ? `?school_id=${schoolId}` : '';
      const res = await authFetch(`/api/exam-types${params}`);
      const json = await res.json();
      if (json.success) setExamTypes(json.data);
    } catch { /* silently fail */ }
    setLoading(false);
  }, [schoolId]);

  useEffect(() => { fetchExamTypes(); }, [fetchExamTypes]);

  function resetForm() {
    setFormName('');
    setFormNameMy('');
    setFormWeight('100');
    setFormTerm('');
    setEditingExamType(null);
  }

  function openEdit(examType: ExamTypeItem) {
    setEditingExamType(examType);
    setFormName(examType.name);
    setFormNameMy(examType.name_my || '');
    setFormWeight(String(examType.weight));
    setFormTerm(examType.term || '');
    setShowAddModal(true);
  }

  async function handleSaveExamType() {
    if (!formName.trim()) return;
    setFormSaving(true);
    setError('');
    try {
      if (editingExamType) {
        await authFetch('/api/exam-types', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            id: editingExamType.id,
            name: formName.trim(),
            name_my: formNameMy.trim() || null,
            weight: parseFloat(formWeight) || 100,
            term: formTerm.trim() || null,
          }),
        });
      } else {
        await authFetch('/api/exam-types', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            school_id: schoolId,
            name: formName.trim(),
            name_my: formNameMy.trim() || null,
            weight: parseFloat(formWeight) || 100,
            term: formTerm.trim() || null,
          }),
        });
      }
      setShowAddModal(false);
      resetForm();
      await fetchExamTypes();
    } catch {
      setError('Failed to save exam type');
    }
    setFormSaving(false);
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this exam type? Existing grade records referencing it may be affected.')) return;
    setActionLoading(id);
    await authFetch('/api/exam-types', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    await fetchExamTypes();
    setActionLoading(null);
  }

  async function handleToggleActive(id: string, isActive: boolean) {
    setActionLoading(id);
    await authFetch('/api/exam-types', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, is_active: !isActive }),
    });
    await fetchExamTypes();
    setActionLoading(null);
  }

  return (
    <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
      <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
        <h2 className="text-lg font-semibold text-gray-900">Exam Types</h2>
        <span className="text-sm text-gray-500">{examTypes.length} types</span>
      </div>

      {error && (
        <div className="mx-6 mt-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
          <button onClick={() => setError('')} className="ml-2 font-medium hover:underline">Dismiss</button>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
        </div>
      ) : (
        <div className="divide-y divide-gray-100">
          {examTypes.length === 0 && (
            <div className="px-6 py-8 text-center text-sm text-gray-400">
              No exam types yet. Add one below.
            </div>
          )}
          {examTypes.map((et) => (
            <div
              key={et.id}
              className={`px-6 py-3 flex items-center gap-3 transition-colors hover:bg-gray-50 ${!et.is_active ? 'opacity-50' : ''}`}
            >
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-gray-900">{et.name}</span>
                  {et.name_my && <span className="text-xs text-gray-500">({et.name_my})</span>}
                </div>
                <div className="flex items-center gap-2 mt-1">
                  <span className="text-xs text-gray-400">Weight: {et.weight}%</span>
                  {et.term && (
                    <span className="inline-block rounded-full bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-700">
                      {et.term}
                    </span>
                  )}
                </div>
              </div>

              {/* Active toggle */}
              <button
                onClick={() => handleToggleActive(et.id, et.is_active)}
                disabled={actionLoading === et.id}
                className="shrink-0"
              >
                <div className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                  et.is_active ? 'bg-green-500' : 'bg-gray-300'
                }`}>
                  <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                    et.is_active ? 'translate-x-4' : 'translate-x-1'
                  }`} />
                </div>
              </button>

              {/* Edit */}
              <button
                onClick={() => openEdit(et)}
                className="shrink-0 rounded p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
              >
                <Pencil className="h-4 w-4" />
              </button>

              {/* Delete */}
              <button
                onClick={() => handleDelete(et.id)}
                disabled={actionLoading === et.id}
                className="shrink-0 rounded p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
              >
                {actionLoading === et.id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Add button */}
      <div className="border-t border-gray-200 px-6 py-4">
        <button
          onClick={() => { resetForm(); setShowAddModal(true); }}
          className="flex items-center gap-2 text-sm font-medium text-blue-600 hover:text-blue-800"
        >
          <Plus className="h-4 w-4" />
          Add Exam Type
        </button>
      </div>

      {/* Add/Edit Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              {editingExamType ? 'Edit Exam Type' : 'Add Exam Type'}
            </h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Exam Type Name</label>
                <input
                  type="text"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="e.g. Mid-term Exam"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  autoFocus
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Weight (%)</label>
                  <input
                    type="number"
                    value={formWeight}
                    onChange={(e) => setFormWeight(e.target.value)}
                    min="0"
                    max="100"
                    step="0.01"
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Term</label>
                  <input
                    type="text"
                    value={formTerm}
                    onChange={(e) => setFormTerm(e.target.value)}
                    placeholder="e.g. Term 1"
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
              </div>
            </div>
            <div className="mt-6 flex items-center gap-2 justify-end">
              <button
                onClick={() => { setShowAddModal(false); resetForm(); }}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-600 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveExamType}
                disabled={formSaving || !formName.trim()}
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
              >
                {formSaving ? <Loader2 className="h-4 w-4 animate-spin" /> : editingExamType ? 'Update' : 'Add'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// --- User Management Component ---
function UserManagement() {
  const [users, setUsers] = useState<UserItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [error, setError] = useState('');

  // Add form state
  const [newEmail, setNewEmail] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newName, setNewName] = useState('');
  const [newRole, setNewRole] = useState<string>('admin');
  const [adding, setAdding] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  // Edit password state
  const [editPasswordId, setEditPasswordId] = useState<string | null>(null);
  const [editPasswordValue, setEditPasswordValue] = useState('');
  const [showEditPassword, setShowEditPassword] = useState(false);

  const fetchUsers = useCallback(async () => {
    try {
      const res = await authFetch('/api/settings/users');
      const json = await res.json();
      if (json.success) setUsers(json.data);
    } catch {
      // silently fail
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  async function handleAddUser(e: React.FormEvent) {
    e.preventDefault();
    if (!newEmail || !newPassword || !newName) return;
    setAdding(true);
    setError('');

    try {
      const res = await authFetch('/api/settings/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: newEmail,
          password: newPassword,
          full_name: newName,
          role: newRole,
        }),
      });
      const json = await res.json();
      if (!json.success) {
        setError(json.error || 'Failed to create user');
      } else {
        setShowAddForm(false);
        setNewEmail('');
        setNewPassword('');
        setNewName('');
        setNewRole('admin');
        await fetchUsers();
      }
    } catch {
      setError('Network error');
    }
    setAdding(false);
  }

  async function handleToggleActive(id: string, is_active: boolean) {
    setActionLoading(id);
    await authFetch('/api/settings/users', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, is_active }),
    });
    await fetchUsers();
    setActionLoading(null);
  }

  async function handleDelete(id: string) {
    if (!confirm('Are you sure you want to delete this user? This cannot be undone.')) return;
    setActionLoading(id);
    await authFetch('/api/settings/users', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    await fetchUsers();
    setActionLoading(null);
  }

  async function handleChangePassword(id: string) {
    if (!editPasswordValue || editPasswordValue.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }
    setActionLoading(id);
    const res = await authFetch('/api/settings/users', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, password: editPasswordValue }),
    });
    const json = await res.json();
    if (!json.success) {
      setError(json.error || 'Failed to update password');
    } else {
      setEditPasswordId(null);
      setEditPasswordValue('');
    }
    setActionLoading(null);
  }

  const roleLabels: Record<string, string> = {
    admin: 'Admin',
    counter_staff: 'Counter Staff',
    seller: 'Seller',
  };

  const roleBadgeColors: Record<string, string> = {
    admin: 'bg-purple-100 text-purple-700',
    counter_staff: 'bg-blue-100 text-blue-700',
    seller: 'bg-green-100 text-green-700',
  };

  return (
    <div className="rounded-xl border border-gray-200 bg-white shadow-sm">
      <div className="flex items-center justify-between border-b border-gray-200 px-6 py-4">
        <h2 className="text-lg font-semibold text-gray-900">User Management</h2>
        <span className="text-sm text-gray-500">{users.length} users</span>
      </div>

      {error && (
        <div className="mx-6 mt-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
          <button onClick={() => setError('')} className="ml-2 font-medium hover:underline">Dismiss</button>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
        </div>
      ) : (
        <div className="divide-y divide-gray-100">
          {users.length === 0 && (
            <div className="px-6 py-8 text-center text-sm text-gray-400">
              No users yet. Add one below.
            </div>
          )}
          {users.map((user) => (
            <div
              key={user.id}
              className={`px-6 py-4 transition-colors hover:bg-gray-50 ${
                !user.is_active ? 'opacity-50' : ''
              }`}
            >
              <div className="flex items-center gap-4">
                {/* User info */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-gray-900">{user.full_name}</span>
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${roleBadgeColors[user.role] || 'bg-gray-100 text-gray-700'}`}>
                      {roleLabels[user.role] || user.role}
                    </span>
                  </div>
                  <p className="text-sm text-gray-500 truncate">{user.email}</p>
                </div>

                {/* Active toggle */}
                <button
                  onClick={() => handleToggleActive(user.id, !user.is_active)}
                  disabled={actionLoading === user.id}
                  className="shrink-0"
                  title={user.is_active ? 'Click to deactivate' : 'Click to activate'}
                >
                  <div className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                    user.is_active ? 'bg-green-500' : 'bg-gray-300'
                  }`}>
                    <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${
                      user.is_active ? 'translate-x-4' : 'translate-x-1'
                    }`} />
                  </div>
                </button>

                {/* Change password */}
                <button
                  onClick={() => {
                    setEditPasswordId(editPasswordId === user.id ? null : user.id);
                    setEditPasswordValue('');
                  }}
                  className="shrink-0 rounded p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
                  title="Change password"
                >
                  <Pencil className="h-4 w-4" />
                </button>

                {/* Delete */}
                <button
                  onClick={() => handleDelete(user.id)}
                  disabled={actionLoading === user.id}
                  className="shrink-0 rounded p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                  title="Delete user"
                >
                  {actionLoading === user.id ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Trash2 className="h-4 w-4" />
                  )}
                </button>
              </div>

              {/* Change password inline form */}
              {editPasswordId === user.id && (
                <div className="mt-3 flex items-center gap-2">
                  <div className="relative flex-1">
                    <input
                      type={showEditPassword ? 'text' : 'password'}
                      value={editPasswordValue}
                      onChange={(e) => setEditPasswordValue(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handleChangePassword(user.id);
                        if (e.key === 'Escape') { setEditPasswordId(null); setEditPasswordValue(''); }
                      }}
                      placeholder="New password (min 6 chars)"
                      className="w-full rounded-md border border-gray-300 px-3 py-1.5 pr-9 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                      autoFocus
                    />
                    <button
                      type="button"
                      onClick={() => setShowEditPassword(!showEditPassword)}
                      className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      {showEditPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </button>
                  </div>
                  <button
                    onClick={() => handleChangePassword(user.id)}
                    disabled={actionLoading === user.id || editPasswordValue.length < 6}
                    className="rounded-md bg-blue-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                  >
                    Save
                  </button>
                  <button
                    onClick={() => { setEditPasswordId(null); setEditPasswordValue(''); }}
                    className="rounded-md border border-gray-300 px-3 py-1.5 text-sm text-gray-600 hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Add new user */}
      <div className="border-t border-gray-200 px-6 py-4">
        {showAddForm ? (
          <form onSubmit={handleAddUser} className="space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <input
                type="text"
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                placeholder="Full name"
                required
                className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
              <input
                type="email"
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                placeholder="Email address"
                required
                className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Password (min 6 chars)"
                  required
                  minLength={6}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 pr-9 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
              <select
                value={newRole}
                onChange={(e) => setNewRole(e.target.value)}
                className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              >
                <option value="admin">Admin</option>
                <option value="counter_staff">Counter Staff</option>
                <option value="seller">Seller</option>
              </select>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="submit"
                disabled={adding || !newEmail || !newPassword || !newName}
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
              >
                {adding ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Create User'}
              </button>
              <button
                type="button"
                onClick={() => { setShowAddForm(false); setNewEmail(''); setNewPassword(''); setNewName(''); setError(''); }}
                className="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-600 hover:bg-gray-50"
              >
                Cancel
              </button>
            </div>
          </form>
        ) : (
          <button
            onClick={() => setShowAddForm(true)}
            className="flex items-center gap-2 text-sm font-medium text-blue-600 hover:text-blue-800"
          >
            <Plus className="h-4 w-4" />
            Add User
          </button>
        )}
      </div>
    </div>
  );
}

export default function SettingsPage() {
  const { selectedSchoolId } = useSchoolContext();
  const [activeTab, setActiveTab] = useState<SettingsTab>('school');
  const [grades, setGrades] = useState<GradeItem[]>([]);
  const [sections, setSections] = useState<SectionItem[]>([]);
  const [gradesLoading, setGradesLoading] = useState(true);
  const [sectionsLoading, setSectionsLoading] = useState(true);

  const fetchGrades = useCallback(async () => {
    try {
      const params = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
      const res = await authFetch(`/api/settings/grades${params}`);
      const json = await res.json();
      if (json.success) setGrades(json.data);
    } catch {
      // silently fail
    }
    setGradesLoading(false);
  }, [selectedSchoolId]);

  const fetchSections = useCallback(async () => {
    try {
      const params = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
      const res = await authFetch(`/api/settings/sections${params}`);
      const json = await res.json();
      if (json.success) setSections(json.data);
    } catch {
      // silently fail
    }
    setSectionsLoading(false);
  }, [selectedSchoolId]);

  useEffect(() => {
    fetchGrades();
    fetchSections();
  }, [fetchGrades, fetchSections]);

  // --- Grade handlers ---
  async function addGrade(name: string) {
    await authFetch('/api/settings/grades', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, school_id: selectedSchoolId || undefined }),
    });
    await fetchGrades();
  }

  async function deleteGrade(id: string) {
    await authFetch('/api/settings/grades', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    await fetchGrades();
  }

  async function toggleGradeActive(id: string, is_active: boolean) {
    await authFetch('/api/settings/grades', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, is_active }),
    });
    await fetchGrades();
  }

  async function renameGrade(id: string, name: string) {
    await authFetch('/api/settings/grades', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, name }),
    });
    await fetchGrades();
  }

  async function moveGradeUp(index: number) {
    if (index === 0) return;
    const current = grades[index];
    const above = grades[index - 1];
    await Promise.all([
      authFetch('/api/settings/grades', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: current.id, display_order: above.display_order }),
      }),
      authFetch('/api/settings/grades', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: above.id, display_order: current.display_order }),
      }),
    ]);
    await fetchGrades();
  }

  async function moveGradeDown(index: number) {
    if (index >= grades.length - 1) return;
    const current = grades[index];
    const below = grades[index + 1];
    await Promise.all([
      authFetch('/api/settings/grades', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: current.id, display_order: below.display_order }),
      }),
      authFetch('/api/settings/grades', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: below.id, display_order: current.display_order }),
      }),
    ]);
    await fetchGrades();
  }

  // --- Section handlers ---
  async function addSection(name: string) {
    await authFetch('/api/settings/sections', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, school_id: selectedSchoolId || undefined }),
    });
    await fetchSections();
  }

  async function deleteSection(id: string) {
    await authFetch('/api/settings/sections', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    await fetchSections();
  }

  async function toggleSectionActive(id: string, is_active: boolean) {
    await authFetch('/api/settings/sections', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, is_active }),
    });
    await fetchSections();
  }

  async function renameSection(id: string, name: string) {
    await authFetch('/api/settings/sections', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, name }),
    });
    await fetchSections();
  }

  async function moveSectionUp(index: number) {
    if (index === 0) return;
    const current = sections[index];
    const above = sections[index - 1];
    await Promise.all([
      authFetch('/api/settings/sections', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: current.id, display_order: above.display_order }),
      }),
      authFetch('/api/settings/sections', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: above.id, display_order: current.display_order }),
      }),
    ]);
    await fetchSections();
  }

  async function moveSectionDown(index: number) {
    if (index >= sections.length - 1) return;
    const current = sections[index];
    const below = sections[index + 1];
    await Promise.all([
      authFetch('/api/settings/sections', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: current.id, display_order: below.display_order }),
      }),
      authFetch('/api/settings/sections', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: below.id, display_order: current.display_order }),
      }),
    ]);
    await fetchSections();
  }

  return (
    <div>
      <div className="mb-6">
        <div className="flex items-center gap-3 mb-1">
          <Settings className="h-6 w-6 text-gray-400" />
          <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
        </div>
        <p className="text-sm text-gray-500">Manage school configuration and users.</p>
      </div>

      {/* Tabs */}
      <div className="mb-6 border-b border-gray-200">
        <nav className="flex gap-6">
          <button
            onClick={() => setActiveTab('school')}
            className={`flex items-center gap-2 border-b-2 pb-3 text-sm font-medium transition-colors ${
              activeTab === 'school'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            <School className="h-4 w-4" />
            School
          </button>
          <button
            onClick={() => setActiveTab('users')}
            className={`flex items-center gap-2 border-b-2 pb-3 text-sm font-medium transition-colors ${
              activeTab === 'users'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            <Users className="h-4 w-4" />
            User Management
          </button>
        </nav>
      </div>

      {/* Tab content */}
      {activeTab === 'school' && (
        <div className="space-y-8">
          {/* School Settings */}
          {selectedSchoolId && <SchoolSettingsPanel schoolId={selectedSchoolId} />}
          {!selectedSchoolId && (
            <div className="rounded-xl border border-yellow-200 bg-yellow-50 px-6 py-4 text-sm text-yellow-800">
              Please select a school to configure settings.
            </div>
          )}

          {/* Grades & Sections */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <ManageableList
              title="Grades"
              items={grades}
              loading={gradesLoading}
              onAdd={addGrade}
              onDelete={deleteGrade}
              onToggleActive={toggleGradeActive}
              onRename={renameGrade}
              onMoveUp={moveGradeUp}
              onMoveDown={moveGradeDown}
              addPlaceholder="e.g. Grade 12"
            />

            <ManageableList
              title="Sections"
              items={sections}
              loading={sectionsLoading}
              onAdd={addSection}
              onDelete={deleteSection}
              onToggleActive={toggleSectionActive}
              onRename={renameSection}
              onMoveUp={moveSectionUp}
              onMoveDown={moveSectionDown}
              addPlaceholder="e.g. Section F"
            />
          </div>

          {/* Subjects & Exam Types */}
          {selectedSchoolId && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <SubjectManagement schoolId={selectedSchoolId} grades={grades} />
              <ExamTypeManagement schoolId={selectedSchoolId} />
            </div>
          )}
        </div>
      )}

      {activeTab === 'users' && <UserManagement />}
    </div>
  );
}
