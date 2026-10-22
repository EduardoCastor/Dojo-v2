import React, { useState } from 'react';
import { Trophy, Plus, Medal, CheckCircle2, AlertTriangle, Users, MapPin, Calendar } from 'lucide-react';
import { Competition, CompetitionAthlete, Student, Person } from '../../types';
import { formatDateBR } from '../../utils/formatters';

interface CompetitionsViewProps {
  competitions: Competition[];
  athletes: CompetitionAthlete[];
  students: Student[];
  persons: Person[];
  onAddCompetition: (competition: Competition) => void;
  onAddAthlete: (athlete: CompetitionAthlete) => void;
}

export const CompetitionsView: React.FC<CompetitionsViewProps> = ({
  competitions,
  athletes,
  students,
  persons,
  onAddCompetition,
  onAddAthlete,
}) => {
  const [selectedCompId, setSelectedCompId] = useState<string>(competitions[0]?.id || '');
  const [isAddCompOpen, setIsAddCompOpen] = useState(false);

  // New Comp form
  const [title, setTitle] = useState('');
  const [organizer, setOrganizer] = useState('Federação Paulista de Judô (FPJ)');
  const [location, setLocation] = useState('Ginásio do Ibirapuera - São Paulo/SP');
  const [eventDate, setEventDate] = useState('2026-11-14');
  const [registrationDeadline, setRegistrationDeadline] = useState('2026-10-31');

  const activeComp = competitions.find(c => c.id === selectedCompId) || competitions[0];
  const compAthletes = athletes.filter(a => a.competitionId === activeComp?.id);

  const getAthleteName = (studentId: string) => {
    const student = students.find(s => s.id === studentId);
    const person = student ? persons.find(p => p.id === student.personId) : null;
    return person?.fullName || 'Atleta';
  };

  const handleCreateComp = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const newComp: Competition = {
      id: `comp-${Date.now()}`,
      tenantId: competitions[0]?.tenantId || 'tenant-kodokan',
      martialArtId: 'art-judo',
      title,
      organizer,
      location,
      eventDate,
      registrationDeadline,
      status: 'open',
    };

    onAddCompetition(newComp);
    setIsAddCompOpen(false);
    setTitle('');
  };

  // Medal stats
  const goldCount = athletes.filter(a => a.placement === 'gold').length;
  const silverCount = athletes.filter(a => a.placement === 'silver').length;
  const bronzeCount = athletes.filter(a => a.placement === 'bronze').length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-white tracking-tight">Competições & Alto Rendimento</h2>
          <p className="text-xs text-slate-400">
            Inscrição de atletas por categoria de peso, validação de documentação e quadro geral de medalhas.
          </p>
        </div>

        <button
          onClick={() => setIsAddCompOpen(true)}
          className="flex items-center gap-2 rounded-lg bg-red-600 px-4 py-2 text-xs font-semibold text-white hover:bg-red-500 transition-colors shadow cursor-pointer"
        >
          <Plus className="h-4 w-4" />
          <span>Cadastrar Torneio</span>
        </button>
      </div>

      {/* Medal Tally Strip */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 rounded-xl border border-amber-600/40 bg-amber-950/20 flex items-center justify-between">
          <div>
            <div className="text-xs text-amber-400 font-semibold uppercase tracking-wider">Ouro Conquistado</div>
            <div className="text-2xl font-bold text-white font-mono">{goldCount}</div>
          </div>
          <Medal className="h-8 w-8 text-amber-400" />
        </div>

        <div className="p-4 rounded-xl border border-slate-600/40 bg-slate-900/40 flex items-center justify-between">
          <div>
            <div className="text-xs text-slate-300 font-semibold uppercase tracking-wider">Prata Conquistada</div>
            <div className="text-2xl font-bold text-white font-mono">{silverCount}</div>
          </div>
          <Medal className="h-8 w-8 text-slate-300" />
        </div>

        <div className="p-4 rounded-xl border border-amber-800/40 bg-amber-950/10 flex items-center justify-between">
          <div>
            <div className="text-xs text-amber-600 font-semibold uppercase tracking-wider">Bronze Conquistado</div>
            <div className="text-2xl font-bold text-white font-mono">{bronzeCount}</div>
          </div>
          <Medal className="h-8 w-8 text-amber-600" />
        </div>
      </div>

      {/* Tournaments List & Details */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Tournament Selector */}
        <div className="space-y-3">
          <div className="text-xs font-bold text-slate-300 uppercase tracking-wider">Torneios Cadastrados</div>
          {competitions.map((c) => (
            <button
              key={c.id}
              onClick={() => setSelectedCompId(c.id)}
              className={`w-full text-left p-3.5 rounded-xl border transition-all cursor-pointer ${
                selectedCompId === c.id
                  ? 'border-red-500 bg-slate-900 shadow-md'
                  : 'border-slate-800 bg-slate-950/60 hover:bg-slate-900/60'
              }`}
            >
              <div className="flex items-center justify-between text-[10px] text-slate-400 mb-1">
                <span>{c.organizer}</span>
                <span
                  className={`px-1.5 py-0.5 rounded font-semibold ${
                    c.status === 'open'
                      ? 'bg-emerald-950/60 text-emerald-400'
                      : 'bg-slate-800 text-slate-400'
                  }`}
                >
                  {c.status === 'open' ? 'Inscrições Abertas' : 'Finalizado'}
                </span>
              </div>
              <div className="font-bold text-white text-xs">{c.title}</div>
              <div className="text-[11px] text-slate-400 mt-1 flex items-center gap-2">
                <Calendar className="h-3 w-3 text-red-500" />
                <span>{formatDateBR(c.eventDate)}</span>
              </div>
            </button>
          ))}
        </div>

        {/* Selected Tournament Athletes Table */}
        <div className="lg:col-span-2 rounded-xl border border-slate-800 bg-slate-900/60 p-5">
          {activeComp ? (
            <div>
              <div className="flex items-start justify-between gap-4 border-b border-slate-800 pb-4 mb-4">
                <div>
                  <h3 className="text-base font-bold text-white">{activeComp.title}</h3>
                  <div className="text-xs text-slate-400 mt-0.5">
                    {activeComp.location} · Organização: {activeComp.organizer}
                  </div>
                </div>
                <div className="text-right text-[11px] text-slate-400">
                  Prazo de Inscrição: <strong className="text-slate-200">{formatDateBR(activeComp.registrationDeadline)}</strong>
                </div>
              </div>

              <div className="text-xs font-bold text-slate-300 mb-3 flex items-center justify-between">
                <span>Atletas da Academia Inscritos ({compAthletes.length})</span>
                <span className="text-[11px] text-slate-400 font-normal">Validação de atestado e categoria</span>
              </div>

              <div className="divide-y divide-slate-800">
                {compAthletes.length === 0 ? (
                  <div className="py-6 text-center text-slate-500 text-xs">
                    Nenhum atleta inscrito neste torneio ainda.
                  </div>
                ) : (
                  compAthletes.map((ath) => (
                    <div key={ath.id} className="py-3 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                      <div>
                        <div className="font-bold text-white text-xs">{ath.studentName}</div>
                        <div className="text-[11px] text-slate-400">
                          {ath.category} · Categoria de Peso: <strong className="text-slate-200">{ath.weightCategory}</strong>
                        </div>
                        {ath.notes && (
                          <div className="text-[10px] text-slate-400 mt-0.5 italic">{ath.notes}</div>
                        )}
                      </div>

                      <div className="flex items-center gap-3">
                        <span
                          className={`flex items-center gap-1 text-[10px] font-semibold px-2 py-0.5 rounded ${
                            ath.docsValidated
                              ? 'bg-emerald-950/60 text-emerald-400 border border-emerald-500/30'
                              : 'bg-amber-950/60 text-amber-400 border border-amber-500/30'
                          }`}
                        >
                          <CheckCircle2 className="h-3 w-3" />
                          <span>{ath.docsValidated ? 'Docs OK' : 'Docs Pendentes'}</span>
                        </span>

                        {ath.placement && ath.placement !== 'none' && (
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-slate-800 text-amber-400 border border-amber-500/30 uppercase">
                            Medalha de {ath.placement === 'silver' ? 'Prata' : ath.placement === 'gold' ? 'Ouro' : 'Bronze'}
                          </span>
                        )}
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          ) : (
            <div className="p-8 text-center text-slate-500">Selecione uma competição.</div>
          )}
        </div>
      </div>

      {/* Add Tournament Modal */}
      {isAddCompOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="relative w-full max-w-md rounded-2xl border border-slate-700 bg-slate-900 p-6 shadow-2xl text-slate-200">
            <h3 className="text-base font-bold text-white mb-3">Cadastrar Competição Esportiva</h3>

            <form onSubmit={handleCreateComp} className="space-y-3 text-xs">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Nome do Torneio *</label>
                <input
                  type="text"
                  required
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Ex: Campeonato Metropolitano de Judô"
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Entidade Organizadora</label>
                <input
                  type="text"
                  value={organizer}
                  onChange={(e) => setOrganizer(e.target.value)}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Local do Evento</label>
                <input
                  type="text"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Data da Competição</label>
                  <input
                    type="date"
                    value={eventDate}
                    onChange={(e) => setEventDate(e.target.value)}
                    className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Prazo de Inscrição</label>
                  <input
                    type="date"
                    value={registrationDeadline}
                    onChange={(e) => setRegistrationDeadline(e.target.value)}
                    className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsAddCompOpen(false)}
                  className="px-3 py-2 rounded-lg border border-slate-700 bg-slate-800 text-slate-300 hover:text-white"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-red-600 font-semibold text-white hover:bg-red-500"
                >
                  Salvar Competição
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
