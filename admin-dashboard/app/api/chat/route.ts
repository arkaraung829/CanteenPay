import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const searchParams = request.nextUrl.searchParams;
  const schoolId = searchParams.get('school_id') || '';
  const conversationId = searchParams.get('conversation_id') || '';
  const action = searchParams.get('action') || '';

  // Fetch parents list for new conversation dropdown
  if (action === 'parents') {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, full_name, phone')
      .eq('role', 'parent')
      .order('full_name');

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }
    return Response.json({ success: true, data: data || [] });
  }

  // If conversation_id provided, return messages
  if (conversationId) {
    const { data, error } = await supabase
      .from('chat_messages')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })
      .limit(200);

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    // Mark unread parent messages as read
    await supabase
      .from('chat_messages')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('conversation_id', conversationId)
      .eq('is_from_school', false)
      .eq('is_read', false);

    return Response.json({ success: true, data: data || [] });
  }

  // Otherwise return conversations with parent + linked students + unread count
  let query = supabase
    .from('chat_conversations')
    .select('*, profiles!chat_conversations_parent_id_fkey(full_name)')
    .order('last_message_at', { ascending: false, nullsFirst: false });

  if (schoolId) {
    query = query.eq('school_id', schoolId);
  }

  const { data, error } = await query;

  if (error) {
    return Response.json({ success: false, error: error.message }, { status: 500 });
  }

  // Fetch linked students for each parent
  const parentIds = [...new Set((data || []).map((c: Record<string, unknown>) => c.parent_id as string))];
  const { data: links } = await supabase
    .from('parent_student_links')
    .select('parent_id, students(id, full_name, student_code, grade, class_name)')
    .in('parent_id', parentIds.length > 0 ? parentIds : ['none']);

  // Build parent -> students map
  const parentStudentsMap: Record<string, Array<{ id: string; full_name: string; student_code: string; grade: string | null; class_name: string | null }>> = {};
  for (const link of (links || [])) {
    const pid = (link as Record<string, unknown>).parent_id as string;
    const student = (link as Record<string, unknown>).students as Record<string, unknown> | null;
    if (student) {
      if (!parentStudentsMap[pid]) parentStudentsMap[pid] = [];
      parentStudentsMap[pid].push({
        id: student.id as string,
        full_name: student.full_name as string,
        student_code: student.student_code as string,
        grade: student.grade as string | null,
        class_name: student.class_name as string | null,
      });
    }
  }

  // Fetch unread counts per conversation (messages from parents that admin hasn't read)
  const convIds = (data || []).map((c: Record<string, unknown>) => c.id as string);
  const { data: unreadData } = await supabase
    .from('chat_messages')
    .select('conversation_id')
    .in('conversation_id', convIds.length > 0 ? convIds : ['none'])
    .eq('is_from_school', false)
    .eq('is_read', false);

  // Count unread per conversation
  const unreadMap: Record<string, number> = {};
  for (const msg of (unreadData || [])) {
    const cid = (msg as Record<string, unknown>).conversation_id as string;
    unreadMap[cid] = (unreadMap[cid] || 0) + 1;
  }

  // Fetch last message preview for each conversation
  const { data: lastMessages } = await supabase
    .from('chat_messages')
    .select('conversation_id, content, is_from_school, created_at')
    .in('conversation_id', convIds.length > 0 ? convIds : ['none'])
    .order('created_at', { ascending: false });

  // Get first (latest) message per conversation
  const lastMessageMap: Record<string, { content: string; is_from_school: boolean }> = {};
  for (const msg of (lastMessages || [])) {
    const cid = (msg as Record<string, unknown>).conversation_id as string;
    if (!lastMessageMap[cid]) {
      lastMessageMap[cid] = {
        content: (msg as Record<string, unknown>).content as string,
        is_from_school: (msg as Record<string, unknown>).is_from_school as boolean,
      };
    }
  }

  // Attach students, unread count, and last message to each conversation
  const enriched = (data || []).map((c: Record<string, unknown>) => ({
    ...c,
    students: parentStudentsMap[c.parent_id as string] || [],
    unread_count: unreadMap[c.id as string] || 0,
    last_message: lastMessageMap[c.id as string] || null,
  }));

  return Response.json({ success: true, data: enriched });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { action } = body;

    // Create a new conversation
    if (action === 'create_conversation') {
      const { school_id, parent_id, subject } = body;

      if (!school_id || !parent_id) {
        return Response.json({ success: false, error: 'school_id and parent_id are required' }, { status: 400 });
      }

      // Check if there's already an active conversation with this parent
      const { data: existing } = await supabase
        .from('chat_conversations')
        .select('id')
        .eq('school_id', school_id)
        .eq('parent_id', parent_id)
        .eq('status', 'open')
        .limit(1);

      if (existing && existing.length > 0) {
        return Response.json({ success: true, data: existing[0], existing: true });
      }

      const { data, error } = await supabase
        .from('chat_conversations')
        .insert({
          school_id,
          parent_id,
          title: subject || 'New Conversation',
          subject: subject || null,
          status: 'open',
          last_message_at: new Date().toISOString(),
        })
        .select('*, profiles!chat_conversations_parent_id_fkey(full_name)')
        .single();

      if (error) {
        return Response.json({ success: false, error: error.message }, { status: 500 });
      }

      return Response.json({ success: true, data });
    }

    // Send a message (default action)
    const { conversation_id, sender_id, content } = body;

    if (!conversation_id || !sender_id || !content) {
      return Response.json({ success: false, error: 'Missing required fields' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('chat_messages')
      .insert({
        conversation_id,
        sender_id,
        content,
        is_from_school: true,
        sender_role: 'admin',
        is_read: true, // Admin's own messages are read by default
      })
      .select()
      .single();

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    // Update last_message_at
    await supabase
      .from('chat_conversations')
      .update({ last_message_at: new Date().toISOString() })
      .eq('id', conversation_id);

    return Response.json({ success: true, data });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
