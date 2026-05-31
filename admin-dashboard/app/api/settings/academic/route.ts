import { createAdminClient } from '@/lib/supabase';
import { verifyAdminOrTeacher, unauthorizedResponse } from '@/lib/api-auth';
import { NextRequest, NextResponse } from 'next/server';

/**
 * Compute the current academic year based on the academic_year_start month.
 * E.g. if school starts in June (6) and today is July 2025 => "2025-2026"
 *      if today is March 2026 => "2025-2026"
 */
function computeCurrentAcademicYear(startMonth: number): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1; // 1-based
  if (month >= startMonth) {
    return `${year}-${year + 1}`;
  }
  return `${year - 1}-${year}`;
}

/**
 * Generate a list of recent academic years: previous, current, next.
 */
function generateAcademicYears(currentAcademicYear: string): string[] {
  const parts = currentAcademicYear.split('-');
  const startYear = parseInt(parts[0], 10);
  return [
    `${startYear - 1}-${startYear}`,
    `${startYear}-${startYear + 1}`,
    `${startYear + 1}-${startYear + 2}`,
  ];
}

export async function GET(request: NextRequest) {
  const auth = await verifyAdminOrTeacher(request);
  if (!auth) return unauthorizedResponse();

  const supabase = createAdminClient();
  const schoolId = request.nextUrl.searchParams.get('school_id');

  // Default start month: June (Myanmar academic year)
  let academicYearStart = 6;
  let academicYearEnd = 5;
  let settingsAcademicYear: string | null = null;
  let settingsTerm: string | null = null;

  // Try to load school settings if school_id provided
  if (schoolId) {
    const { data: school } = await supabase
      .from('schools')
      .select('settings')
      .eq('id', schoolId)
      .single();

    if (school?.settings) {
      const settings = school.settings as Record<string, unknown>;
      if (typeof settings.academic_year_start === 'number') {
        academicYearStart = settings.academic_year_start;
      }
      if (typeof settings.academic_year_end === 'number') {
        academicYearEnd = settings.academic_year_end;
      }
      if (typeof settings.academic_year === 'string') {
        settingsAcademicYear = settings.academic_year;
      }
      if (typeof settings.term === 'string') {
        settingsTerm = settings.term;
      }
    }
  }

  // Compute current academic year from start month
  const currentAcademicYear = settingsAcademicYear || computeCurrentAcademicYear(academicYearStart);
  const academicYears = generateAcademicYears(currentAcademicYear);

  // Fetch distinct terms from exam_types
  let termsQuery = supabase
    .from('exam_types')
    .select('term')
    .eq('is_active', true)
    .not('term', 'is', null);

  if (schoolId) {
    termsQuery = termsQuery.eq('school_id', schoolId);
  }

  const { data: examData } = await termsQuery;
  const distinctTerms = [...new Set(
    (examData || [])
      .map((e: { term: string | null }) => e.term)
      .filter((t): t is string => !!t)
  )];

  return NextResponse.json({
    success: true,
    data: {
      academic_year: currentAcademicYear,
      term: settingsTerm || (distinctTerms.length > 0 ? distinctTerms[0] : null),
      academic_year_start: academicYearStart,
      academic_year_end: academicYearEnd,
      academic_years: academicYears,
      terms: distinctTerms,
    },
  });
}
