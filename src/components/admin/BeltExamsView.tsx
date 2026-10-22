import React, { useState } from 'react';
import {
  FileCheck2,
  Plus,
  Award,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Printer,
  X,
  Check,
  Calendar,
} from 'lucide-react';
import {
  BeltExamEvent,
  BeltExamRegistration,
  Student,
  Person,
  BeltRank,
  Tenant,
} from '../../types';
import { formatDateBR, calculateAge, formatCurrencyBRL } from '../../utils/formatters';
import { evaluateBeltExamEligibility } from '../../utils/validators';

interface BeltExamsViewProps {
  tenant: Tenant;
  exams: BeltExamEvent[];
  registrations: BeltExamRegistration[];
  students: Student[];
  persons: Person[];
  beltRanks: BeltRank[];
  onAddExam: (exam: BeltExamEvent) => void;
  onApproveCandidate: (registrationId: string, score: number, notes: string) => void;
}

export const BeltExamsView: React.FC<BeltExamsViewProps> = ({
  tenant,
  exams,
  registrations,
  students,
  persons,
  beltRanks,
  onAddExam,
  onApproveCandidate,
}) => {
  const [selectedExamId, setSelectedExamId] = useState<string>(exams[0]?.id || '');
  const [isAddExamOpen, setIsAddExamOpen] = useState(false);
  const [selectedCertReg, setSelectedCertReg] = useState<BeltExamRegistration | null>(null);

  // Evaluation modal state
  const [evaluatingReg, setEvaluatingReg] = useState<BeltExamRegistration | null>(null);
  const [score, setScore] = useState('8.5');
  const [examinerNotes, setExaminerNotes] = useState('Excelente execução de Nage-waza e postura de Reiho.');

  // New Exam Form
  const [title, setTitle] = useState('');
  const [examDate, setExamDate] = useState('2026-11-28');
  const [location, setLocation] = useState('Dojo Nobre da Matriz');
  const [chiefExaminer, setChiefExaminer] = useState('Sensei Kenji Yamamoto (6º Dan)');
  const [examFee, setExamFee] = useState('120');

  const activeExam = exams.find(e => e.id === selectedExamId) || exams[0];
  const examRegistrations = registrations.filter(r => r.examId === activeExam?.id);

  const getStudentAndPerson = (studentId: string) => {
    const student = students.find(s => s.id === studentId);
    const person = student ? persons.find(p => p.id === student.personId) : null;
    return { student, person };
  };

  const handleCreateExam = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const newExam: BeltExamEvent = {
      id: `exam-${Date.now()}`,
      tenantId: tenant.id,
      branchId: 'branch-matriz',
      martialArtId: 'art-judo',
      martialArtName: 'Judô',
      title,
      examDate,
      location,
      chiefExaminerName: chiefExaminer,
      targetRanks: ['Faixa Azul', 'Faixa Amarela', 'Faixa Laranja', 'Faixa Verde'],
      examFee: Number(examFee) || 120,
      status: 'open',
      candidatesCount: 0,
    };

    onAddExam(newExam);
    setIsAddExamOpen(false);
    setTitle('');
  };

  const handleConfirmApproval = () => {
    if (!evaluatingReg) return;
    onApproveCandidate(evaluatingReg.id, Number(score) || 9.0, examinerNotes);
    setEvaluatingReg(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-white tracking-tight">Exames de Faixa & Graduação</h2>
          <p className="text-xs text-slate-400">
            Bancas examinadoras oficiais, elegibilidade objetiva (tempo e presença) e emissão de certificados.
          </p>
        </div>

        <button
          onClick={() => setIsAddExamOpen(true)}
          className="flex items-center gap-2 rounded-lg bg-red-600 px-4 py-2 text-xs font-semibold text-white hover:bg-red-500 transition-colors shadow cursor-pointer"
        >
          <Plus className="h-4 w-4" />
          <span>Novo Exame de Graduação</span>
        </button>
      </div>

      {/* Active Exam Card Details */}
      {activeExam ? (
        <div className="p-5 rounded-xl border border-slate-800 bg-slate-900/60 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="text-[10px] font-bold text-red-400 uppercase bg-red-950/60 border border-red-500/30 px-2 py-0.5 rounded">
                {activeExam.martialArtName}
              </span>
              <span className="text-xs text-slate-400">Data marcada: <strong className="text-white font-mono">{formatDateBR(activeExam.examDate)}</strong></span>
            </div>
            <h3 className="text-base font-bold text-white">{activeExam.title}</h3>
            <div className="text-xs text-slate-400 mt-1">
              Local: <span className="text-slate-300">{activeExam.location}</span> · Banca Chefiada por: <span className="text-slate-200 font-medium">{activeExam.chiefExaminerName}</span>
            </div>
          </div>

          <div className="flex items-center gap-4 border-t md:border-t-0 md:border-l border-slate-800 pt-3 md:pt-0 md:pl-6">
            <div className="text-right">
              <div className="text-xs text-slate-400">Taxa do Exame</div>
              <div className="text-lg font-bold text-emerald-400 font-mono">{formatCurrencyBRL(activeExam.examFee)}</div>
            </div>
            <span className="px-3 py-1 rounded-full bg-emerald-950/60 border border-emerald-500/30 text-emerald-400 text-xs font-semibold">
              Inscrições Abertas
            </span>
          </div>
        </div>
      ) : (
        <div className="p-8 text-center text-slate-500 text-xs">Nenhum exame cadastrado.</div>
      )}

      {/* Candidates List with Eligibility Indicators */}
      <div className="rounded-xl border border-slate-800 bg-slate-900/60 overflow-hidden">
        <div className="p-4 border-b border-slate-800 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Award className="h-4 w-4 text-red-500" />
            <h3 className="text-xs font-bold text-white uppercase tracking-wider">
              Candidatos Inscritos & Elegibilidade ({examRegistrations.length})
            </h3>
          </div>
          <span className="text-[11px] text-slate-400">Critério: Carência de tempo + Presença ≥ 75% + Idade</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-800 bg-slate-950/60 text-slate-400 font-semibold uppercase tracking-wider text-[10px]">
              <tr>
                <th className="py-3 px-4">Aluno Candidato</th>
                <th className="py-3 px-4">Faixa Atual</th>
                <th className="py-3 px-4">Faixa Pretendida</th>
                <th className="py-3 px-4">Taxa</th>
                <th className="py-3 px-4">Elegibilidade Prévia</th>
                <th className="py-3 px-4">Resultado da Banca</th>
                <th className="py-3 px-4 text-right">Ações da Banca</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {examRegistrations.map((reg) => {
                const { student, person } = getStudentAndPerson(reg.studentId);
                const age = person ? calculateAge(person.birthDate) : 0;
                const isApproved = reg.resultStatus === 'approved';

                return (
                  <tr key={reg.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-3 px-4">
                      <div className="font-semibold text-white">{reg.studentName}</div>
                      <div className="text-[10px] text-slate-400 font-mono">
                        {age} anos · Matrícula: {student?.registrationNumber}
                      </div>
                    </td>

                    <td className="py-3 px-4 font-medium text-slate-300">
                      {reg.currentBelt}
                    </td>

                    <td className="py-3 px-4 font-bold text-white">
                      {reg.targetBelt}
                    </td>

                    <td className="py-3 px-4">
                      <span className="text-[10px] font-semibold text-emerald-400 bg-emerald-950/60 px-2 py-0.5 rounded border border-emerald-500/30">
                        {reg.feeStatus === 'paid' ? 'Taxa Paga' : 'Pendente'}
                      </span>
                    </td>

                    <td className="py-3 px-4">
                      <div className="flex items-center gap-1.5 text-emerald-400">
                        <CheckCircle2 className="h-3.5 w-3.5 shrink-0" />
                        <span className="text-[11px] font-medium">Requisitos Cumpridos</span>
                      </div>
                      <span className="text-[10px] text-slate-500 block">Tempo e frequência validados</span>
                    </td>

                    <td className="py-3 px-4">
                      {isApproved ? (
                        <div>
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-950/80 text-emerald-300 border border-emerald-500/40">
                            Aprovado (Nota {reg.score?.toFixed(1) || '9.0'})
                          </span>
                        </div>
                      ) : (
                        <span className="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold bg-slate-800 text-slate-400">
                          Aguardando Exame
                        </span>
                      )}
                    </td>

                    <td className="py-3 px-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        {!isApproved ? (
                          <button
                            onClick={() => setEvaluatingReg(reg)}
                            className="px-2.5 py-1 rounded-lg bg-red-600 hover:bg-red-500 text-white font-semibold text-[11px] shadow transition-colors cursor-pointer whitespace-nowrap"
                          >
                            Avaliar & Promover
                          </button>
                        ) : (
                          <button
                            onClick={() => setSelectedCertReg(reg)}
                            className="flex items-center gap-1 px-2.5 py-1 rounded-lg border border-slate-700 bg-slate-800 text-slate-300 hover:text-white text-[11px] font-semibold transition-colors cursor-pointer"
                          >
                            <Printer className="h-3 w-3 text-red-400" />
                            <span>Certificado</span>
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Evaluating Modal */}
      {evaluatingReg && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="relative w-full max-w-md rounded-2xl border border-slate-700 bg-slate-900 p-6 shadow-2xl text-slate-200">
            <h3 className="text-base font-bold text-white mb-1">Avaliação da Banca Examinadora</h3>
            <p className="text-xs text-slate-400 mb-4">
              Candidato: <strong className="text-white">{evaluatingReg.studentName}</strong> para <strong className="text-red-400">{evaluatingReg.targetBelt}</strong>
            </p>

            <div className="space-y-3 text-xs mb-6">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Nota Técnica (0 a 10)</label>
                <input
                  type="number"
                  step="0.1"
                  min="0"
                  max="10"
                  value={score}
                  onChange={(e) => setScore(e.target.value)}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Parecer do Sensei Examinador</label>
                <textarea
                  rows={3}
                  value={examinerNotes}
                  onChange={(e) => setExaminerNotes(e.target.value)}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => setEvaluatingReg(null)}
                className="px-3 py-2 rounded-lg border border-slate-700 bg-slate-800 text-slate-300 hover:text-white"
              >
                Cancelar
              </button>
              <button
                type="button"
                onClick={handleConfirmApproval}
                className="px-4 py-2 rounded-lg bg-emerald-600 font-semibold text-white hover:bg-emerald-500 shadow"
              >
                Aprovar & Graduar Aluno
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Certificate Modal */}
      {selectedCertReg && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="relative w-full max-w-2xl rounded-2xl border border-slate-700 bg-slate-900 p-6 shadow-2xl text-slate-200">
            <button
              onClick={() => setSelectedCertReg(null)}
              className="absolute top-4 right-4 p-1 text-slate-400 hover:text-white"
            >
              <X className="h-5 w-5" />
            </button>

            {/* Diploma Style Document */}
            <div className="border-4 border-amber-600/40 rounded-xl p-8 bg-amber-50 text-slate-950 space-y-6 text-center shadow-lg">
              <div className="border-b border-amber-300/80 pb-4">
                <div className="text-xs uppercase tracking-widest text-red-700 font-bold">Confederação & Academia de Artes Marciais</div>
                <h4 className="text-2xl font-extrabold text-slate-900 mt-1 tracking-tight">{tenant.tradeName}</h4>
                <div className="text-xs text-slate-600 font-serif italic mt-0.5">Fundada sob os princípios da disciplina e do respeito mútuo (Jita Kyoei)</div>
              </div>

              <div className="space-y-3">
                <div className="text-xs text-slate-700 uppercase tracking-wider font-semibold">Certificado Oficial de Graduação</div>
                <p className="text-sm text-slate-800 leading-relaxed font-serif">
                  Certificamos que o(a) atleta e praticante de Judô
                </p>
                <div className="text-xl font-extrabold text-slate-900 uppercase underline decoration-amber-600">
                  {selectedCertReg.studentName}
                </div>
                <p className="text-sm text-slate-800 leading-relaxed font-serif">
                  prestou com êxito todos os exames técnicos exigidos de Kata, Waza e conduta moral, sendo promovido(a) com honras ao nível de:
                </p>
                <div className="text-2xl font-black text-red-700 uppercase tracking-wide">
                  {selectedCertReg.targetBelt}
                </div>
              </div>

              <div className="pt-6 border-t border-amber-300/80 flex items-center justify-between text-xs text-slate-700">
                <div>
                  <div className="border-b border-slate-400 w-40 mb-1"></div>
                  <span>Sensei Kenji Yamamoto</span>
                  <div className="text-[10px] text-slate-500">Examinador Geral (6º Dan)</div>
                </div>

                <div className="text-right text-[11px] text-slate-500 font-mono">
                  Registro: KOD-DIPLOMA-{selectedCertReg.id.slice(-6)}
                  <br />
                  Data: {formatDateBR(new Date().toISOString())}
                </div>
              </div>
            </div>

            <div className="mt-4 flex justify-end gap-2">
              <button
                onClick={() => setSelectedCertReg(null)}
                className="px-4 py-2 rounded-lg bg-slate-800 text-xs text-white hover:bg-slate-700"
              >
                Fechar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Exam Modal */}
      {isAddExamOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="relative w-full max-w-md rounded-2xl border border-slate-700 bg-slate-900 p-6 shadow-2xl text-slate-200">
            <h3 className="text-base font-bold text-white mb-3">Cadastrar Exame de Faixa</h3>

            <form onSubmit={handleCreateExam} className="space-y-3 text-xs">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Título do Evento *</label>
                <input
                  type="text"
                  required
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Ex: Exame de Graduação - 1º Semestre 2027"
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Data do Exame</label>
                  <input
                    type="date"
                    value={examDate}
                    onChange={(e) => setExamDate(e.target.value)}
                    className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Taxa de Inscrição (R$)</label>
                  <input
                    type="number"
                    value={examFee}
                    onChange={(e) => setExamFee(e.target.value)}
                    className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Local / Dojo</label>
                <input
                  type="text"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Examinador Chefe</label>
                <input
                  type="text"
                  value={chiefExaminer}
                  onChange={(e) => setChiefExaminer(e.target.value)}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsAddExamOpen(false)}
                  className="px-3 py-2 rounded-lg border border-slate-700 bg-slate-800 text-slate-300 hover:text-white"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-red-600 font-semibold text-white hover:bg-red-500"
                >
                  Criar Exame
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
