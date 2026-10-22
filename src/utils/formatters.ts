/**
 * Formatters and converters aligned with Brazilian conventions (pt-BR, BRL, DD/MM/AAAA)
 */

export function formatCurrencyBRL(value: number): string {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

export function formatDateBR(dateInput: string | Date | undefined | null): string {
  if (!dateInput) return '-';
  try {
    const d = typeof dateInput === 'string' ? new Date(dateInput + (dateInput.length === 10 ? 'T12:00:00' : '')) : dateInput;
    if (isNaN(d.getTime())) return '-';
    return new Intl.DateTimeFormat('pt-BR', {
      timeZone: 'America/Sao_Paulo',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(d);
  } catch {
    return '-';
  }
}

export function formatDateTimeBR(dateInput: string | Date | undefined | null): string {
  if (!dateInput) return '-';
  try {
    const d = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;
    if (isNaN(d.getTime())) return '-';
    return new Intl.DateTimeFormat('pt-BR', {
      timeZone: 'America/Sao_Paulo',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(d);
  } catch {
    return '-';
  }
}

export function calculateAge(birthDateStr?: string | null): number {
  if (!birthDateStr) return 0;
  try {
    const birth = new Date(birthDateStr + (birthDateStr.length === 10 ? 'T12:00:00' : ''));
    if (isNaN(birth.getTime())) return 0;
    const now = new Date();
    let age = now.getFullYear() - birth.getFullYear();
    const m = now.getMonth() - birth.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < birth.getDate())) {
      age--;
    }
    return Math.max(0, age);
  } catch {
    return 0;
  }
}

export function calculateBMI(weightKg?: number | null, heightCm?: number | null): { bmi: number; classification: string } {
  if (!weightKg || !heightCm || heightCm <= 0) return { bmi: 0, classification: 'Não avaliado' };
  const heightM = heightCm / 100;
  const bmi = Number((weightKg / (heightM * heightM)).toFixed(1));
  
  let classification = 'Eutrófico (Normal)';
  if (bmi < 18.5) classification = 'Abaixo do peso';
  else if (bmi >= 25 && bmi < 30) classification = 'Sobrepeso';
  else if (bmi >= 30 && bmi < 35) classification = 'Obesidade Grau I';
  else if (bmi >= 35) classification = 'Obesidade Grau II+';

  return { bmi, classification };
}

export { formatCPF, cleanCPF, validateCPF, maskCPFInput } from './cpfValidator';

export function formatCNPJ(cnpj?: string | null): string {
  if (!cnpj) return '-';
  const clean = String(cnpj).replace(/\D/g, '');
  if (clean.length !== 14) return cnpj;
  return clean.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5');
}

export function formatPhoneBR(phone?: string | null): string {
  if (!phone) return '-';
  const clean = String(phone).replace(/\D/g, '');
  if (clean.length === 11) {
    return clean.replace(/(\d{2})(\d{5})(\d{4})/, '($1) $2-$3');
  } else if (clean.length === 10) {
    return clean.replace(/(\d{2})(\d{4})(\d{4})/, '($1) $2-$3');
  }
  return phone;
}

export function getDaysOfWeekLabels(days: number[]): string {
  const map: Record<number, string> = {
    0: 'Dom',
    1: 'Seg',
    2: 'Ter',
    3: 'Qua',
    4: 'Qui',
    5: 'Sex',
    6: 'Sáb',
  };
  return days.map(d => map[d] || '').filter(Boolean).join(', ');
}
