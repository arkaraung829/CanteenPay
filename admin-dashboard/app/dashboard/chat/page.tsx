'use client';

import { useState, useEffect, useCallback, useRef } from 'react';
import { MessageCircle, Send, Loader2, X } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { createAdminClient } from '@/lib/supabase';
import { useSchoolContext } from '@/lib/school-context';

interface Conversation {
  id: string;
  parent_id: string;
  title: string;
  status: string;
  last_message_at: string | null;
  created_at: string;
  parent_name?: string;
  unread_count?: number;
}

interface Message {
  id: string;
  sender_id: string;
  content: string;
  is_from_school: boolean;
  read_at: string | null;
  created_at: string;
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
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const fetchConversations = useCallback(async () => {
    let query = supabase
      .from('chat_conversations')
      .select('*, profiles!chat_conversations_parent_id_fkey(full_name)')
      .order('last_message_at', { ascending: false, nullsFirst: false });

    if (selectedSchoolId) {
      query = query.eq('school_id', selectedSchoolId);
    }

    const { data } = await query;

    const mapped: Conversation[] = (data || []).map((c: Record<string, unknown>) => {
      const profile = c.profiles as Record<string, unknown> | null;
      return {
        id: c.id as string,
        parent_id: c.parent_id as string,
        title: c.title as string,
        status: c.status as string,
        last_message_at: c.last_message_at as string | null,
        created_at: c.created_at as string,
        parent_name: (profile?.full_name as string) || 'Parent',
      };
    });

    setConversations(mapped);
    setLoading(false);
  }, [selectedSchoolId]);

  useEffect(() => {
    fetchConversations();
  }, [fetchConversations]);

  async function selectConversation(conv: Conversation) {
    setSelectedConv(conv);
    setMsgLoading(true);

    const { data } = await supabase
      .from('chat_messages')
      .select('*')
      .eq('conversation_id', conv.id)
      .order('created_at', { ascending: true })
      .limit(100);

    setMessages((data || []) as Message[]);
    setMsgLoading(false);
    scrollToBottom();

    // Subscribe to new messages
    supabase
      .channel(`chat-admin-${conv.id}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'chat_messages',
        filter: `conversation_id=eq.${conv.id}`,
      }, (payload) => {
        setMessages(prev => [...prev, payload.new as Message]);
        scrollToBottom();
      })
      .subscribe();
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

    const { error } = await supabase.from('chat_messages').insert({
      conversation_id: selectedConv.id,
      sender_id: userId,
      content: newMessage.trim(),
      is_from_school: true,
    });

    if (!error) {
      setNewMessage('');
      await supabase
        .from('chat_conversations')
        .update({ last_message_at: new Date().toISOString() })
        .eq('id', selectedConv.id);
    }

    setSending(false);
  }

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
        </div>
        <p className="text-sm text-gray-500">Chat with parents</p>
      </div>

      <div className="flex gap-4 h-[calc(100vh-200px)]">
        {/* Conversation list */}
        <div className="w-80 shrink-0 rounded-xl border border-gray-200 bg-white overflow-hidden flex flex-col">
          <div className="border-b border-gray-200 px-4 py-3">
            <p className="text-sm font-semibold text-gray-700">{conversations.length} conversations</p>
          </div>
          <div className="flex-1 overflow-y-auto divide-y divide-gray-100">
            {conversations.length === 0 ? (
              <div className="px-4 py-8 text-center text-sm text-gray-400">No conversations yet</div>
            ) : (
              conversations.map((conv) => (
                <button
                  key={conv.id}
                  onClick={() => selectConversation(conv)}
                  className={`w-full text-left px-4 py-3 hover:bg-gray-50 transition-colors ${
                    selectedConv?.id === conv.id ? 'bg-blue-50' : ''
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-100 shrink-0">
                      <span className="text-sm font-bold text-blue-600">
                        {(conv.parent_name || 'P')[0]}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 truncate">{conv.parent_name}</p>
                      <p className="text-xs text-gray-400">
                        {conv.last_message_at ? formatTime(conv.last_message_at) : 'No messages'}
                      </p>
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
                <p className="text-sm">Select a conversation</p>
              </div>
            </div>
          ) : (
            <>
              {/* Header */}
              <div className="border-b border-gray-200 px-5 py-3 flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-gray-900">{selectedConv.parent_name}</p>
                  <p className="text-xs text-gray-400">{selectedConv.status}</p>
                </div>
                <button
                  onClick={() => { setSelectedConv(null); setMessages([]); }}
                  className="rounded p-1 text-gray-400 hover:bg-gray-100 lg:hidden"
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
                  <p className="text-center text-sm text-gray-400 py-8">No messages yet</p>
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
                        <p className="text-sm">{msg.content}</p>
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
                  />
                  <button
                    type="submit"
                    disabled={sending || !newMessage.trim()}
                    className="rounded-full bg-blue-600 p-2.5 text-white hover:bg-blue-700 disabled:opacity-50"
                  >
                    {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                  </button>
                </form>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
