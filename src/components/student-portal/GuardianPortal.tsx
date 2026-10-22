import React, { useState } from 'react';
import {
  Users,
  Award,
  Calendar,
  CheckCircle2,
  DollarSign,
  ShieldCheck,
  FileCheck,
  Copy,
  Check,
  ArrowRight,
} from 'lucide-react';
import {
  Student,
  Person,
  GuardianRelationship,
  Invoice,
  ClassGroup,
  AttendanceRecord,
  HealthRecord,
} from '../../types';
import { formatCurrencyBRL, formatDateBR, calculateAge } from '../../utils/formatters';

interface GuardianPortalProps {
  guardianPerson: Person;
  relationships: GuardianRelationship[];
  students: Student[];
  persons: Person[];
  invoices: Invoice[];
  classes: ClassGroup[];
  attendances: AttendanceRecord[];
  healthRecords: HealthRecord[];
}

export const GuardianPortal: React.FC<GuardianPortalProps> = ({
  guardianPerson,
  relationships,
  students,
  persons,
  invoices,
  classes,
  attendances,
  healthRecords,
}) => {
  if (!guardianPerson) {
    return (
      <div className="p-8 text-center text-slate-400 bg-slate-900/50 rounded-2xl border border-slate-800 my-8">
        <p className="text-sm font-semibold text-white mb-1">Portal do Responsável</p>
        <p className="text-xs text-slate-400">Nenhum responsável legal identificado para este usuário no momento.</p>
      </div>
    );
  }

  // Find dependents
  const dependentStudentIds = relationships
    .filter(r => r.guardianPersonId === guardianPerson.id)
    .map(r => r.studentId);

  const myStudents = students.filter(s => dependentStudentIds.includes(s.id));
  const [selectedStudentId, setSelectedStudentId] = useState<string>(myStudents[0]?.id || '');
  const [copiedPix, setCopiedPix] = useState(false);

  const activeStudent = myStudents.find(s => s.id === selectedStudentId) || myStudents[0];
  const activePerson = persons.find(p => p.id === activeStudent?.personId);
  const activeAge = activePerson ? calculateAge(activePerson.birthDate) : 0;
  const activeBelt = activeStudent?.currentGraduations?.[0];
  const activeHealth = healthRecords.find(h => h.studentId === activeStudent?.id);

  // Consolidated Invoices for this guardian
  const familyInvoices = invoices.filter(
    i => i.financialGuardianId === guardianPerson.id || dependentStudentIds.includes(i.studentId)
  );

  const handleCopyPix = (code?: string) => {
    if (!code) return;
    navigator.clipboard.writeText(code);
    setCopiedPix(true);
    setTimeout(() => setCopiedPix(false), 2000);
  };

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Guardian Header */}
      <div className="p-6 rounded-2xl border border-slate-800 bg-slate-900/60 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-[10px] font-bold text-red-400 uppercase bg-red-950/60 px-2 py-0.5 rounded border border-red-500/30">
              Portal da Família & Responsáveis
            </span>
            <span className="text-xs text-slate-400">Responsável Legal & Financeiro</span>
          </div>
          <h2 className="text-xl font-bold text-white">{guardianPerson.fullName}</h2>
          <p className="text-xs text-slate-400 mt-0.5">
            Acompanhamento integrado de matrículas, frequência, faixas e mensalidades unificadas.
          </p>
        </div>

        {/* Dependent Switcher Tabs */}
        <div className="flex items-center gap-2 p-1.5 rounded-xl bg-slate-950 border border-slate-800">
          {myStudents.map((dep) => {
            const p = persons.find(item => item.id === dep.personId);
            const isSelected = dep.id === activeStudent?.id;
            return (
              <button
                key={dep.id}
                onClick={() => setSelectedStudentId(dep.id)}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                  isSelected
                    ? 'bg-red-600 text-white shadow'
                    : 'text-slate-400 hover:text-white hover:bg-slate-900'
                }`}
              >
                <Users className="h-3.5 w-3.5" />
                <span>{p?.fullName.split(' ')[0] || 'Dependente'}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Active Dependent Overview */}
      {activeStudent && activePerson && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Card 1: Belt & Progress */}
          <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/60 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-bold text-slate-400 uppercase">Graduação</span>
                <span className="text-[11px] text-slate-500 font-mono">Matrícula: {activeStudent.registrationNumber}</span>
              </div>

              <div className="flex items-center gap-3 my-2">
                <span
                  className="h-5 w-5 rounded-full border border-slate-500 shadow-sm"
                  style={{ backgroundColor: activeBelt?.beltColorHex || '#fff' }}
                ></span>
                <div>
                  <div className="text-base font-bold text-white">{activeBelt?.beltName}</div>
                  <div className="text-xs text-slate-400">{activeBelt?.martialArtName || 'Judô'}</div>
                </div>
              </div>

              <div className="text-xs text-slate-400 mt-3 pt-3 border-t border-slate-800 space-y-1">
                <div>Idade Atual: <strong className="text-white">{activeAge} anos</strong></div>
                <div>Graduado em: {formatDateBR(activeBelt?.graduatedAt)}</div>
              </div>
            </div>

            <div className="mt-4 p-2 rounded-lg bg-slate-950/60 border border-slate-800 text-[11px] text-emerald-400 flex items-center gap-1.5">
              <CheckCircle2 className="h-3.5 w-3.5 shrink-0" />
              <span>Apto para os treinos regulares</span>
            </div>
          </div>

          {/* Card 2: Medical & Authorization */}
          <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/60 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-bold text-slate-400 uppercase">Atestados & Saúde</span>
                <ShieldCheck className="h-4 w-4 text-emerald-400" />
              </div>

              {activeHealth ? (
                <div className="space-y-2 text-xs">
                  <div className="text-slate-300">
                    Atestado Médico: <strong className="text-emerald-400">Válido</strong>
                  </div>
                  <div className="text-[11px] text-slate-400">
                    Vencimento: {formatDateBR(activeHealth.medicalCertExpiryDate)}
                  </div>
                  <div className="text-[11px] text-slate-400">
                    Alergias: {activeHealth.allergies.join(', ') || 'Nenhuma informada.'}
                  </div>
                  <div className="text-[11px] text-slate-400">
                    Medicamentos: {activeHealth.voluntaryMedications || 'Nenhum.'}
                  </div>
                </div>
              ) : (
                <div className="text-xs text-slate-500">Nenhum prontuário registrado.</div>
              )}
            </div>

            <div className="mt-4 text-[10px] text-slate-500">
              Autorização para retirada de menores com mãe Camila Oliveira.
            </div>
          </div>

          {/* Card 3: Monthly Fee with Family Discount Indicator */}
          <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/60 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-bold text-slate-400 uppercase">Condição Financeira</span>
                <DollarSign className="h-4 w-4 text-emerald-400" />
              </div>

              <div className="text-2xl font-bold text-white font-mono">
                {formatCurrencyBRL(activeStudent.monthlyFee)}
                <span className="text-xs text-slate-400 font-sans font-normal ml-1">/mês</span>
              </div>

              {activeStudent.id === 'student-sofia' && (
                <div className="mt-2 p-2 rounded-lg bg-emerald-950/60 border border-emerald-500/30 text-[11px] text-emerald-300">
                  <span className="font-bold">Desconto Familiar (15%) Ativo:</span> Benefício aplicado automaticamente por ser o 2º dependente sob a mesma titularidade.
                </div>
              )}
            </div>

            <div className="mt-4 text-[10px] text-slate-500">
              Cobrança unificada vinculada ao CPF {guardianPerson.cpf}.
            </div>
          </div>
        </div>
      )}

      {/* Unified Invoices Table for the Family */}
      <div className="rounded-2xl border border-slate-800 bg-slate-900/60 p-5">
        <h3 className="text-sm font-bold text-white mb-3 flex items-center gap-2">
          <DollarSign className="h-4 w-4 text-emerald-400" />
          <span>Extrato Financeiro Unificado da Família</span>
        </h3>

        <div className="divide-y divide-slate-800 text-xs">
          {familyInvoices.map((inv) => {
            const student = students.find(s => s.id === inv.studentId);
            const p = student ? persons.find(item => item.id === student.personId) : null;
            const isPaid = inv.status === 'paid';

            return (
              <div key={inv.id} className="py-3 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                <div>
                  <div className="font-bold text-white">{p?.fullName || 'Aluno'} · Mensalidade {inv.competence}</div>
                  <div className="text-[11px] text-slate-400">
                    Vencimento: {formatDateBR(inv.dueDate)} {inv.discountAmount > 0 ? `· (${inv.discountDescription})` : ''}
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <div className="text-right">
                    <div className="font-mono font-bold text-white">{formatCurrencyBRL(inv.finalAmount)}</div>
                    <span
                      className={`text-[10px] font-semibold px-2 py-0.5 rounded ${
                        isPaid
                          ? 'bg-emerald-950/60 text-emerald-400 border border-emerald-500/30'
                          : 'bg-amber-950/60 text-amber-400 border border-amber-500/30'
                      }`}
                    >
                      {isPaid ? 'Pago com PIX' : 'Aguardando Pagamento'}
                    </span>
                  </div>

                  {!isPaid && (
                    <button
                      onClick={() => handleCopyPix(inv.pixCode)}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs shadow transition-colors cursor-pointer"
                    >
                      {copiedPix ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
                      <span>{copiedPix ? 'Copiado!' : 'PIX'}</span>
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
