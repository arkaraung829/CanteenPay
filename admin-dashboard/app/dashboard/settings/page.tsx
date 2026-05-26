'use client';

import { useState, useEffect, useCallback } from 'react';
import {
  Settings, Plus, Trash2, ChevronUp, ChevronDown,
  Loader2, Pencil, Check, X, GripVertical,
} from 'lucide-react';

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

export default function SettingsPage() {
  const [grades, setGrades] = useState<GradeItem[]>([]);
  const [sections, setSections] = useState<SectionItem[]>([]);
  const [gradesLoading, setGradesLoading] = useState(true);
  const [sectionsLoading, setSectionsLoading] = useState(true);

  const fetchGrades = useCallback(async () => {
    try {
      const res = await fetch('/api/settings/grades');
      const json = await res.json();
      if (json.success) setGrades(json.data);
    } catch {
      // silently fail
    }
    setGradesLoading(false);
  }, []);

  const fetchSections = useCallback(async () => {
    try {
      const res = await fetch('/api/settings/sections');
      const json = await res.json();
      if (json.success) setSections(json.data);
    } catch {
      // silently fail
    }
    setSectionsLoading(false);
  }, []);

  useEffect(() => {
    fetchGrades();
    fetchSections();
  }, [fetchGrades, fetchSections]);

  // --- Grade handlers ---
  async function addGrade(name: string) {
    await fetch('/api/settings/grades', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name }),
    });
    await fetchGrades();
  }

  async function deleteGrade(id: string) {
    await fetch('/api/settings/grades', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    await fetchGrades();
  }

  async function toggleGradeActive(id: string, is_active: boolean) {
    await fetch('/api/settings/grades', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, is_active }),
    });
    await fetchGrades();
  }

  async function renameGrade(id: string, name: string) {
    await fetch('/api/settings/grades', {
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
      fetch('/api/settings/grades', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: current.id, display_order: above.display_order }),
      }),
      fetch('/api/settings/grades', {
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
      fetch('/api/settings/grades', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: current.id, display_order: below.display_order }),
      }),
      fetch('/api/settings/grades', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: below.id, display_order: current.display_order }),
      }),
    ]);
    await fetchGrades();
  }

  // --- Section handlers ---
  async function addSection(name: string) {
    await fetch('/api/settings/sections', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name }),
    });
    await fetchSections();
  }

  async function deleteSection(id: string) {
    await fetch('/api/settings/sections', {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id }),
    });
    await fetchSections();
  }

  async function toggleSectionActive(id: string, is_active: boolean) {
    await fetch('/api/settings/sections', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, is_active }),
    });
    await fetchSections();
  }

  async function renameSection(id: string, name: string) {
    await fetch('/api/settings/sections', {
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
      fetch('/api/settings/sections', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: current.id, display_order: above.display_order }),
      }),
      fetch('/api/settings/sections', {
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
      fetch('/api/settings/sections', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: current.id, display_order: below.display_order }),
      }),
      fetch('/api/settings/sections', {
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
        <p className="text-sm text-gray-500">Manage grades and sections for your school.</p>
      </div>

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
    </div>
  );
}
