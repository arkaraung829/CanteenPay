-- Enhance chat tables with student_id, subject, sender_role, and RLS policies
-- Builds on 023_photo_storage_and_chat.sql

-- Add missing columns to chat_conversations
ALTER TABLE chat_conversations ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES students(id);
ALTER TABLE chat_conversations ADD COLUMN IF NOT EXISTS subject TEXT;

-- Add sender_role to chat_messages (admin or parent)
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS sender_role TEXT CHECK (sender_role IN ('admin', 'parent'));

-- Add is_read boolean for simpler unread tracking
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT false;

-- Better index for messages (conversation + created_at)
CREATE INDEX IF NOT EXISTS idx_chat_msg_conv_created ON chat_messages(conversation_id, created_at);

-- RLS policies for chat_conversations
-- Parents can see their own conversations
CREATE POLICY IF NOT EXISTS conv_parent_select ON chat_conversations
  FOR SELECT USING (parent_id = auth.uid());

CREATE POLICY IF NOT EXISTS conv_parent_insert ON chat_conversations
  FOR INSERT WITH CHECK (parent_id = auth.uid());

-- Admin/staff can manage all conversations for their school
CREATE POLICY IF NOT EXISTS conv_admin_all ON chat_conversations
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'counter_staff')
    )
  );

-- RLS policies for chat_messages
-- Participants can read messages in their conversations
CREATE POLICY IF NOT EXISTS msg_select ON chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chat_conversations c
      WHERE c.id = conversation_id
      AND (
        c.parent_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('admin', 'counter_staff')
        )
      )
    )
  );

-- Sender can insert messages
CREATE POLICY IF NOT EXISTS msg_insert ON chat_messages
  FOR INSERT WITH CHECK (sender_id = auth.uid());

-- Participants can update is_read
CREATE POLICY IF NOT EXISTS msg_update ON chat_messages
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM chat_conversations c
      WHERE c.id = conversation_id
      AND (
        c.parent_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM profiles p
          WHERE p.id = auth.uid()
          AND p.role IN ('admin', 'counter_staff')
        )
      )
    )
  );
