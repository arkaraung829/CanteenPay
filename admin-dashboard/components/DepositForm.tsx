'use client';

import { useState } from 'react';
import { Search, Banknote, CheckCircle } from 'lucide-react';
import { formatMMK, type Student } from '@/lib/types';

// Demo students for prototype
const DEMO_STUDENTS: Student[] = [
  { id: '1', school_id: 's1', student_code: 'STU-2024-001', qr_data: 'qr1', full_name: 'Aung Kyaw Zin', class_name: 'Grade 5-A', grade: '5', is_active: true, created_at: '', wallet: { id: 'w1', student_id: '1', balance: 15000, currency: 'MMK', is_frozen: false, updated_at: '' } },
  { id: '2', school_id: 's1', student_code: 'STU-2024-002', qr_data: 'qr2', full_name: 'Thin Thin Aye', class_name: 'Grade 4-B', grade: '4', is_active: true, created_at: '', wallet: { id: 'w2', student_id: '2', balance: 8500, currency: 'MMK', is_frozen: false, updated_at: '' } },
  { id: '3', school_id: 's1', student_code: 'STU-2024-003', qr_data: 'qr3', full_name: 'Min Thant Zaw', class_name: 'Grade 6-A', grade: '6', is_active: true, created_at: '', wallet: { id: 'w3', student_id: '3', balance: 3200, currency: 'MMK', is_frozen: false, updated_at: '' } },
];

const QUICK_AMOUNTS = [2000, 5000, 10000, 20000, 50000];

