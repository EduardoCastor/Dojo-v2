import React, { useState } from 'react';
import { BookOpen, Video, FileText, Plus, Search, Eye, Lock, Shield, Check } from 'lucide-react';
import { DigitalLibraryItem, BeltRank } from '../../types';
import { formatDateBR } from '../../utils/formatters';

interface DigitalLibraryViewProps {
  libraryItems: DigitalLibraryItem[];
  beltRanks: BeltRank[];
  onAddLibraryItem: (item: DigitalLibraryItem) => void;
}

export const DigitalLibraryView: React.FC<DigitalLibraryViewProps> = ({
  libraryItems,
  beltRanks,
  onAddLibraryItem,
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<string>('all');
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [activeItem, setActiveItem] = useState<DigitalLibraryItem | null>(null);

  // New item form
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState<DigitalLibraryItem['category']>('waza_techniques');
  const [mediaType, setMediaType] = useState<'video' | 'pdf' | 'document'>('video');
  const [mediaUrl, setMediaUrl] = useState('');
  const [description, setDescription] = useState('');
  const [accessScope, setAccessScope] = useState<'tenant_all' | 'restricted_belt'>('tenant_all');

  const filteredItems = libraryItems.filter((item) => {
    const matchesSearch =
      item.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.description.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = categoryFilter === 'all' || item.category === categoryFilter;
    return matchesSearch && matchesCategory;
  });

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const newItem: DigitalLibraryItem = {
      id: `lib-${Date.now()}`,
      tenantId: libraryItems[0]?.tenantId || 'tenant-kodokan',
      title,
      category,
      mediaType,
      mediaUrl: mediaUrl || '#conteudo-educacional',
      description,
      martialArtId: 'art-judo',
      martialArtName: 'Judô',
      targetBeltNames: ['Faixa Branca', 'Faixa Azul', 'Faixa Amarela'],
      authorInstructor: 'Comissão Técnica',
      publishedDate: new Date().toISOString().split('T')[0],
      accessScope,
      viewCount: 1,
    };

    onAddLibraryItem(newItem);
    setIsAddOpen(false);
    setTitle('');
    setDescription('');
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-white tracking-tight">Biblioteca Digital de Artes Marciais</h2>
          <p className="text-xs text-slate-400">
            Repositório de videoaulas técnicas, apostilas de kata, regras oficiais e materiais para exames de faixa.
          </p>
        </div>

        <button
          onClick={() => setIsAddOpen(true)}
          className="flex items-center gap-2 rounded-lg bg-red-600 px-4 py-2 text-xs font-semibold text-white hover:bg-red-500 transition-colors shadow cursor-pointer"
        >
          <Plus className="h-4 w-4" />
          <span>Publicar Material Técnico</span>
        </button>
      </div>

      {/* Featured Banner with generated technique illustration */}
      <div className="relative rounded-2xl overflow-hidden border border-slate-800 bg-slate-900/60 p-6 flex flex-col md:flex-row items-center gap-6">
        <div className="w-full md:w-1/3 rounded-xl overflow-hidden border border-slate-700/80 shadow">
          <img
            src="/src/assets/images/martial_arts_technique_1792068010372.jpg"
            alt="Treinamento Técnico de Judô e Kumi-Kata"
            className="w-full h-44 object-cover"
            referrerPolicy="no-referrer"
          />
        </div>
        <div className="flex-1 space-y-2">
          <span className="text-[10px] font-bold uppercase tracking-wider text-red-400 bg-red-950/60 border border-red-500/30 px-2.5 py-0.5 rounded-full">
            Destaque Pedagógico
          </span>
          <h3 className="text-base font-bold text-white">
            Gokyo no Waza & Sequências de Exame 2026
          </h3>
          <p className="text-xs text-slate-300 leading-relaxed max-w-xl">
            Apostilas completas com os princípios de kuzushi (desequilíbrio), tsukuri (encaixe) e kake (finalização), além de videoaulas gravadas pelos Senseis para estudo prévio dos alunos candidatos a exame.
          </p>
          <div className="flex items-center gap-4 text-[11px] text-slate-400 pt-2">
            <span>4 Categorias didáticas</span>
            <span>·</span>
            <span>Acesso liberado no Portal do Aluno</span>
          </div>
        </div>
      </div>

      {/* Search and Category Filters */}
      <div className="flex flex-col sm:flex-row items-center gap-3">
        <div className="relative flex-1 w-full">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-500" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Pesquisar técnicas, apostilas, kata ou regras..."
            className="w-full rounded-lg border border-slate-800 bg-slate-900 pl-9 pr-3 py-2 text-xs text-white placeholder-slate-500 focus:border-red-500 focus:outline-none"
          />
        </div>

        <div className="flex items-center gap-1 p-1 bg-slate-900 border border-slate-800 rounded-lg text-xs overflow-x-auto">
          {[
            { id: 'all', label: 'Todos' },
            { id: 'kata', label: 'Kata' },
            { id: 'waza_techniques', label: 'Técnicas (Waza)' },
            { id: 'rules_referee', label: 'Arbitragem' },
            { id: 'physical_prep', label: 'Prep. Física' },
          ].map((cat) => (
            <button
              key={cat.id}
              onClick={() => setCategoryFilter(cat.id)}
              className={`px-3 py-1.5 rounded-md font-medium whitespace-nowrap cursor-pointer transition-colors ${
                categoryFilter === cat.id ? 'bg-slate-800 text-white' : 'text-slate-400 hover:text-white'
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>
      </div>

      {/* Grid of Materials */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {filteredItems.map((item) => {
          const isVideo = item.mediaType === 'video';

          return (
            <div
              key={item.id}
              className="flex flex-col justify-between rounded-xl border border-slate-800 bg-slate-900/60 p-5 hover:border-slate-700 transition-all group"
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-800 border border-slate-700 text-red-400">
                      {isVideo ? <Video className="h-4 w-4" /> : <FileText className="h-4 w-4" />}
                    </div>
                    <span className="text-[11px] font-semibold text-slate-300 capitalize">
                      {item.category.replace('_', ' ')}
                    </span>
                  </div>

                  {item.accessScope === 'restricted_belt' ? (
                    <span className="flex items-center gap-1 text-[10px] text-amber-400 bg-amber-950/60 px-2 py-0.5 rounded border border-amber-500/30">
                      <Lock className="h-3 w-3" />
                      <span>Faixas Específicas</span>
                    </span>
                  ) : (
                    <span className="text-[10px] text-emerald-400 bg-emerald-950/60 px-2 py-0.5 rounded border border-emerald-500/30">
                      Geral
                    </span>
                  )}
                </div>

                <h3 className="text-sm font-bold text-white mb-1.5 group-hover:text-red-400 transition-colors">
                  {item.title}
                </h3>
                <p className="text-xs text-slate-400 line-clamp-2 mb-3">
                  {item.description}
                </p>

                {item.targetBeltNames && item.targetBeltNames.length > 0 && (
                  <div className="flex flex-wrap gap-1 mb-3">
                    {item.targetBeltNames.map((bn, i) => (
                      <span key={i} className="text-[10px] px-1.5 py-0.5 rounded bg-slate-800 text-slate-300 border border-slate-700">
                        {bn}
                      </span>
                    ))}
                  </div>
                )}
              </div>

              <div className="pt-3 border-t border-slate-800 flex items-center justify-between text-[11px] text-slate-400">
                <span>Por {item.authorInstructor}</span>
                <button
                  onClick={() => setActiveItem(item)}
                  className="flex items-center gap-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white transition-colors cursor-pointer"
                >
                  <Eye className="h-3.5 w-3.5" />
                  <span>Acessar</span>
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Viewer Modal */}
      {activeItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="relative w-full max-w-2xl rounded-2xl border border-slate-700 bg-slate-900 p-6 shadow-2xl text-slate-200">
            <button
              onClick={() => setActiveItem(null)}
              className="absolute top-4 right-4 p-1 text-slate-400 hover:text-white"
            >
              ✕
            </button>

            <div className="flex items-center gap-2 mb-2">
              <span className="text-[10px] font-bold uppercase tracking-wider text-red-400 bg-red-950/60 px-2 py-0.5 rounded border border-red-500/30">
                {activeItem.category.replace('_', ' ')}
              </span>
              <span className="text-xs text-slate-400">Publicado em {formatDateBR(activeItem.publishedDate)}</span>
            </div>

            <h3 className="text-lg font-bold text-white mb-2">{activeItem.title}</h3>
            <p className="text-xs text-slate-300 mb-4">{activeItem.description}</p>

            <div className="p-6 rounded-xl border border-slate-800 bg-slate-950 flex flex-col items-center justify-center text-center my-4">
              {activeItem.mediaType === 'video' ? (
                <div className="space-y-3">
                  <div className="w-16 h-16 rounded-full bg-red-600/20 text-red-500 flex items-center justify-center mx-auto border border-red-500/30">
                    <Video className="h-8 w-8" />
                  </div>
                  <div className="text-xs text-slate-300 font-semibold">Videoaula Técnica Disponibilizada</div>
                  <div className="text-[11px] text-slate-500 max-w-md">
                    Vídeo gravado no dojo central pelo instrutor {activeItem.authorInstructor}.
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  <div className="w-16 h-16 rounded-full bg-blue-600/20 text-blue-500 flex items-center justify-center mx-auto border border-blue-500/30">
                    <FileText className="h-8 w-8" />
                  </div>
                  <div className="text-xs text-slate-300 font-semibold">Apostila Digital em PDF</div>
                  <div className="text-[11px] text-slate-500 max-w-md">
                    Documento de estudo com diagramas de pegadas (kumi-kata) e passos de movimentação (tai-sabaki).
                  </div>
                </div>
              )}
            </div>

            <div className="flex justify-end pt-2">
              <button
                onClick={() => setActiveItem(null)}
                className="px-4 py-2 rounded-lg bg-slate-800 text-xs font-semibold text-white hover:bg-slate-700"
              >
                Fechar Visualizador
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Item Modal */}
      {isAddOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="relative w-full max-w-lg rounded-2xl border border-slate-700 bg-slate-900 p-6 shadow-2xl text-slate-200">
            <h3 className="text-base font-bold text-white mb-3">Publicar Material Educacional</h3>

            <form onSubmit={handleCreate} className="space-y-3 text-xs">
              <div>
                <label className="block text-slate-300 font-medium mb-1">Título do Conteúdo *</label>
                <input
                  type="text"
                  required
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Ex: Ippon-Seoi-Nage: Mecânica de Alavanca"
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-300 font-medium mb-1">Categoria Pedagógica</label>
                  <select
                    value={category}
                    onChange={(e) => setCategory(e.target.value as any)}
                    className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                  >
                    <option value="kata">Kata Tradicional</option>
                    <option value="waza_techniques">Técnicas (Waza)</option>
                    <option value="rules_referee">Regulamento & Arbitragem</option>
                    <option value="physical_prep">Preparação Física</option>
                    <option value="philosophy_history">História & Filosofia</option>
                  </select>
                </div>

                <div>
                  <label className="block text-slate-300 font-medium mb-1">Formato do Material</label>
                  <select
                    value={mediaType}
                    onChange={(e) => setMediaType(e.target.value as any)}
                    className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                  >
                    <option value="video">Vídeo / Videoaula</option>
                    <option value="pdf">Documento PDF / Apostila</option>
                    <option value="document">Texto Orientativo</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Nível de Acesso</label>
                <select
                  value={accessScope}
                  onChange={(e) => setAccessScope(e.target.value as any)}
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                >
                  <option value="tenant_all">Liberado para Todos os Alunos</option>
                  <option value="restricted_belt">Exclusivo para Faixas Específicas</option>
                </select>
              </div>

              <div>
                <label className="block text-slate-300 font-medium mb-1">Descrição & Diretrizes de Estudo</label>
                <textarea
                  rows={3}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Explique o objetivo didático deste conteúdo..."
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-white focus:border-red-500 focus:outline-none"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsAddOpen(false)}
                  className="px-3 py-2 rounded-lg border border-slate-700 bg-slate-800 text-slate-300 hover:text-white"
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg bg-red-600 font-semibold text-white hover:bg-red-500"
                >
                  Publicar Material
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
