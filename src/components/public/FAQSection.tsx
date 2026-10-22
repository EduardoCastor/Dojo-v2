import React, { useState } from 'react';
import { ChevronDown } from 'lucide-react';

export const FAQSection: React.FC = () => {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  const faqs = [
    {
      q: 'Como funciona o período de teste gratuito de 10 dias?',
      a: 'Ao cadastrar sua academia, você tem acesso imediato a todas as funcionalidades do Plano Avançado durante 10 dias corridos, sem necessidade de cartão de crédito. Uma contagem regressiva é exibida no topo do painel. Após o 10º dia, novas operações de cadastro são bloqueadas, mas seus dados permanecem preservados por 60 dias para contratação.',
    },
    {
      q: 'O sistema suporta as faixas e regras oficiais da CBJ, CBJJ e outras federações?',
      a: 'Sim! As regras de graduação não são fixadas no código. O sistema traz modelos iniciais recomendados baseados nas normas da Confederação Brasileira de Judô (CBJ) e CBJJ, mas cada academia pode personalizar carências de tempo, idades mínimas e requisitos técnicos.',
    },
    {
      q: 'Como a plataforma lida com dados de menores e atestados de saúde (LGPD)?',
      a: 'Adotamos padrões rigorosos da LGPD: separação entre responsáveis legais, responsáveis financeiros e contatos de emergência. A seção de saúde e documentos médicos possui permissões restritas e trilha de auditoria completa.',
    },
    {
      q: 'Posso cadastrar irmãos com desconto familiar na mensalidade?',
      a: 'Sim. O sistema permite unificar o responsável financeiro familiar e aplicar políticas de desconto parametrizáveis (ex: 15% de desconto para o 2º dependente), evitando aplicações duplicadas ou indevidas de benefícios.',
    },
    {
      q: 'Como funciona a validação anti-conflito de horários de turmas?',
      a: 'Caso a secretaria tente matricular um aluno em uma turma cujo horário e dias colidam com outra turma em que ele já está ativo, o sistema alerta e bloqueia a sobreposição. Também é validada a lotação máxima do tatami para garantir a segurança dos praticantes.',
    },
    {
      q: 'Os alunos e pais conseguem acessar pelo celular?',
      a: 'Sim. A plataforma é uma Progressive Web App (PWA) totalmente responsiva para smartphones e computadores, com portais dedicados onde os responsáveis acompanham presenças, mensalidades com código PIX e histórico de graduações.',
    },
  ];

  return (
    <section id="faq" className="py-20 border-b border-slate-800 bg-slate-950">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12">
          <div className="text-xs font-semibold text-red-500 uppercase tracking-wider mb-2">Tire suas Dúvidas</div>
          <h2 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
            Perguntas Frequentes
          </h2>
          <p className="mt-2 text-sm text-slate-400">
            Respostas claras sobre conformidade, regras esportivas e operação do sistema.
          </p>
        </div>

        <div className="space-y-3">
          {faqs.map((faq, index) => {
            const isOpen = openIndex === index;
            return (
              <div
                key={index}
                className="rounded-xl border border-slate-800/80 bg-slate-900/50 overflow-hidden transition-colors"
              >
                <button
                  onClick={() => setOpenIndex(isOpen ? null : index)}
                  className="flex w-full items-center justify-between p-5 text-left text-sm font-semibold text-white hover:text-red-400 transition-colors cursor-pointer"
                >
                  <span>{faq.q}</span>
                  <ChevronDown
                    className={`h-4 w-4 text-slate-400 transition-transform duration-200 shrink-0 ml-4 ${
                      isOpen ? 'rotate-180 text-red-500' : ''
                    }`}
                  />
                </button>
                {isOpen && (
                  <div className="px-5 pb-5 text-xs text-slate-300 leading-relaxed border-t border-slate-800/50 pt-3">
                    {faq.a}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};