export default function DepositForm() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStudent, setSelectedStudent] = useState<Student | null>(null);
  const [amount, setAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState<'cash' | 'transfer'>('cash');
  const [note, setNote] = useState('');
  const [showSuccess, setShowSuccess] = useState(false);
  const [receipt, setReceipt] = useState<{ ref: string; newBalance: number } | null>(null);

  const filteredStudents = searchQuery.length > 0
    ? DEMO_STUDENTS.filter(s =>
        s.full_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        s.student_code.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : [];

  function handleDeposit() {
    if (!selectedStudent || !amount) return;
    const depositAmount = parseInt(amount);
    const currentBalance = selectedStudent.wallet?.balance || 0;
    const newBalance = currentBalance + depositAmount;
    const ref = `RC-${Math.random().toString(36).substring(2, 7).toUpperCase()}`;
    setReceipt({ ref, newBalance });
    setShowSuccess(true);
  }

  function handleReset() {
    setSelectedStudent(null);
    setAmount('');
    setNote('');
    setShowSuccess(false);
    setReceipt(null);
    setSearchQuery('');
  }

  if (showSuccess && receipt && selectedStudent) {
    return (
      <div className="mx-auto max-w-md text-center">
        <div className="rounded-2xl border border-green-200 bg-green-50 p-8">
          <CheckCircle className="mx-auto h-16 w-16 text-green-500" />
          <h2 className="mt-4 text-xl font-bold text-gray-900">Deposit Successful</h2>
          <p className="mt-1 text-sm text-gray-500">Reference: {receipt.ref}</p>

          <div className="mt-6 space-y-3 text-left">
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">Student</span>
              <span className="font-medium text-gray-900">{selectedStudent.full_name}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">Class</span>
              <span className="font-medium text-gray-900">{selectedStudent.class_name}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">Amount Deposited</span>
              <span className="font-bold text-green-600">{formatMMK(parseInt(amount))}</span>
            </div>
            <div className="border-t pt-3 flex justify-between text-sm">
              <span className="text-gray-500">New Balance</span>
              <span className="font-bold text-gray-900">{formatMMK(receipt.newBalance)}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">Payment</span>
              <span className="font-medium text-gray-900 capitalize">{paymentMethod}</span>
            </div>
          </div>

          <div className="mt-6 flex gap-3">
            <button
              onClick={handleReset}
              className="flex-1 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700"
            >
              New Deposit
            </button>
          </div>

          <p className="mt-4 text-xs text-gray-400">
            Parent notification sent
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      {/* Step 1: Find Student */}
      <div className="rounded-xl border border-gray-200 bg-white p-6">
        <h3 className="text-sm font-semibold text-gray-900 mb-4">1. Find Student</h3>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => { setSearchQuery(e.target.value); setSelectedStudent(null); }}
            placeholder="Search by name or student ID..."
            className="w-full rounded-lg border border-gray-300 py-2.5 pl-10 pr-4 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>

        {filteredStudents.length > 0 && !selectedStudent && (
          <div className="mt-3 divide-y divide-gray-100 rounded-lg border border-gray-200">
            {filteredStudents.map((student) => (
              <button
                key={student.id}
                onClick={() => { setSelectedStudent(student); setSearchQuery(student.full_name); }}
                className="flex w-full items-center justify-between px-4 py-3 text-left hover:bg-gray-50"
              >
                <div>
                  <p className="text-sm font-medium text-gray-900">{student.full_name}</p>
                  <p className="text-xs text-gray-500">{student.student_code} &middot; {student.class_name}</p>
                </div>
                <span className="text-sm font-medium text-gray-600">
                  {formatMMK(student.wallet?.balance || 0)}
                </span>
              </button>
            ))}
          </div>
        )}

        {selectedStudent && (
          <div className="mt-3 flex items-center gap-4 rounded-lg border border-blue-200 bg-blue-50 px-4 py-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-blue-600 text-sm font-bold text-white">
              {selectedStudent.full_name.charAt(0)}
            </div>
            <div className="flex-1">
              <p className="text-sm font-semibold text-gray-900">{selectedStudent.full_name}</p>
              <p className="text-xs text-gray-500">{selectedStudent.student_code} &middot; {selectedStudent.class_name}</p>
            </div>
            <div className="text-right">
              <p className="text-xs text-gray-500">Current Balance</p>
              <p className="text-sm font-bold text-gray-900">{formatMMK(selectedStudent.wallet?.balance || 0)}</p>
            </div>
          </div>
        )}
      </div>

      {/* Step 2: Deposit Amount */}
      {selectedStudent && (
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <h3 className="text-sm font-semibold text-gray-900 mb-4">2. Deposit Amount</h3>

          <div className="relative">
            <Banknote className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="Enter amount in MMK"
              className="w-full rounded-lg border border-gray-300 py-2.5 pl-10 pr-4 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            />
          </div>

          <div className="mt-3 flex flex-wrap gap-2">
            {QUICK_AMOUNTS.map((qa) => (
              <button
                key={qa}
                onClick={() => setAmount(qa.toString())}
                className={`rounded-lg border px-4 py-2 text-sm font-medium transition-colors ${
                  amount === qa.toString()
                    ? 'border-blue-500 bg-blue-50 text-blue-700'
                    : 'border-gray-200 text-gray-600 hover:bg-gray-50'
                }`}
              >
                {formatMMK(qa)}
              </button>
            ))}
          </div>

          {/* Payment Method */}
          <div className="mt-4">
            <p className="mb-2 text-xs font-medium text-gray-500 uppercase">Payment Method</p>
            <div className="flex gap-2">
              {(['cash', 'transfer'] as const).map((method) => (
                <button
                  key={method}
                  onClick={() => setPaymentMethod(method)}
                  className={`rounded-lg border px-4 py-2 text-sm font-medium capitalize transition-colors ${
                    paymentMethod === method
                      ? 'border-blue-500 bg-blue-50 text-blue-700'
                      : 'border-gray-200 text-gray-600 hover:bg-gray-50'
                  }`}
                >
                  {method}
                </button>
              ))}
            </div>
          </div>

          {/* Note */}
          <div className="mt-4">
            <input
              type="text"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Optional note..."
              className="w-full rounded-lg border border-gray-300 py-2 px-3 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            />
          </div>
        </div>
      )}

      {/* Step 3: Confirm */}
      {selectedStudent && amount && parseInt(amount) > 0 && (
        <div className="rounded-xl border border-gray-200 bg-white p-6">
          <h3 className="text-sm font-semibold text-gray-900 mb-4">3. Confirm Deposit</h3>
          <div className="rounded-lg bg-gray-50 p-4 space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">Student</span>
              <span className="font-medium">{selectedStudent.full_name}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-500">Deposit Amount</span>
              <span className="font-bold text-green-600">+ {formatMMK(parseInt(amount))}</span>
            </div>
            <div className="flex justify-between text-sm border-t pt-2">
              <span className="text-gray-500">New Balance</span>
              <span className="font-bold text-gray-900">
                {formatMMK((selectedStudent.wallet?.balance || 0) + parseInt(amount))}
              </span>
            </div>
          </div>
          <button
            onClick={handleDeposit}
            className="mt-4 w-full rounded-lg bg-green-600 px-4 py-3 text-sm font-semibold text-white shadow-sm hover:bg-green-700"
          >
            Confirm Deposit
          </button>
        </div>
      )}
    </div>
  );
}
