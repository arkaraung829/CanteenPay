'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import Link from 'next/link';
import { ArrowLeft, Printer } from 'lucide-react';
import QRCode from 'qrcode';
import { supabase } from '@/lib/supabase';

interface StudentCard {
  id: string;
  student_code: string;
  full_name: string;
  class_name: string | null;
  qr_data: string;
  school_name: string;
}

function QRCardCanvas({
  student,
  index,
}: {
  student: StudentCard;
  index: number;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    if (canvasRef.current) {
      QRCode.toCanvas(canvasRef.current, student.qr_data, {
        width: 120,
        margin: 1,
        color: { dark: '#000000', light: '#ffffff' },
      });
    }
  }, [student.qr_data]);

  return (
    <div
      key={`card-${index}`}
      className="border border-gray-300 rounded-lg overflow-hidden flex flex-col items-center justify-between p-3"
      style={{ width: '85.6mm', height: '54mm' }}
    >
      <p className="text-[9px] font-bold text-gray-800 uppercase tracking-wider">
        {student.school_name}
      </p>
      <canvas ref={canvasRef} />
      <div className="text-center">
        <p className="text-[11px] font-semibold text-gray-900 leading-tight">{student.full_name}</p>
        <p className="text-[9px] text-gray-500">{student.class_name || ''}</p>
        <p className="text-[8px] font-mono text-gray-400">{student.student_code}</p>
      </div>
    </div>
  );
}

export default function PrintAllCardsPage() {
  const [students, setStudents] = useState<StudentCard[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchStudents = useCallback(async () => {
    const { data, error } = await supabase
      .from('students')
      .select('id, student_code, full_name, class_name, qr_data, schools(name)')
      .eq('is_active', true)
      .order('full_name');

    if (error) {
      console.error('Error fetching students:', error);
      setLoading(false);
      return;
    }

    const mapped: StudentCard[] = (data || []).map((s: Record<string, unknown>) => {
      const schoolsRaw = s.schools as unknown;
      let schoolName = 'Paynow MM School';
      if (Array.isArray(schoolsRaw) && schoolsRaw.length > 0) {
        schoolName = schoolsRaw[0].name || schoolName;
      } else if (schoolsRaw && typeof schoolsRaw === 'object' && 'name' in schoolsRaw) {
        schoolName = (schoolsRaw as { name: string }).name || schoolName;
      }
      return {
        id: s.id as string,
        student_code: s.student_code as string,
        full_name: s.full_name as string,
        class_name: s.class_name as string | null,
        qr_data: s.qr_data as string,
        school_name: schoolName,
      };
    });

    setStudents(mapped);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchStudents();
  }, [fetchStudents]);

  function handlePrint() {
    window.print();
  }

  if (loading) {
    return (
      <div>
        <div className="mb-6">
          <Link href="/dashboard/students" className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
            <ArrowLeft className="h-4 w-4" /> Back to Students
          </Link>
        </div>
        <p className="text-sm text-gray-500">Loading students...</p>
      </div>
    );
  }

  return (
    <div>
      {/* Header - hidden when printing */}
      <div className="print:hidden mb-6">
        <div className="mb-4">
          <Link href="/dashboard/students" className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
            <ArrowLeft className="h-4 w-4" /> Back to Students
          </Link>
        </div>
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Print QR Cards</h1>
            <p className="mt-1 text-sm text-gray-500">{students.length} active students</p>
          </div>
          <button
            onClick={handlePrint}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Printer className="h-4 w-4" /> Print All Cards
          </button>
        </div>
      </div>

      {/* Cards grid - 4 cards per A4 page (2x2) */}
      <div className="grid grid-cols-2 gap-4 justify-items-center print:gap-2">
        {students.map((student, i) => (
          <QRCardCanvas key={student.id} student={student} index={i} />
        ))}
      </div>

      {/* Print styles */}
      <style jsx global>{`
        @media print {
          @page {
            size: A4;
            margin: 10mm;
          }
          body {
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
          }
        }
      `}</style>
    </div>
  );
}
