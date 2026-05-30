'use client';

import { authFetch } from '@/lib/auth-fetch';

import { useState, useEffect, useCallback, useRef } from 'react';
import { MessageCircle, Send, Loader2, X, Plus, Search } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useSchoolContext } from '@/lib/school-context';

interface StudentInfo {
  id: string;
  full_name: string;
  student_code: string;
  grade: string | null;
  class_name: string | null;
}

interface LastMessage {
  content: string;
  is_from_school: boolean;
}

interface Conversation {
  id: string;
  parent_id: string;
  title: string;
  subject: string | null;
  status: string;
  last_message_at: string | null;
  created_at: string;
  parent_name?: string;
  students?: StudentInfo[];
  unread_count?: number;
  last_message?: LastMessage | null;
}

interface Message {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  is_from_school: boolean;
  sender_role: string | null;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
}

interface ParentOption {
  id: string;
  full_name: string;
  phone: string | null;
}

export default function ChatPage() {
  const { selectedSchoolId } = useSchoolContext();
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [selectedConv, setSelectedConv] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [msgLoading, setMsgLoading] = useState(false);
  const [newMessage, setNewMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null);

  // New conversation modal state
  const [showNewConv, setShowNewConv] = useState(false);
  const [parents, setParents] = useState<ParentOption[]>([]);
  const [parentsLoading, setParentsLoading] = useState(false);
  const [selectedParentId, setSelectedParentId] = useState('');
  const [newSubject, setNewSubject] = useState('');
  const [creating, setCreating] = useState(false);
  const [parentSearch, setParentSearch] = useState('');

  const totalUnread = conversations.reduce((sum, c) => sum + (c.unread_count || 0), 0);

  const fetchConversations = useCallback(async () => {
    const params = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
    const res = await authFetch(`/api/chat${params}`);
    const json = await res.json();

    if (json.success) {
      const mapped: Conversation[] = (json.data || []).map((c: Record<string, unknown>) => {
        const profile = c.profiles as Record<string, unknown> | null;
        return {
          id: c.id as string,
          parent_id: c.parent_id as string,
          title: c.title as string,
          subject: c.subject as string | null,
          status: c.status as string,
          last_message_at: c.last_message_at as string | null,
          created_at: c.created_at as string,
          parent_name: (profile?.full_name as string) || 'Parent',
          students: (c.students as StudentInfo[]) || [],
          unread_count: (c.unread_count as number) || 0,
          last_message: (c.last_message as LastMessage) || null,
        };
      });
      setConversations(mapped);
    }
    setLoading(false);
  }, [selectedSchoolId]);

  useEffect(() => {
    fetchConversations();
  }, [fetchConversations]);

  // Subscribe to all new messages for real-time unread updates
  useEffect(() => {
    const channel = supabase
      .channel('chat-global-admin')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'chat_messages',
      }, (payload) => {
        const newMsg = payload.new as Message;
        // If this message is for the currently selected conversation, add it
        if (selectedConv && newMsg.conversation_id === selectedConv.id) {
          setMessages(prev => {
            // Avoid duplicates
            if (prev.some(m => m.id === newMsg.id)) return prev;
            return [...prev, newMsg];
          });
          scrollToBottom();
        }
        // Refresh conversation list to update unread counts and previews
        fetchConversations();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedConv?.id]);

  async function selectConversation(conv: Conversation) {
    // Unsubscribe from previous channel
    if (channelRef.current) {
      supabase.removeChannel(channelRef.current);
      channelRef.current = null;
    }

    setSelectedConv(conv);
    setMsgLoading(true);

    const res = await authFetch(`/api/chat?conversation_id=${conv.id}`);
    const json = await res.json();
    setMessages(json.success ? (json.data as Message[]) : []);
    setMsgLoading(false);
    scrollToBottom();

    // Clear unread count for this conversation locally
    setConversations(prev =>
      prev.map(c => c.id === conv.id ? { ...c, unread_count: 0 } : c)
    );
  }

  function scrollToBottom() {
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  }

  async function handleSend() {
    if (!newMessage.trim() || !selectedConv) return;
    setSending(true);

    const userId = (await supabase.auth.getUser()).data.user?.id;

    const res = await authFetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        conversation_id: selectedConv.id,
        sender_id: userId,
        content: newMessage.trim(),
      }),
    });

    const json = await res.json();
    if (json.success) {
      setNewMessage('');
      // Add message locally if not yet added by realtime
      if (json.data) {
        setMessages(prev => {
          if (prev.some(m => m.id === json.data.id)) return prev;
          return [...prev, json.data as Message];
        });
        scrollToBottom();
      }
    }
    setSending(false);
  }

  async function openNewConversation() {
    setShowNewConv(true);
    setParentsLoading(true);
    const res = await authFetch('/api/chat?action=parents');
    const json = await res.json();
    if (json.success) {
      setParents(json.data as ParentOption[]);
    }
    setParentsLoading(false);
  }

  async function handleCreateConversation() {
    if (!selectedParentId || !selectedSchoolId) return;
    setCreating(true);

    const res = await authFetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action: 'create_conversation',
        school_id: selectedSchoolId,
        parent_id: selectedParentId,
        subject: newSubject.trim() || undefined,
      }),
    });

    const json = await res.json();
    if (json.success) {
      setShowNewConv(false);
      setSelectedParentId('');
      setNewSubject('');
      setParentSearch('');
      await fetchConversations();

      // Auto-select the new/existing conversation
      const convId = json.data?.id;
      if (convId) {
        const conv = conversations.find(c => c.id === convId);
        if (conv) {
          selectConversation(conv);
        } else {
          // Fetch fresh and select
          const params = selectedSchoolId ? `?school_id=${selectedSchoolId}` : '';
          const freshRes = await authFetch(`/api/chat${params}`);
          const freshJson = await freshRes.json();
          if (freshJson.success) {
            const found = (freshJson.data as Record<string, unknown>[])?.find(
              (c) => (c.id as string) === convId
            );
            if (found) {
              const profile = found.profiles as Record<string, unknown> | null;
              selectConversation({
                id: found.id as string,
                parent_id: found.parent_id as string,
                title: found.title as string,
                subject: found.subject as string | null,
                status: found.status as string,
                last_message_at: found.last_message_at as string | null,
                created_at: found.created_at as string,
                parent_name: (profile?.full_name as string) || 'Parent',
                students: (found.students as StudentInfo[]) || [],
                unread_count: 0,
                last_message: null,
              });
            }
          }
        }
      }
    }
    setCreating(false);
  }

  const filteredParents = parents.filter(p =>
    p.full_name?.toLowerCase().includes(parentSearch.toLowerCase()) ||
    p.phone?.includes(parentSearch)
  );

  const filteredConversations = conversations.filter(c =>
    !searchQuery ||
    c.parent_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    c.subject?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    c.students?.some(s => s.full_name.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  function formatTime(dateStr: string) {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 1) return 'now';
    if (diffMins < 60) return `${diffMins}m`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h`;
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  function truncate(str: string, len: number) {
    return str.length > len ? str.slice(0, len) + '...' : str;
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
      </div>
    );
  }

  return (
    <div>
      <div className="mb-4">
        <div className="flex items-center gap-3 mb-1">
          <MessageCircle className="h-6 w-6 text-gray-400" />
          <h1 className="text-2xl font-bold text-gray-900">Messages</h1>
          {totalUnread > 0 && (
            <span className="inline-flex items-center justify-center rounded-full bg-red-500 px-2.5 py-0.5 text-xs font-bold text-white">
              {totalUnread}
            </span>
          )}
        </div>
        <p className="text-sm text-gray-500">Chat with parents</p>
      </div>

      <div className="flex gap-4 h-[calc(100vh-200px)]">
        {/* Conversation list */}
        <div className="w-80 shrink-0 rounded-xl border border-gray-200 bg-white overflow-hidden flex flex-col">
          <div className="border-b border-gray-200 px-4 py-3 space-y-2">
            <div className="flex items-center justify-between">
              <p className="text-sm font-semibold text-gray-700">
                {conversations.length} conversation{conversations.length !== 1 ? 's' : ''}
              </p>
              <button
                onClick={openNewConversation}
                className="inline-flex items-center gap-1 rounded-lg bg-blue-600 px-2.5 py-1.5 text-xs font-medium text-white hover:bg-blue-700 transition-colors"
              >
                <Plus className="h-3.5 w-3.5" />
                New
              </button>
            </div>
            <div className="relative">
              <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search conversations..."
                className="w-full rounded-lg border border-gray-200 pl-8 pr-3 py-1.5 text-xs focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
          </div>
          <div className="flex-1 overflow-y-auto divide-y divide-gray-100">
            {filteredConversations.length === 0 ? (
              <div className="px-4 py-8 text-center text-sm text-gray-400">
                {searchQuery ? 'No matching conversations' : 'No conversations yet'}
              </div>
            ) : (
              filteredConversations.map((conv) => (
                <button
                  key={conv.id}
                  onClick={() => selectConversation(conv)}
                  className={`w-full text-left px-4 py-3 hover:bg-gray-50 transition-colors ${
                    selectedConv?.id === conv.id ? 'bg-blue-50' : ''
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div className="relative flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 shrink-0">
                      <span className="text-sm font-bold text-blue-600">
                        {(conv.parent_name || 'P')[0]}
                      </span>
                      {(conv.unread_count || 0) > 0 && (
                        <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[9px] font-bold text-white">
                          {conv.unread_count! > 9 ? '9+' : conv.unread_count}
                        </span>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <p className={`text-sm truncate ${(conv.unread_count || 0) > 0 ? 'font-bold text-gray-900' : 'font-medium text-gray-900'}`}>
                          {conv.parent_name}
                        </p>
                        <span className="text-[10px] text-gray-400 shrink-0 ml-2">
                          {conv.last_message_at ? formatTime(conv.last_message_at) : ''}
                        </span>
                      </div>
                      {conv.students && conv.students.length > 0 && (
                        <p className="text-[11px] text-blue-600 truncate">
                          {conv.students.map(s => s.full_name).join(', ')}
                        </p>
                      )}
                      {conv.last_message ? (
                        <p className={`text-xs truncate mt-0.5 ${(conv.unread_count || 0) > 0 ? 'font-medium text-gray-700' : 'text-gray-400'}`}>
                          {conv.last_message.is_from_school ? 'You: ' : ''}
                          {truncate(conv.last_message.content, 40)}
                        </p>
                      ) : (
                        <p className="text-xs text-gray-400 mt-0.5">No messages yet</p>
                      )}
                    </div>
                  </div>
                </button>
              ))
            )}
          </div>
        </div>

        {/* Chat area */}
        <div className="flex-1 rounded-xl border border-gray-200 bg-white overflow-hidden flex flex-col">
          {!selectedConv ? (
            <div className="flex-1 flex items-center justify-center text-gray-400">
              <div className="text-center">
                <MessageCircle className="mx-auto h-12 w-12 text-gray-300 mb-3" />
                <p className="text-sm">Select a conversation to start messaging</p>
                <button
                  onClick={openNewConversation}
                  className="mt-3 inline-flex items-center gap-1.5 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 transition-colors"
                >
                  <Plus className="h-4 w-4" />
                  Start New Conversation
                </button>
              </div>
            </div>
          ) : (
            <>
              {/* Header */}
              <div className="border-b border-gray-200 px-5 py-3 flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-gray-900">{selectedConv.parent_name}</p>
                  {selectedConv.subject && (
                    <p className="text-xs text-gray-500 mt-0.5">Subject: {selectedConv.subject}</p>
                  )}
                  {selectedConv.students && selectedConv.students.length > 0 && (
                    <div className="flex flex-wrap gap-1 mt-1">
                      {selectedConv.students.map(s => (
                        <span key={s.id} className="inline-flex items-center rounded-full bg-blue-50 px-2 py-0.5 text-[10px] font-medium text-blue-700">
                          {s.full_name} &middot; {s.student_code}
                          {s.grade ? ` \u00b7 G${s.grade}` : ''}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
                <button
                  onClick={() => { setSelectedConv(null); setMessages([]); }}
                  className="rounded p-1 text-gray-400 hover:bg-gray-100"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>

              {/* Messages */}
              <div className="flex-1 overflow-y-auto px-5 py-4 space-y-3">
                {msgLoading ? (
                  <div className="flex justify-center py-8">
                    <Loader2 className="h-5 w-5 animate-spin text-blue-600" />
                  </div>
                ) : messages.length === 0 ? (
                  <p className="text-center text-sm text-gray-400 py-8">No messages yet. Send the first message!</p>
                ) : (
                  messages.map((msg) => (
                    <div
                      key={msg.id}
                      className={`flex ${msg.is_from_school ? 'justify-end' : 'justify-start'}`}
                    >
                      <div
                        className={`max-w-[70%] rounded-2xl px-4 py-2.5 ${
                          msg.is_from_school
                            ? 'bg-blue-600 text-white rounded-br-md'
                            : 'bg-gray-100 text-gray-900 rounded-bl-md'
                        }`}
                      >
                        <p className="text-sm whitespace-pre-wrap">{msg.content}</p>
                        <p className={`text-[10px] mt-1 ${
                          msg.is_from_school ? 'text-blue-200' : 'text-gray-400'
                        }`}>
                          {formatTime(msg.created_at)}
                        </p>
                      </div>
                    </div>
                  ))
                )}
                <div ref={messagesEndRef} />
              </div>

              {/* Input */}
              <div className="border-t border-gray-200 px-4 py-3">
                <form onSubmit={(e) => { e.preventDefault(); handleSend(); }} className="flex gap-2">
                  <input
                    type="text"
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    placeholder="Type a reply..."
                    className="flex-1 rounded-full border border-gray-300 px-4 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) {
                        e.preventDefault();
                        handleSend();
                      }
                    }}
                  />
                  <button
                    type="submit"
                    disabled={sending || !newMessage.trim()}
                    className="rounded-full bg-blue-600 p-2.5 text-white hover:bg-blue-700 disabled:opacity-50 transition-colors"
                  >
                    {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                  </button>
                </form>
              </div>
            </>
          )}
        </div>
      </div>

      {/* New Conversation Modal */}
      {showNewConv && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="w-full max-w-md rounded-xl bg-white shadow-xl">
            <div className="flex items-center justify-between border-b border-gray-200 px-5 py-4">
              <h2 className="text-base font-semibold text-gray-900">New Conversation</h2>
              <button
                onClick={() => { setShowNewConv(false); setSelectedParentId(''); setNewSubject(''); setParentSearch(''); }}
                className="rounded p-1 text-gray-400 hover:bg-gray-100"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <div className="px-5 py-4 space-y-4">
              {/* Parent selection */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Select Parent</label>
                <div className="relative mb-2">
                  <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
                  <input
                    type="text"
                    value={parentSearch}
                    onChange={(e) => setParentSearch(e.target.value)}
                    placeholder="Search parents by name or phone..."
                    className="w-full rounded-lg border border-gray-300 pl-8 pr-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  />
                </div>
                {parentsLoading ? (
                  <div className="flex justify-center py-4">
                    <Loader2 className="h-5 w-5 animate-spin text-blue-600" />
                  </div>
                ) : (
                  <div className="max-h-48 overflow-y-auto rounded-lg border border-gray-200">
                    {filteredParents.length === 0 ? (
                      <p className="px-3 py-4 text-center text-sm text-gray-400">
                        {parentSearch ? 'No matching parents' : 'No parents found'}
                      </p>
                    ) : (
                      filteredParents.map((p) => (
                        <button
                          key={p.id}
                          onClick={() => setSelectedParentId(p.id)}
                          className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-50 border-b border-gray-100 last:border-0 transition-colors ${
                            selectedParentId === p.id ? 'bg-blue-50 text-blue-700' : 'text-gray-700'
                          }`}
                        >
                          <span className="font-medium">{p.full_name}</span>
                          {p.phone && <span className="text-gray-400 ml-2">{p.phone}</span>}
                        </button>
                      ))
                    )}
                  </div>
                )}
              </div>

              {/* Subject */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Subject <span className="text-gray-400 font-normal">(optional)</span>
                </label>
                <input
                  type="text"
                  value={newSubject}
                  onChange={(e) => setNewSubject(e.target.value)}
                  placeholder="e.g. Regarding lunch balance"
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>
            </div>
            <div className="flex justify-end gap-2 border-t border-gray-200 px-5 py-3">
              <button
                onClick={() => { setShowNewConv(false); setSelectedParentId(''); setNewSubject(''); setParentSearch(''); }}
                className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleCreateConversation}
                disabled={!selectedParentId || creating}
                className="inline-flex items-center gap-1.5 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 transition-colors"
              >
                {creating ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
                Start Conversation
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
