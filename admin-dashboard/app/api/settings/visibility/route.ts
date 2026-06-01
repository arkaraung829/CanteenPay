import { createAdminClient } from '@/lib/supabase';
import { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const supabase = createAdminClient();
  const schoolId = request.nextUrl.searchParams.get('school_id');
  const grade = request.nextUrl.searchParams.get('grade');

  if (!schoolId) {
    return Response.json({ success: false, error: 'school_id is required' }, { status: 400 });
  }

  try {
    const { data, error } = await supabase
      .from('schools')
      .select('settings')
      .eq('id', schoolId)
      .single();

    if (error) {
      return Response.json({ success: false, error: error.message }, { status: 500 });
    }

    const settings = (data?.settings as Record<string, unknown>) ?? {};
    const visibility = (settings.parent_visibility as Record<string, Record<string, boolean>>) ?? {};

    // Look up grade-specific settings, fall back to default, fall back to all-true
    const allTrue = { report_cards: true, attendance: true, spending: true };
    const defaultVis = visibility.default ?? allTrue;
    const gradeVis = grade && visibility[grade] ? visibility[grade] : defaultVis;

    return Response.json({
      success: true,
      data: {
        report_cards: gradeVis.report_cards ?? true,
        attendance: gradeVis.attendance ?? true,
        spending: gradeVis.spending ?? true,
      },
    });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Internal error' },
      { status: 500 }
    );
  }
}
