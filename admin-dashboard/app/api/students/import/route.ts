import { createAdminClient } from '@/lib/supabase';
import { verifyAdmin, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest } from 'next/server';

interface CsvRow {
  full_name: string;
  full_name_my?: string;
  grade?: string;
  class_name?: string;
  parent_phone?: string;
}

function parseCsv(text: string): { headers: string[]; rows: Record<string, string>[] } {
  const lines = text.split(/\r?\n/).filter((line) => line.trim() !== '');
  if (lines.length === 0) return { headers: [], rows: [] };

  const headers = lines[0].split(',').map((h) => h.trim().toLowerCase().replace(/\s+/g, '_'));
  const rows: Record<string, string>[] = [];

  for (let i = 1; i < lines.length; i++) {
    const values = lines[i].split(',').map((v) => v.trim());
    const row: Record<string, string> = {};
    headers.forEach((h, idx) => {
      row[h] = values[idx] || '';
    });
    rows.push(row);
  }

  return { headers, rows };
}

function validateRow(row: Record<string, string>, index: number): { valid: boolean; error?: string; data?: CsvRow } {
  const fullName = row['full_name'] || row['name'] || '';
  if (!fullName) {
    return { valid: false, error: `Row ${index + 1}: Missing required field 'full_name'` };
  }

  return {
    valid: true,
    data: {
      full_name: fullName,
      full_name_my: row['full_name_my'] || row['name_my'] || undefined,
      grade: row['grade'] || undefined,
      class_name: row['class_name'] || row['class'] || undefined,
      parent_phone: row['parent_phone'] || row['phone'] || undefined,
    },
  };
}

export async function POST(request: NextRequest) {
  const auth = await verifyAdmin(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();

  try {
    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    const previewOnly = formData.get('preview') === 'true';

    if (!file) {
      return Response.json({ success: false, error: 'No file uploaded' }, { status: 400 });
    }

    const text = await file.text();
    const { rows } = parseCsv(text);

    if (rows.length === 0) {
      return Response.json({ success: false, error: 'CSV file is empty or has no data rows' }, { status: 400 });
    }

    // Validate all rows
    const validated = rows.map((row, idx) => validateRow(row, idx));
    const errors = validated.filter((v) => !v.valid).map((v) => v.error!);
    const validRows = validated.filter((v) => v.valid).map((v) => v.data!);

    // If preview, return parsed data without importing
    if (previewOnly) {
      return Response.json({
        success: true,
        preview: true,
        data: validRows,
        errors,
        stats: {
          total: rows.length,
          valid: validRows.length,
          invalid: errors.length,
        },
      });
    }

    // Get school_id
    const { data: schools } = await supabase.from('schools').select('id').limit(1);
    const schoolId = schools?.[0]?.id;

    if (!schoolId) {
      return Response.json({ success: false, error: 'No school found. Please create a school first.' }, { status: 400 });
    }

    // Get current student count for code generation
    const { count: currentCount } = await supabase
      .from('students')
      .select('id', { count: 'exact', head: true });

    let imported = 0;
    const skipped: { row: number; reason: string }[] = [];

    for (let i = 0; i < validRows.length; i++) {
      const row = validRows[i];
      const studentCode = `STU-${new Date().getFullYear()}-${String((currentCount || 0) + imported + 1).padStart(3, '0')}`;

      const { error } = await supabase.from('students').insert({
        full_name: row.full_name,
        full_name_my: row.full_name_my || null,
        grade: row.grade || null,
        class_name: row.class_name || null,
        student_code: studentCode,
        qr_data: crypto.randomUUID(),
        school_id: schoolId,
        is_active: true,
      });

      if (error) {
        skipped.push({ row: i + 1, reason: error.message });
      } else {
        imported++;
      }
    }

    return Response.json({
      success: true,
      preview: false,
      stats: {
        total: rows.length,
        imported,
        skipped: skipped.length,
        invalid: errors.length,
      },
      skipped,
      errors,
    });
  } catch (err) {
    return Response.json(
      { success: false, error: err instanceof Error ? err.message : 'Invalid request' },
      { status: 400 }
    );
  }
}
