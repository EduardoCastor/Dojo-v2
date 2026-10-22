import React from 'react';
import {
  Users,
  Calendar,
  DollarSign,
  TrendingUp,
  Award,
  AlertTriangle,
  CheckCircle,
  Plus,
  ArrowRight,
  Shield,
  FileCheck2,
} from 'lucide-react';
import {
  Tenant,
  Student,
  ClassGroup,
  Invoice,
  BeltExamEvent,
  AuditLog,
} from '../../types';
import { formatCurrencyBRL, formatDateBR } from '../../utils/formatters';
import { AdminViewTab } from '../layout/DashboardLayout';

interface OverviewDashboardProps {
  tenant: Tenant;
  students: Student[];
  classes: ClassGroup[];
  invoices: Invoice[];
  exams: BeltExamEvent[];
  auditLogs: AuditLog[];
  onNavigateTab: (tab: AdminViewTab) => void;
  onOpenNewStudent: () => void;
}

export const OverviewDashboard: React.FC<OverviewDashboardProps> = ({
  tenant,
  students,
  classes,
  invoices,
  exams,
  auditLogs,
  onNavigateTab,
  onOpenNewStudent,
}) => {
  const activeStudents = students.filter(s => s.status === 'active');

  // Financial metrics for current month
  const totalInvoiced = invoices.reduce((acc, inv) => acc + inv.finalAmount, 0);
  const totalPaid = invoices.filter(i => i.status === 'paid').reduce((acc, inv) => acc + inv.paidAmount, 0);
  const totalOverdue = invoices.filter(i => i.status === 'overdue').reduce((acc, inv) => acc + inv.balance, 0);
  const overdueCount = invoices.filter(i => i.status === 'overdue').length;
  const defaultRate = totalInvoiced > 0 ? ((totalOverdue / totalInvoiced) * 100).toFixed(1) : '0';

  // Capacity calculations
  const totalCapacity = classes.reduce((acc, c) => acc + c.maxCapacity, 0);
  const averageOccupancy = totalCapacity > 0 ? Math.round((activeStudents.length / totalCapacity) * 100) : 0;

  return (
    <div className="space-y-6">
      {/* Top Welcome & Quick Actions */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 pb-2">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold text-white tracking-tight">
            Painel da Academia · {tenant.tradeName}
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Gestão operacional consolidada da unidade matriz e filiais ativas.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={onOpenNewStudent}
            className="flex items-center gap-1.5 px-3 py-2 rounded-lg bg-red-600 text-white text-xs font-semibold hover:bg-red-500 active:bg-red-700 transition-colors shadow cursor-pointer"
          >
            <Plus className="h-4 w-4" />
            <span>Novo Aluno</span>
          </button>
          <button
            onClick={() => onNavigateTab('attendance')}
            className="flex items-center gap-1.5 px-3 py-2 rounded-lg border border-slate-700 bg-slate-800 text-slate-200 text-xs font-medium hover:bg-slate-700 hover:text-white transition-colors cursor-pointer"
          >
            <CheckCircle className="h-4 w-4 text-emerald-400" />
            <span>Fazer Chamada</span>
          </button>
        </div>
      </div>

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Alunos Ativos */}
        <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-4">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Alunos Ativos</span>
            <Users className="h-4 w-4 text-blue-400" />
          </div>
          <div className="text-2xl font-bold text-white font-mono tabular-nums">
            {activeStudents.length}
          </div>
          <div className="text-[11px] text-slate-400 mt-1 flex items-center justify-between">
            <span>Capacidade total: {totalCapacity} vagas</span>
            <span className="text-emerald-400 font-semibold">{averageOccupancy}% ocupação</span>
          </div>
        </div>

        {/* Faturamento Recebido */}
        <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-4">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Recebido no Mês</span>
            <DollarSign className="h-4 w-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-emerald-400 font-mono tabular-nums">
            {formatCurrencyBRL(totalPaid)}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            Total previsto: <span className="font-mono tabular-nums">{formatCurrencyBRL(totalInvoiced)}</span>
          </div>
        </div>

        {/* Inadimplência */}
        <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-4">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Inadimplência</span>
            <AlertTriangle className="h-4 w-4 text-amber-400" />
          </div>
          <div className="text-2xl font-bold text-amber-400 font-mono tabular-nums">
            {defaultRate}%
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            {overdueCount} mensalidade(s) em atraso ({formatCurrencyBRL(totalOverdue)})
          </div>
        </div>

        {/* Turmas & Treinos */}
        <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-4">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-medium">Turmas Cadastradas</span>
            <Calendar className="h-4 w-4 text-purple-400" />
          </div>
          <div className="text-2xl font-bold text-white font-mono tabular-nums">
            {classes.length}
          </div>
          <div className="text-[11px] text-slate-400 mt-1 flex items-center gap-1.5">
            <CheckCircle className="h-3 w-3 text-emerald-400" />
            <span>Validação anti-conflito ativa</span>
          </div>
        </div>
      </div>

      {/* Middle Section: Upcoming Belt Exam & Active Classes */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Upcoming Belt Exam Card */}
        <div className="lg:col-span-1 rounded-xl border border-slate-800 bg-slate-900/60 p-5 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-red-600/10 text-red-500 border border-red-500/20">
                  <Award className="h-4 w-4" />
                </div>
                <h3 className="text-sm font-bold text-white">Próximo Exame de Faixa</h3>
              </div>
              <span className="text-[10px] font-semibold text-emerald-400 bg-emerald-950/60 px-2 py-0.5 rounded border border-emerald-500/30">
                Inscrições Abertas
              </span>
            </div>

            {exams.length > 0 ? (
              <div className="space-y-2 mt-4 text-xs">
                <div className="font-semibold text-white">{exams[0].title}</div>
                <div className="text-slate-400">
                  Data: <strong className="text-slate-200">{formatDateBR(exams[0].examDate)}</strong>
                </div>
                <div className="text-slate-400">
                  Local: <span className="text-slate-300">{exams[0].location}</span>
                </div>
                <div className="text-slate-400">
                  Examinador: <span className="text-slate-300">{exams[0].chiefExaminerName}</span>
                </div>
                <div className="p-2.5 rounded-lg bg-slate-800/60 border border-slate-700/60 text-[11px] text-slate-300 mt-3">
                  <span className="font-medium text-amber-300">Critérios do Exame:</span> Validação de carência em meses, idade mínima e presença mínima (75%).
                </div>
              </div>
            ) : (
              <p className="text-xs text-slate-400">Nenhum exame agendado no momento.</p>
            )}
          </div>

          <button
            onClick={() => onNavigateTab('exams')}
            className="mt-4 w-full flex items-center justify-center gap-1.5 py-2 px-3 rounded-lg border border-slate-700 bg-slate-800 text-xs font-semibold text-slate-200 hover:text-white hover:bg-slate-700 transition-colors cursor-pointer"
          >
            <span>Ver Elegibilidade de Alunos</span>
            <ArrowRight className="h-3.5 w-3.5" />
          </button>
        </div>

        {/* Classes Today & Schedule Summary */}
        <div className="lg:col-span-2 rounded-xl border border-slate-800 bg-slate-900/60 p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Calendar className="h-4 w-4 text-red-500" />
              <span>Turmas Regulares & Capacidade</span>
            </h3>
            <button
              onClick={() => onNavigateTab('classes')}
              className="text-xs font-semibold text-red-400 hover:text-red-300 transition-colors cursor-pointer"
            >
              Ver Grade Completa
            </button>
          </div>

          <div className="space-y-3">
            {classes.slice(0, 4).map((c) => {
              return (
                <div
                  key={c.id}
                  className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-3 rounded-lg border border-slate-800 bg-slate-950/60"
                >
                  <div>
                    <div className="text-xs font-bold text-white">{c.name}</div>
                    <div className="text-[11px] text-slate-400 mt-0.5">
                      {c.startTime} às {c.endTime} · {c.tatamiRoom} · Prof. {c.headInstructorName}
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    <div className="text-right text-[11px]">
                      <div className="text-slate-300 font-mono">Capacidade: {c.maxCapacity}</div>
                      <div className="text-slate-400 text-[10px]">Idade: {c.minAge} {c.maxAge ? `a ${c.maxAge}` : '+'} anos</div>
                    </div>
                    <button
                      onClick={() => onNavigateTab('attendance')}
                      className="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-xs font-medium text-slate-200 hover:text-white transition-colors cursor-pointer whitespace-nowrap"
                    >
                      Chamada
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Audit Log / Activity Trail */}
      <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-5">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2 text-sm font-bold text-white">
            <Shield className="h-4 w-4 text-slate-400" />
            <span>Trilha de Auditoria Recente</span>
          </div>
          <span className="text-[11px] text-slate-400">Registro de operações críticas</span>
        </div>

        <div className="divide-y divide-slate-800/80 text-xs">
          {auditLogs.slice(0, 4).map((log) => (
            <div key={log.id} className="py-2.5 flex items-start justify-between gap-4">
              <div>
                <span className="font-semibold text-white">{log.action}: </span>
                <span className="text-slate-400">{log.details}</span>
              </div>
              <div className="text-right shrink-0 text-[11px] text-slate-400">
                <div>{log.userName}</div>
                <div className="text-slate-400">{formatDateBR(log.timestamp)}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
