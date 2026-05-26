'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import { ArrowLeft, Printer } from 'lucide-react';
import QRCode from 'qrcode';
import { formatMMK } from '@/lib/types';
import { supabase } from '@/lib/supabase';

interface StudentDetail {
  id: string;
  student_code: string;
  full_name: string;
  full_name_my: string | null;
  class_name: string | null;
  grade: string | null;
  is_active: boolean;
  qr_data: string;
  balance: number;
  school_name: string;
}

export default function StudentDetailPage() {
  const params = useParams();
  const id = params.id as string;

  const [student, setStudent] = useState<StudentDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const qrCanvasRef = useRef<HTMLCanvasElement>(null);
  const printQrCanvasRef = useRef<HTMLCanvasElement>(null);

  const generateQR = useCallback(async (qrData: string) => {
    if (qrCanvasRef.current) {
      await QRCode.toCanvas(qrCanvasRef.current, qrData, {
        width: 200,
        margin: 2,
        color: { dark: '#000000', light: '#ffffff' },
      });
    }
    if (printQrCanvasRef.current) {
      await QRCode.toCanvas(printQrCanvasRef.current, qrData, {
        width: 160,
        margin: 1,
        color: { dark: '#000000', light: '#ffffff' },
      });
    }
  }, []);

  useEffect(() => {
    async function fetchStudent() {
      const { data, error } = await supabase
        .from('students')
        .select('id, student_code, full_name, full_name_my, class_name, grade, is_active, qr_data, wallets(balance), schools(name)')
        .eq('id', id)
        .single();

      if (error || !data) {
        console.error('Error fetching student:', error);
        setLoading(false);
        return;
      }

      const wallets = data.wallets as Array<{ balance: number }> | { balance: number } | null;
      let balance = 0;
      if (Array.isArray(wallets) && wallets.length > 0) {
        balance = wallets[0].balance || 0;
      } else if (wallets && !Array.isArray(wallets)) {
        balance = wallets.balance || 0;
      }

      const schoolsRaw = data.schools as unknown;
      let schoolName = 'CanteenPay School';
      if (Array.isArray(schoolsRaw) && schoolsRaw.length > 0) {
        schoolName = schoolsRaw[0].name || schoolName;
      } else if (schoolsRaw && typeof schoolsRaw === 'object' && 'name' in schoolsRaw) {
        schoolName = (schoolsRaw as { name: string }).name || schoolName;
      }

      const s: StudentDetail = {
        id: data.id as string,
        student_code: data.student_code as string,
        full_name: data.full_name as string,
        full_name_my: data.full_name_my as string | null,
        class_name: data.class_name as string | null,
        grade: data.grade as string | null,
        is_active: data.is_active as boolean,
        qr_data: data.qr_data as string,
        balance,
        school_name: schoolName,
      };

      setStudent(s);
      setLoading(false);
    }

    fetchStudent();
  }, [id]);

  useEffect(() => {
    if (student?.qr_data) {
      generateQR(student.qr_data);
    }
  }, [student, generateQR]);

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
        <div className="space-y-4">
          {[1, 2, 3].map(i => (
            <div key={i} className="h-20 animate-pulse rounded-lg bg-gray-100" />
          ))}
        </div>
      </div>
    );
  }

  if (!student) {
    return (
      <div>
        <div className="mb-6">
          <Link href="/dashboard/students" className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
            <ArrowLeft className="h-4 w-4" /> Back to Students
          </Link>
        </div>
        <p className="text-gray-500">Student not found.</p>
      </div>
    );
  }

  return (
    <div>
      {/* Screen view */}
      <div className="print:hidden">
        <div className="mb-6">
          <Link href="/dashboard/students" className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1">
            <ArrowLeft className="h-4 w-4" /> Back to Students
          </Link>
        </div>

        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{student.full_name}</h1>
            {student.full_name_my && (
              <p className="text-sm text-gray-500">{student.full_name_my}</p>
            )}
          </div>
          <button
            onClick={handlePrint}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            <Printer className="h-4 w-4" /> Print Card
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Student Info */}
          <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Student Information</h2>
            <dl className="space-y-3">
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Student Code</dt>
                <dd className="text-sm font-mono font-medium text-gray-900">{student.student_code}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Class</dt>
                <dd className="text-sm text-gray-900">{student.class_name || '-'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Grade</dt>
                <dd className="text-sm text-gray-900">{student.grade ? `Grade ${student.grade}` : '-'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Balance</dt>
                <dd className={`text-sm font-medium ${student.balance < 1000 ? 'text-red-600' : 'text-gray-900'}`}>
                  {formatMMK(student.balance)}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Status</dt>
                <dd>
                  <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
                    student.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                  }`}>
                    {student.is_active ? 'Active' : 'Inactive'}
                  </span>
                </dd>
              </div>
            </dl>
          </div>

          {/* QR Code */}
          <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm flex flex-col items-center">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">QR Code</h2>
            <canvas ref={qrCanvasRef} />
            <p className="mt-3 text-xs text-gray-400 font-mono break-all text-center max-w-[220px]">
              {student.qr_data}
            </p>
          </div>
        </div>
      </div>

      {/* Print view - credit card size: 85.6mm x 54mm */}
      <div className="hidden print:flex print:items-center print:justify-center print:min-h-screen">
        <div
          className="border border-gray-300 rounded-lg overflow-hidden flex flex-col items-center justify-between p-4"
          style={{ width: '85.6mm', height: '54mm' }}
        >
          <p className="text-xs font-bold text-gray-800 uppercase tracking-wider">
            {student.school_name}
          </p>
          <div className="flex flex-col items-center">
            <canvas ref={printQrCanvasRef} />
          </div>
          <div className="text-center">
            <p className="text-sm font-semibold text-gray-900">{student.full_name}</p>
            <p className="text-xs text-gray-500">{student.class_name || ''}</p>
            <p className="text-xs font-mono text-gray-400">{student.student_code}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
