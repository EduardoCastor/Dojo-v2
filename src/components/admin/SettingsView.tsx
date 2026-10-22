import React, { useState } from 'react';
import { Settings, Save, ShieldAlert, Sparkles, Check, Clock, Upload, Image, Trash2, Building2 } from 'lucide-react';
import { Tenant, SaaSPlan } from '../../types';

interface SettingsViewProps {
  tenant: Tenant;
  plans: SaaSPlan[];
  onSaveTenant: (updatedTenant: Tenant) => void;
  onUpgradePlan: () => void;
}

export const SettingsView: React.FC<SettingsViewProps> = ({
  tenant,
  plans,
  onSaveTenant,
  onUpgradePlan,
}) => {
  const [tradeName, setTradeName] = useState(tenant.tradeName);
  const [legalName, setLegalName] = useState(tenant.legalName);
  const [cnpj, setCnpj] = useState(tenant.cnpjOrCpf);
  const [email, setEmail] = useState(tenant.email);
  const [phone, setPhone] = useState(tenant.phone);
  const [logoUrl, setLogoUrl] = useState(tenant.logoUrl || '');
  const [dueDay, setDueDay] = useState(tenant.settings?.defaultDueDay ?? 10);
  const [familyDiscount, setFamilyDiscount] = useState(tenant.settings?.familyDiscount2ndMember ?? 15);
  const [multiArtDiscount, setMultiArtDiscount] = useState(tenant.settings?.multiArtDiscount ?? 20);
  const [penaltyRate, setPenaltyRate] = useState(tenant.settings?.penaltyRate ?? 2);
  const [savedSuccess, setSavedSuccess] = useState(false);

  const currentPlan = plans.find(p => p.id === tenant.planId) || plans[0];

  const handleLogoFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 2 * 1024 * 1024) {
      alert('A imagem deve ter no máximo 2MB.');
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      setLogoUrl(reader.result as string);
    };
    reader.readAsDataURL(file);
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    const updated: Tenant = {
      ...tenant,
      tradeName,
      legalName,
      cnpjOrCpf: cnpj,
      email,
      phone,
      logoUrl: logoUrl || undefined,
      settings: {
        ...(tenant.settings || {}),
        defaultDueDay: Number(dueDay),
        familyDiscount2ndMember: Number(familyDiscount),
        multiArtDiscount: Number(multiArtDiscount),
        penaltyRate: Number(penaltyRate),
      },
    };
    onSaveTenant(updated);
    setSavedSuccess(true);
    setTimeout(() => setSavedSuccess(false), 3000);
  };

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Header */}
      <div>
        <h2 className="text-xl font-bold text-white tracking-tight">Configurações & Parâmetros do Dojo</h2>
        <p className="text-xs text-slate-400">
          Personalize as regras comerciais de desconto, dia padrão de vencimento e dados institucionais.
        </p>
      </div>

      {/* Plan Status Banner */}
      <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/60 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xs font-bold text-white">Plano Contratado: {currentPlan.name}</span>
            <span className="px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-950/60 text-emerald-400 border border-emerald-500/30">
              {tenant.status === 'trial' ? 'Em Período de Teste' : 'Assinatura Ativa'}
            </span>
          </div>
          <p className="text-xs text-slate-400">
            Limite: até {currentPlan.maxStudents} alunos e {currentPlan.maxBranches} filiais.
          </p>
        </div>

        <button
          onClick={onUpgradePlan}
          className="flex items-center gap-1.5 px-4 py-2 rounded-lg bg-red-600 hover:bg-red-500 text-white font-semibold text-xs shadow transition-colors cursor-pointer"
        >
          <Sparkles className="h-4 w-4" />
          <span>Trocar ou Contratar Plano</span>
        </button>
      </div>

      {savedSuccess && (
        <div className="p-3 rounded-lg bg-emerald-950/60 border border-emerald-500/40 text-emerald-300 text-xs flex items-center gap-2">
          <Check className="h-4 w-4 shrink-0 text-emerald-400" />
          <span>Configurações atualizadas com sucesso!</span>
        </div>
      )}

      <form onSubmit={handleSave} className="space-y-6 text-xs">
        {/* Dados Institucionais */}
        <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/60 space-y-4">
          <h3 className="text-xs font-bold text-white uppercase tracking-wider">
            1. Dados Cadastrais & Impressão de Recibos
          </h3>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-slate-300 font-medium mb-1">Nome Fantasia *</label>
              <input
                type="text"
                value={tradeName}
                onChange={(e) => setTradeName(e.target.value)}
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-medium mb-1">Razão Social</label>
              <input
                type="text"
                value={legalName}
                onChange={(e) => setLegalName(e.target.value)}
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
              />
            </div>
          </div>

          {/* Logomarca da Academia */}
          <div className="p-3.5 rounded-xl border border-slate-700/80 bg-slate-950/60 space-y-2">
            <div className="flex items-center justify-between">
              <label className="block text-slate-200 font-semibold text-xs flex items-center gap-1.5">
                <Image className="h-4 w-4 text-red-400" />
                <span>Logomarca Oficial do Dojo (aparece no cabeçalho dos relatórios)</span>
              </label>
              <span className="text-[10px] text-slate-400">PNG, JPG, SVG ou WebP</span>
            </div>

            <div className="flex items-center gap-4">
              <div className="h-16 w-16 rounded-xl border-2 border-dashed border-slate-700 bg-slate-900 flex items-center justify-center overflow-hidden shrink-0 shadow-inner">
                {logoUrl ? (
                  <img src={logoUrl} alt="Logo" className="h-full w-full object-contain p-1" />
                ) : (
                  <Building2 className="h-7 w-7 text-slate-600" />
                )}
              </div>

              <div className="flex-1 space-y-2">
                <div className="flex items-center gap-2">
                  <label className="cursor-pointer inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-600 text-xs font-medium text-slate-200 hover:text-white transition-colors shadow-sm">
                    <Upload className="h-3.5 w-3.5 text-red-400" />
                    <span>Upload de Logo</span>
                    <input
                      type="file"
                      accept="image/png,image/jpeg,image/webp,image/svg+xml"
                      onChange={handleLogoFileChange}
                      className="hidden"
                    />
                  </label>

                  {logoUrl && (
                    <button
                      type="button"
                      onClick={() => setLogoUrl('')}
                      className="p-1.5 rounded-lg border border-red-900/40 bg-red-950/40 text-red-400 hover:text-red-300 hover:bg-red-900/40 transition-colors"
                      title="Remover logotipo"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  )}
                </div>
                <input
                  type="text"
                  value={logoUrl.startsWith('data:') ? '' : logoUrl}
                  onChange={(e) => setLogoUrl(e.target.value)}
                  placeholder="Ou insira a URL da logomarca (https://...)"
                  className="w-full rounded-md border border-slate-700 bg-slate-800 px-2.5 py-1 text-xs text-white placeholder-slate-500 focus:border-red-500 focus:outline-none"
                />
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-slate-300 font-medium mb-1">CNPJ ou CPF</label>
              <input
                type="text"
                value={cnpj}
                onChange={(e) => setCnpj(e.target.value)}
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-medium mb-1">E-mail de Contato</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block text-slate-300 font-medium mb-1">Telefone Principal</label>
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
              />
            </div>
          </div>
        </div>

        {/* Políticas de Mensalidades & Descontos */}
        <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/60 space-y-4">
          <h3 className="text-xs font-bold text-white uppercase tracking-wider">
            2. Regras Comerciais & Descontos Familiares
          </h3>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <label className="block text-slate-300 font-medium mb-1">Dia Padrão de Vencimento</label>
              <input
                type="number"
                min="1"
                max="28"
                value={dueDay}
                onChange={(e) => setDueDay(Number(e.target.value))}
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Todo dia {dueDay} do mês</span>
            </div>

            <div>
              <label className="block text-slate-300 font-medium mb-1">Desconto Familiar (2º Membro)</label>
              <div className="relative">
                <input
                  type="number"
                  min="0"
                  max="50"
                  value={familyDiscount}
                  onChange={(e) => setFamilyDiscount(Number(e.target.value))}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
                <span className="absolute right-3 top-2 text-slate-400">%</span>
              </div>
              <span className="text-[10px] text-slate-500 mt-1 block">Para irmãos matriculados</span>
            </div>

            <div>
              <label className="block text-slate-300 font-medium mb-1">Desconto 2ª Modalidade</label>
              <div className="relative">
                <input
                  type="number"
                  min="0"
                  max="50"
                  value={multiArtDiscount}
                  onChange={(e) => setMultiArtDiscount(Number(e.target.value))}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
                <span className="absolute right-3 top-2 text-slate-400">%</span>
              </div>
              <span className="text-[10px] text-slate-500 mt-1 block">Ex: Judô + Jiu-Jitsu</span>
            </div>

            <div>
              <label className="block text-slate-300 font-medium mb-1">Multa por Atraso</label>
              <div className="relative">
                <input
                  type="number"
                  min="0"
                  max="10"
                  step="0.5"
                  value={penaltyRate}
                  onChange={(e) => setPenaltyRate(Number(e.target.value))}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
                <span className="absolute right-3 top-2 text-slate-400">%</span>
              </div>
              <span className="text-[10px] text-slate-500 mt-1 block">Conforme limites legais CDC</span>
            </div>
          </div>
        </div>

        <div className="flex justify-end">
          <button
            type="submit"
            className="flex items-center gap-2 px-5 py-2.5 rounded-lg bg-red-600 hover:bg-red-500 text-white font-semibold text-xs shadow transition-colors cursor-pointer"
          >
            <Save className="h-4 w-4" />
            <span>Salvar Configurações</span>
          </button>
        </div>
      </form>
    </div>
  );
};
