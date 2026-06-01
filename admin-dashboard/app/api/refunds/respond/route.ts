import { createAdminClient } from '@/lib/supabase';
import { verifyAdminOrTeacher, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

// PATCH: approve or reject a refund request
export async function PATCH(request: NextRequest) {
  const auth = await verifyAdminOrTeacher(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const body = await request.json();
    const { refund_request_id, action } = body;

    if (!refund_request_id) {
      return Response.json(
        { success: false, error: 'refund_request_id is required' },
        { status: 400 }
      );
    }

    if (!action || !['approve', 'reject'].includes(action)) {
      return Response.json(
        { success: false, error: 'action must be "approve" or "reject"' },
        { status: 400 }
      );
    }

    // Get the refund request
    const { data: refundReq, error: fetchError } = await supabase
      .from('refund_requests')
      .select('*')
      .eq('id', refund_request_id)
      .single();

    if (fetchError || !refundReq) {
      return Response.json(
        { success: false, error: 'Refund request not found' },
        { status: 404 }
      );
    }

    if (refundReq.status !== 'pending') {
      return Response.json(
        { success: false, error: `Refund request already ${refundReq.status}` },
        { status: 400 }
      );
    }

    if (action === 'approve') {
      // Call admin_process_refund RPC with the original transaction_id
      const { data: refundData, error: refundError } = await supabase.rpc(
        'admin_process_refund',
        {
          p_transaction_id: refundReq.transaction_id,
          p_reason: refundReq.reason || 'Seller-approved refund',
        }
      );

      if (refundError) {
        return Response.json(
          { success: false, error: refundError.message },
          { status: 500 }
        );
      }

      // Update refund request status
      const { data: updated, error: updateError } = await supabase
        .from('refund_requests')
        .update({
          status: 'approved',
          responded_by: auth.userId,
          responded_at: new Date().toISOString(),
        })
        .eq('id', refund_request_id)
        .select()
        .single();

      if (updateError) {
        return Response.json(
          { success: false, error: updateError.message },
          { status: 500 }
        );
      }

      return Response.json({
        success: true,
        data: updated,
        refund: refundData,
      });
    } else {
      // Reject
      const { data: updated, error: updateError } = await supabase
        .from('refund_requests')
        .update({
          status: 'rejected',
          responded_by: auth.userId,
          responded_at: new Date().toISOString(),
        })
        .eq('id', refund_request_id)
        .select()
        .single();

      if (updateError) {
        return Response.json(
          { success: false, error: updateError.message },
          { status: 500 }
        );
      }

      return Response.json({ success: true, data: updated });
    }
  } catch (err) {
    return Response.json(
      {
        success: false,
        error: err instanceof Error ? err.message : 'Invalid request',
      },
      { status: 400 }
    );
  }
}
