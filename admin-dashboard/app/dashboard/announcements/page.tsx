'use client';

import { authFetch } from '@/lib/auth-fetch';

import { useState, useEffect, useCallback } from 'react';
import {
  Megaphone, Plus, Trash2, Loader2, X, Send, Bell,
} from 'lucide-react';
import { useSchoolContext } from '@/lib/school-context';

interface Announcement {
  id: string;
  title: string;
  title_my?: string;
  body: string;
  body_my?: string;
  target_audience: string[];
  is_published: boolean;
  published_at?: string;
  created_at: string;
  profiles?: { full_name: string };
  schools?: { name: string };
}

const audienceLabels: Record<string, string> = {
  all: 'Everyone',
  parent: 'Parents',
  student: 'Students',
  seller: 'Sellers',
};

const audienceBadgeColors: Record<string, string> = {
  all: 'bg-purple-100 text-purple-700',
  parent: 'bg-blue-100 text-blue-700',
  student: 'bg-green-100 text-green-700',
  seller: 'bg-amber-100 text-amber-700',
};

export default function AnnouncementsPage() {
  const { selectedSchoolId } = useSchoolContext();
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);

  // Form state
  const [title, setTitle] = useState('');
  const [titleMy, setTitleMy] = useState('');
  const [body, setBody] = useState('');
  const [bodyMy, setBodyMy] = useState('');
  const [audience, setAudience] = useState<string[]>(['all']);
  const [sendPush, setSendPush] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [deleteLoading, setDeleteLoading] = useState<string | null>(null);
  const [resendLoading, setResendLoading] = useState<string | null>(null);

  const fetchAnnouncements = useCallback(async () => {
    try {
      const params = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
      const res = await authFetch(`/api/announcements${params}`);
      const json = await res.json();
      if (json.success) setAnnouncements(json.data);
    } catch {
      // silently fail
    }
    setLoading(false);
  }, [selectedSchoolId]);

  useEffect(() => {
    fetchAnnouncements();
  }, [fetchAnnouncements]);

  function toggleAudience(value: string) {
    if (value === 'all') {
      setAudience(['all']);
      return;
    }
    let next = audience.filter(a => a !== 'all');
    if (next.includes(value)) {
      next = next.filter(a => a !== value);
    } else {
      next.push(value);
    }
    if (next.length === 0) next = ['all'];
    setAudience(next);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim() || !body.trim()) return;
    setSubmitting(true);
    setError('');
    setSuccessMsg('');

    try {
      const res = await authFetch('/api/announcements', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: title.trim(),
          title_my: titleMy.trim() || undefined,
          body: body.trim(),
          body_my: bodyMy.trim() || undefined,
          target_audience: audience,
          school_id: selectedSchoolId || undefined,
          send_push: sendPush,
        }),
      });
      const json = await res.json();

      if (!json.success) {
        setError(json.error || 'Failed to create announcement');
      } else {
        const pushInfo = json.push;
        const pushMsg = sendPush && pushInfo
          ? ` Push sent to ${pushInfo.sent || 0} users.`
          : '';
        setSuccessMsg(`Announcement published!${pushMsg}`);
        setTitle('');
        setTitleMy('');
        setBody('');
        setBodyMy('');
        setAudience(['all']);
        setShowForm(false);
        await fetchAnnouncements();
      }
    } catch {
      setError('Network error');
    }
    setSubmitting(false);
  }

  async function handleResend(a: Announcement) {
    if (!confirm(`Re-send push notification for "${a.title}"?`)) return;
    setResendLoading(a.id);
    setSuccessMsg('');
    try {
      const res = await authFetch('/api/announcements', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: a.title,
          title_my: a.title_my,
          body: a.body,
          body_my: a.body_my,
          target_audience: a.target_audience,
          send_push: true,
          resend_only: true,
        }),
      });
      const json = await res.json();
      const pushInfo = json.push;
      setSuccessMsg(`Push re-sent to ${pushInfo?.sent || 0} users.`);
    } catch {
      setSuccessMsg('Failed to re-send.');
    }
    setResendLoading(null);
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this announcement?')) return;
    setDeleteLoading(id);
    try {
      await authFetch('/api/announcements', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      });
    } catch { /* network error */ }
    await fetchAnnouncements();
    setDeleteLoading(null);
  }

  function formatDate(dateStr: string) {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <Megaphone className="h-6 w-6 text-gray-400" />
            <h1 className="text-2xl font-bold text-gray-900">Announcements</h1>
          </div>
          <p className="text-sm text-gray-500">Send announcements and push notifications to parents, students, and sellers.</p>
        </div>
        <button
          onClick={() => { setShowForm(true); setError(''); setSuccessMsg(''); }}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> New Announcement
        </button>
      </div>

      {/* Success message */}
      {successMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-700 flex items-center justify-between">
          {successMsg}
          <button onClick={() => setSuccessMsg('')} className="text-green-500 hover:text-green-700"><X className="h-4 w-4" /></button>
        </div>
      )}

      {/* New Announcement Form */}
      {showForm && (
        <div className="mb-6 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">New Announcement</h2>
            <button onClick={() => setShowForm(false)} className="rounded-lg p-1 text-gray-400 hover:bg-gray-100">
              <X className="h-5 w-5" />
            </button>
          </div>

          {error && (
            <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Title</label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                placeholder="e.g., School Holiday Notice / ကျောင်းပိတ်ရက်"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Message</label>
              <textarea
                required
                rows={4}
                value={body}
                onChange={(e) => setBody(e.target.value)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                placeholder="Write your announcement (English and Myanmar)..."
              />
            </div>

            {/* Target audience */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Target Audience</label>
              <div className="flex flex-wrap gap-2">
                {['all', 'parent', 'student', 'seller'].map((value) => (
                  <button
                    key={value}
                    type="button"
                    onClick={() => toggleAudience(value)}
                    className={`rounded-full px-4 py-1.5 text-sm font-medium border transition-colors ${
                      audience.includes(value)
                        ? 'bg-blue-600 text-white border-blue-600'
                        : 'bg-white text-gray-600 border-gray-300 hover:bg-gray-50'
                    }`}
                  >
                    {audienceLabels[value]}
                  </button>
                ))}
              </div>
            </div>

            {/* Send push toggle */}
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => setSendPush(!sendPush)}
                className="shrink-0"
              >
                <div className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                  sendPush ? 'bg-blue-600' : 'bg-gray-300'
                }`}>
                  <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    sendPush ? 'translate-x-6' : 'translate-x-1'
                  }`} />
                </div>
              </button>
              <div>
                <span className="text-sm font-medium text-gray-700 flex items-center gap-1.5">
                  <Bell className="h-4 w-4" /> Send Push Notification
                </span>
                <p className="text-xs text-gray-500">Immediately notify users on their phones</p>
              </div>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={submitting || !title.trim() || !body.trim()}
                className="flex items-center gap-2 rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
              >
                {submitting ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Send className="h-4 w-4" />
                )}
                {sendPush ? 'Publish & Send' : 'Publish'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Announcements list */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
        </div>
      ) : announcements.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12 text-center">
          <Megaphone className="mx-auto h-12 w-12 text-gray-300" />
          <p className="mt-4 text-sm text-gray-400">No announcements yet</p>
        </div>
      ) : (
        <div className="space-y-4">
          {announcements.map((a) => (
            <div key={a.id} className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              <div className="flex items-start justify-between">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="text-sm font-semibold text-gray-900">{a.title}</h3>
                    {a.target_audience.map((t) => (
                      <span
                        key={t}
                        className={`rounded-full px-2 py-0.5 text-xs font-medium ${audienceBadgeColors[t] || 'bg-gray-100 text-gray-700'}`}
                      >
                        {audienceLabels[t] || t}
                      </span>
                    ))}
                  </div>
                  {a.title_my && (
                    <p className="text-sm text-gray-500 mb-1">{a.title_my}</p>
                  )}
                  <p className="text-sm text-gray-700 whitespace-pre-wrap">{a.body}</p>
                  {a.body_my && (
                    <p className="text-sm text-gray-500 mt-1 whitespace-pre-wrap">{a.body_my}</p>
                  )}
                  <div className="mt-2 flex items-center gap-3 text-xs text-gray-400">
                    <span>{formatDate(a.published_at || a.created_at)}</span>
                    {a.schools?.name && <span>{a.schools.name}</span>}
                    {a.profiles?.full_name && <span>by {a.profiles.full_name}</span>}
                  </div>
                </div>
                <div className="flex items-center gap-1 shrink-0 ml-4">
                  <button
                    onClick={() => handleResend(a)}
                    disabled={resendLoading === a.id}
                    className="rounded p-1.5 text-gray-400 hover:bg-blue-50 hover:text-blue-600 transition-colors"
                    title="Re-send push notification"
                  >
                    {resendLoading === a.id ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Bell className="h-4 w-4" />
                    )}
                  </button>
                  <button
                    onClick={() => handleDelete(a.id)}
                    disabled={deleteLoading === a.id}
                    className="rounded p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                    title="Delete"
                  >
                    {deleteLoading === a.id ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Trash2 className="h-4 w-4" />
                    )}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
