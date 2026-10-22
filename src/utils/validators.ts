import { ClassGroup, BeltRank } from '../types';

/**
 * Checks if two time windows on matching days overlap.
 * Time format: "HH:mm" (24h)
 */
export function doClassTimesOverlap(
  daysA: number[],
  startA: string,
  endA: string,
  daysB: number[],
  startB: string,
  endB: string
): boolean {
  // Check if they share at least one day
  const commonDays = daysA.filter(d => daysB.includes(d));
  if (commonDays.length === 0) return false;

  // Convert "HH:mm" to minutes from midnight
  const parseMin = (t: string) => {
    const [h, m] = t.split(':').map(Number);
    return (h || 0) * 60 + (m || 0);
  };

  const aStart = parseMin(startA);
  const aEnd = parseMin(endA);
  const bStart = parseMin(startB);
  const bEnd = parseMin(endB);

  // Overlap condition: startA < endB AND startB < endA
  return aStart < bEnd && bStart < aEnd;
}

/**
 * Validate if an enrollment in a new class group would cause a time conflict
 * with existing enrolled classes of that student.
 */
export function checkEnrollmentConflict(
  newClass: ClassGroup,
  existingClasses: ClassGroup[]
): { hasConflict: boolean; conflictingClass?: ClassGroup } {
  for (const existing of existingClasses) {
    if (existing.id === newClass.id) continue;
    if (
      doClassTimesOverlap(
        newClass.daysOfWeek,
        newClass.startTime,
        newClass.endTime,
        existing.daysOfWeek,
        existing.startTime,
        existing.endTime
      )
    ) {
      return { hasConflict: true, conflictingClass: existing };
    }
  }
  return { hasConflict: false };
}

/**
 * Check eligibility for a student targeting a higher belt rank
 */
export interface EligibilityResult {
  isEligible: boolean;
  reasons: string[];
  metrics: {
    studentAge: number;
    requiredMinAge: number;
    monthsInCurrentRank: number;
    requiredMinMonths: number;
    attendanceRatePercent: number;
    requiredMinAttendance: number;
  };
}

export function evaluateBeltExamEligibility(
  studentAge: number,
  graduatedAtStr: string,
  targetBelt: BeltRank,
  attendancePercentage: number,
  minRequiredAttendance = 75
): EligibilityResult {
  const reasons: string[] = [];

  // 1. Minimum Age
  const requiredMinAge = targetBelt.minAgeYears || 0;
  if (studentAge < requiredMinAge) {
    reasons.push(`Idade atual (${studentAge} anos) é menor que a idade mínima exigida (${requiredMinAge} anos)`);
  }

  // 2. Minimum Time in Current Rank (carência)
  let monthsInCurrentRank = 0;
  if (graduatedAtStr) {
    const gradDate = new Date(graduatedAtStr + 'T12:00:00');
    const now = new Date();
    monthsInCurrentRank = Math.max(
      0,
      (now.getFullYear() - gradDate.getFullYear()) * 12 + (now.getMonth() - gradDate.getMonth())
    );
  }

  const requiredMinMonths = targetBelt.minPracticeMonths || 0;
  if (monthsInCurrentRank < requiredMinMonths) {
    reasons.push(
      `Tempo na graduação atual (${monthsInCurrentRank} meses) é inferior ao tempo de permanência exigido (${requiredMinMonths} meses)`
    );
  }

  // 3. Minimum Attendance Rate
  if (attendancePercentage < minRequiredAttendance) {
    reasons.push(
      `Frequência no período (${attendancePercentage}%) está abaixo do mínimo exigido (${minRequiredAttendance}%)`
    );
  }

  return {
    isEligible: reasons.length === 0,
    reasons,
    metrics: {
      studentAge,
      requiredMinAge,
      monthsInCurrentRank,
      requiredMinMonths,
      attendanceRatePercent: attendancePercentage,
      requiredMinAttendance: minRequiredAttendance,
    },
  };
}

/**
 * Calculates monthly billing amount applying strictly non-duplicate promotional discounts
 */
export function calculateStudentMonthlyTuition(
  baseFee: number,
  isSecondModality: boolean,
  multiArtDiscountPercent: number,
  isSecondFamilyMember: boolean,
  familyDiscountPercent: number
): { finalAmount: number; discountAmount: number; appliedDiscounts: string[] } {
  let discountAmount = 0;
  const appliedDiscounts: string[] = [];

  // Highest priority discount is applied first, avoiding compounding duplication
  if (isSecondFamilyMember && familyDiscountPercent > 0) {
    const discount = (baseFee * familyDiscountPercent) / 100;
    discountAmount += discount;
    appliedDiscounts.push(`Desconto Familiar (-${familyDiscountPercent}%)`);
  } else if (isSecondModality && multiArtDiscountPercent > 0) {
    const discount = (baseFee * multiArtDiscountPercent) / 100;
    discountAmount += discount;
    appliedDiscounts.push(`Desconto 2ª Modalidade (-${multiArtDiscountPercent}%)`);
  }

  const finalAmount = Math.max(0, baseFee - discountAmount);
  return {
    finalAmount,
    discountAmount,
    appliedDiscounts,
  };
}
