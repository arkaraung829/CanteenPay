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

  // If conversation_id provided, return messages
  if (conversationId) {
    const { data, error } = await supabase
      .from('chat_messages')
      .select('*')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true })
      .limit(100);

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }
    return Response.json({ success: true, data: data || [] });
  }

  // Otherwise return conversations with parent + linked students
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

  // Build parent → students map
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

  // Attach students to each conversation
  const enriched = (data || []).map((c: Record<string, unknown>) => ({
    ...c,
    students: parentStudentsMap[c.parent_id as string] || [],
  }));

  return Response.json({ success: true, data: enriched });
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
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
