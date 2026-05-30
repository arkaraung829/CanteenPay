import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
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

  // Otherwise return conversations
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

  return Response.json({ success: true, data: data || [] });
}

export async function POST(request: NextRequest) {
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
