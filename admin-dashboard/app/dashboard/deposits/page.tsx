'use client';

import DepositForm from '@/components/DepositForm';
import { useSchoolContext } from '@/lib/school-context';

export default function DepositsPage() {
  const { selectedSchoolId } = useSchoolContext();

  return (
    <div>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Counter Deposit</h1>
        <p className="mt-1 text-sm text-gray-500">Credit student accounts from cash deposits</p>
      </div>
      <DepositForm schoolId={selectedSchoolId} />
    </div>
  );
}
