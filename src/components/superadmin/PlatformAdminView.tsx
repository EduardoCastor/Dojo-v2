import React, { useState } from 'react';
import {
  ShieldAlert,
  Building2,
  DollarSign,
  Users,
  Clock,
  Sparkles,
  CheckCircle2,
  XCircle,
  Edit2,
  Save,
  Check,
  Search,
} from 'lucide-react';
import { Tenant, SaaSPlan, User } from '../../types';
import { formatCurrencyBRL, formatDateBR } from '../../utils/formatters';

interface PlatformAdminViewProps {
  tenants: Tenant[];
  plans: SaaSPlan[];
  currentUser: User;
  onUpdatePlans: (updatedPlans: SaaSPlan[]) => void;
  onUpdateTenantStatus: (tenantId: string, status: Tenant['status']) => void;
  onSwitchTenant: (tenantId: string) => void;
}

export const PlatformAdminView: React.FC<PlatformAdminViewProps> = ({
  tenants,
  plans,
  currentUser,
  onUpdatePlans,
  onUpdateTenantStatus,
  onSwitchTenant,
}) => {
  const [activeTab, setActiveTab] = useState<'tenants' | 'plans' | 'audit'>('tenants');
  const [searchTerm, setSearchTerm] = useState('');
  const [editablePlans, setEditablePlans] = useState<SaaSPlan[]>(plans);
  const [plansSaved, setPlansSaved] = useState(false);

  // Platform Metrics
  const totalTenants = tenants.length;
  const trialTenants = tenants.filter(t => t.status === 'trial').length;
  const activeTenants = tenants.filter(t => t.status === 'active').length;
  const estimatedMRR = tenants.reduce((acc, t) => {
    const plan = plans.find(p => p.id === t.planId);
    return acc + (plan?.pricePerMonth || 0);
  }, 0);

  const filteredTenants = tenants.filter(
    t =>
      t.tradeName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      t.adminName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      t.cnpjOrCpf.includes(searchTerm)
  );

  const handlePlanPriceChange = (planId: string, newPrice: number) => {
    setEditablePlans(prev =>
      prev.map(p => (p.id === planId ? { ...p, pricePerMonth: newPrice } : p))
    );
  };

  const handlePlanMaxStudentsChange = (planId: string, maxStudents: number) => {
    setEditablePlans(prev =>
      prev.map(p => (p.id === planId ? { ...p, maxStudents } : p))
    );
  };

  const handlePlanMaxBranchesChange = (planId: string, maxBranches: number) => {
    setEditablePlans(prev =>
      prev.map(p => (p.id === planId ? { ...p, maxBranches } : p))
    );
  };

  const handleSavePlans = () => {
    onUpdatePlans(editablePlans);
    setPlansSaved(true);
    setTimeout(() => setPlansSaved(false), 2500);
  };

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-[10px] font-bold text-amber-400 uppercase bg-amber-950/60 px-2 py-0.5 rounded border border-amber-500/30">
              Console Central da Plataforma
            </span>
            <span className="text-xs text-slate-400">Administrador Geral SaaS</span>
          </div>
          <h1 className="text-xl sm:text-2xl font-bold text-white tracking-tight">
            Gestão Multi-Tenant & Assinaturas
          </h1>
          <p className="text-xs text-slate-400">
            Painel exclusivo do proprietário da plataforma para monitoramento de academias, planos e retenção.
          </p>
        </div>
      </div>

      {/* SaaS Platform KPI Strip */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="p-4 rounded-xl border border-slate-800 bg-slate-900/60">
          <div className="text-xs text-slate-400 mb-1">Academias Clientes</div>
          <div className="text-2xl font-bold text-white font-mono tabular-nums">{totalTenants}</div>
          <div className="text-[11px] text-slate-500 mt-1">{activeTenants} ativas · {trialTenants} em teste</div>
        </div>

        <div className="p-4 rounded-xl border border-slate-800 bg-slate-900/60">
          <div className="text-xs text-slate-400 mb-1">Contas em Avaliação (10d)</div>
          <div className="text-2xl font-bold text-amber-400 font-mono tabular-nums">{trialTenants}</div>
          <div className="text-[11px] text-slate-500 mt-1">Conversão para planos pagos</div>
        </div>

        <div className="p-4 rounded-xl border border-slate-800 bg-slate-900/60">
          <div className="text-xs text-slate-400 mb-1">MRR Estimado (Recorrência)</div>
          <div className="text-2xl font-bold text-emerald-400 font-mono tabular-nums">{formatCurrencyBRL(estimatedMRR)}</div>
          <div className="text-[11px] text-slate-500 mt-1">Faturamento mensal do SaaS</div>
        </div>

        <div className="p-4 rounded-xl border border-slate-800 bg-slate-900/60">
          <div className="text-xs text-slate-400 mb-1">Isolamento de Dados</div>
          <div className="text-2xl font-bold text-blue-400 font-mono tabular-nums">100%</div>
          <div className="text-[11px] text-slate-500 mt-1">Segregação multi-tenant estrita</div>
        </div>
      </div>

      {/* Tabs Switcher */}
      <div className="flex border-b border-slate-800 text-xs font-semibold">
        <button
          onClick={() => setActiveTab('tenants')}
          className={`py-2.5 px-4 border-b-2 cursor-pointer transition-colors ${
            activeTab === 'tenants' ? 'border-red-500 text-white' : 'border-transparent text-slate-400 hover:text-white'
          }`}
        >
          Academias Cadastradas ({tenants.length})
        </button>
        <button
          onClick={() => setActiveTab('plans')}
          className={`py-2.5 px-4 border-b-2 cursor-pointer transition-colors ${
            activeTab === 'plans' ? 'border-red-500 text-white' : 'border-transparent text-slate-400 hover:text-white'
          }`}
        >
          Configuração de Planos & Limites
        </button>
      </div>

      {/* Tab 1: Tenants List */}
      {activeTab === 'tenants' && (
        <div className="space-y-4">
          <div className="relative w-full max-w-md">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-500" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Buscar por nome da academia, responsável ou CNPJ..."
              className="w-full rounded-lg border border-slate-800 bg-slate-900 pl-9 pr-3 py-2 text-xs text-white placeholder-slate-500 focus:border-red-500 focus:outline-none"
            />
          </div>

          <div className="rounded-xl border border-slate-800 bg-slate-900/60 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-slate-800 bg-slate-950/60 text-slate-400 font-semibold uppercase tracking-wider text-[10px]">
                  <tr>
                    <th className="py-3 px-4">Academia / Dojô</th>
                    <th className="py-3 px-4">Responsável</th>
                    <th className="py-3 px-4">Plano</th>
                    <th className="py-3 px-4">Status & Trial</th>
                    <th className="py-3 px-4">Cidade / UF</th>
                    <th className="py-3 px-4 text-right">Ações da Plataforma</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60">
                  {filteredTenants.map((t) => {
                    const plan = plans.find(p => p.id === t.planId);
                    const isTrial = t.status === 'trial';
                    const isSuspended = t.status === 'suspended';

                    return (
                      <tr key={t.id} className="hover:bg-slate-800/40 transition-colors">
                        <td className="py-3 px-4">
                          <div className="font-bold text-white">{t.tradeName}</div>
                          <div className="text-[10px] text-slate-500 font-mono">
                            {t.cnpjOrCpf} · ID: {t.id}
                          </div>
                        </td>

                        <td className="py-3 px-4">
                          <div className="text-slate-200">{t.adminName}</div>
                          <div className="text-[10px] text-slate-500">{t.email}</div>
                        </td>

                        <td className="py-3 px-4">
                          <span className="font-semibold text-slate-300">{plan?.name || t.planId}</span>
                          <span className="block text-[10px] text-slate-500">
                            {plan?.pricePerMonth === 0 ? 'Gratuito' : formatCurrencyBRL(plan?.pricePerMonth || 0)}
                          </span>
                        </td>

                        <td className="py-3 px-4">
                          {isTrial ? (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold bg-amber-950/60 text-amber-400 border border-amber-500/30">
                              <Clock className="h-3 w-3" />
                              <span>Teste 10 Dias Ativo</span>
                            </span>
                          ) : isSuspended ? (
                            <span className="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold bg-red-950/60 text-red-400 border border-red-500/30">
                              Suspensa
                            </span>
                          ) : (
                            <span className="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-950/60 text-emerald-400 border border-emerald-500/30">
                              Assinatura Regular
                            </span>
                          )}
                        </td>

                        <td className="py-3 px-4 text-slate-400">
                          {t.address.city}/{t.address.state}
                        </td>

                        <td className="py-3 px-4 text-right">
                          <div className="flex items-center justify-end gap-2">
                            <button
                              onClick={() => onSwitchTenant(t.id)}
                              className="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-[11px] font-semibold transition-colors cursor-pointer"
                              title="Acessar painel da academia"
                            >
                              Acessar Dojo
                            </button>

                            {isSuspended ? (
                              <button
                                onClick={() => onUpdateTenantStatus(t.id, 'active')}
                                className="px-2.5 py-1 rounded bg-emerald-600/20 text-emerald-400 hover:bg-emerald-600/30 text-[11px] font-semibold transition-colors cursor-pointer"
                              >
                                Reativar
                              </button>
                            ) : (
                              <button
                                onClick={() => onUpdateTenantStatus(t.id, 'suspended')}
                                className="px-2.5 py-1 rounded bg-red-950/60 text-red-400 hover:bg-red-900/60 text-[11px] font-semibold transition-colors cursor-pointer"
                              >
                                Suspender
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
        </div>
      )}

      {/* Tab 2: Configuração de Planos SaaS */}
      {activeTab === 'plans' && (
        <div className="space-y-6">
          <div className="p-4 rounded-xl border border-slate-800 bg-slate-900/40 text-xs text-slate-300 flex items-center justify-between">
            <div>
              <span className="font-bold text-white">Parâmetros Configuráveis pelo Administrador:</span>
              <p className="text-slate-400 text-[11px] mt-0.5">
                Altere preços de mensalidade, limites máximos de alunos e filiais em tempo de execução sem alterar código-fonte.
              </p>
            </div>
            {plansSaved && (
              <span className="text-xs text-emerald-400 font-semibold flex items-center gap-1">
                <Check className="h-4 w-4" />
                Planos Atualizados!
              </span>
            )}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {editablePlans.map((plan) => (
              <div
                key={plan.id}
                className="p-5 rounded-2xl border border-slate-800 bg-slate-900/60 space-y-4 text-xs"
              >
                <div className="border-b border-slate-800 pb-3">
                  <div className="font-bold text-white text-base">{plan.name}</div>
                  <div className="text-[11px] text-slate-400 mt-0.5">{plan.tagline}</div>
                </div>

                <div className="space-y-3">
                  <div>
                    <label className="block text-slate-300 font-medium mb-1">Preço Mensal (R$)</label>
                    <input
                      type="number"
                      value={plan.pricePerMonth}
                      disabled={plan.id === 'trial'}
                      onChange={(e) => handlePlanPriceChange(plan.id, Number(e.target.value))}
                      className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-1.5 text-white font-mono focus:outline-none"
                    />
                  </div>

                  <div>
                    <label className="block text-slate-300 font-medium mb-1">Máx. de Alunos Cadastrados</label>
                    <input
                      type="number"
                      value={plan.maxStudents}
                      onChange={(e) => handlePlanMaxStudentsChange(plan.id, Number(e.target.value))}
                      className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-1.5 text-white font-mono focus:outline-none"
                    />
                  </div>

                  <div>
                    <label className="block text-slate-300 font-medium mb-1">Máx. de Filiais Permitidas</label>
                    <input
                      type="number"
                      value={plan.maxBranches}
                      onChange={(e) => handlePlanMaxBranchesChange(plan.id, Number(e.target.value))}
                      className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-1.5 text-white font-mono focus:outline-none"
                    />
                  </div>
                </div>

                <div className="pt-2 border-t border-slate-800 text-[11px] text-slate-400 space-y-1">
                  <div>Biblioteca Digital: {plan.features.digitalLibrary ? '✅ Sim' : '❌ Não'}</div>
                  <div>Exames de Faixa: {plan.features.beltExams ? '✅ Sim' : '❌ Não'}</div>
                  <div>Competições: {plan.features.competitions ? '✅ Sim' : '❌ Não'}</div>
                </div>
              </div>
            ))}
          </div>

          <div className="flex justify-end">
            <button
              onClick={handleSavePlans}
              className="flex items-center gap-2 px-5 py-2.5 rounded-lg bg-red-600 hover:bg-red-500 text-white font-semibold text-xs shadow transition-colors cursor-pointer"
            >
              <Save className="h-4 w-4" />
              <span>Salvar Parâmetros dos Planos</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
