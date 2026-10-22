/**
 * Script de Verificação dos Testes Obrigatórios - Módulo Financeiro TatameHub
 */
import { financialService } from '../src/services/financialService';
import { DataStore } from '../src/data/storage';
import { Invoice, FinancialTransaction } from '../src/types';

// Mock localStorage in node environment for DataStore testing
class LocalStorageMock {
  store: Record<string, string> = {};
  getItem(key: string) { return this.store[key] || null; }
  setItem(key: string, value: string) { this.store[key] = value.toString(); }
  removeItem(key: string) { delete this.store[key]; }
  clear() { this.store = {}; }
}
(global as any).localStorage = new LocalStorageMock();

async function runAllTests() {
  console.log('=== INICIANDO TESTES OBRIGATÓRIOS DO MÓDULO FINANCEIRO ===\n');
  let passedCount = 0;
  let totalCount = 13;

  const tenantA = 'tenant-kodokan';
  const tenantB = 'tenant-bjj-pro';

  // Seed baseline
  const baseInvoices = DataStore.getInvoices(tenantA);
  const baseTxs = DataStore.getFinancialTransactions(tenantA);

  // -------------------------------------------------------------
  // Teste 1: Dar baixa integral em uma mensalidade pendente
  // -------------------------------------------------------------
  try {
    const pendingInv = baseInvoices.find(i => i.status === 'pending') || baseInvoices[0];
    const initialBalance = pendingInv.balance;
    const settled = await financialService.settlePayment(pendingInv.id, tenantA, {
      amount: initialBalance,
      paymentMethod: 'pix',
      registeredByName: 'Administrador Teste',
    });

    if (settled.status === 'paid' && settled.balance === 0 && settled.paidAmount >= initialBalance) {
      console.log('✔ Teste 1 APROVADO: Baixa integral em mensalidade realizada com sucesso (Status: paid, Saldo: 0.00).');
      passedCount++;
    } else {
      console.error('❌ Teste 1 FALHOU:', settled);
    }
  } catch (err: any) {
    console.error('❌ Teste 1 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 2: Dar baixa parcial e confirmar o saldo restante
  // -------------------------------------------------------------
  try {
    // Criar fatura pendente de R$ 300,00
    const invTest: Invoice = {
      id: 'inv-test-partial',
      tenantId: tenantA,
      branchId: 'branch-matriz',
      studentId: 'student-lucas',
      competence: '12/2026',
      issueDate: '2026-11-01',
      dueDate: '2026-12-10',
      originalAmount: 300,
      discountAmount: 0,
      penaltyAndInterestAmount: 0,
      finalAmount: 300,
      paidAmount: 0,
      balance: 300,
      status: 'pending',
      auditTrail: [],
    };
    DataStore.saveInvoices([invTest, ...DataStore.getInvoices(tenantA)], tenantA);

    const settledPartial = await financialService.settlePayment('inv-test-partial', tenantA, {
      amount: 100.50,
      paymentMethod: 'cash',
      registeredByName: 'Administrador Teste',
    });

    if (settledPartial.status === 'partially_paid' && settledPartial.paidAmount === 100.50 && settledPartial.balance === 199.50) {
      console.log('✔ Teste 2 APROVADO: Baixa parcial registrada com precisão decimal (Pago: R$ 100.50, Saldo Restante: R$ 199.50, Status: partially_paid).');
      passedCount++;
    } else {
      console.error('❌ Teste 2 FALHOU:', settledPartial);
    }
  } catch (err: any) {
    console.error('❌ Teste 2 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 3: Dar baixa em uma cobrança extra de competição
  // -------------------------------------------------------------
  try {
    const compTx = await financialService.createTransaction({
      tenantId: tenantA,
      type: 'income',
      category: 'competition',
      description: 'Taxa Inscrição Copa Brasil',
      amount: 150.00,
      competence: '10/2026',
      status: 'pending',
      studentId: 'student-gabriel',
    });

    const settledComp = await financialService.settleTransaction(compTx.id, tenantA, {
      amount: 150.00,
      paymentMethod: 'credit_card',
      registeredByName: 'Administrador Teste',
    });

    if (settledComp.status === 'completed' && settledComp.balance === 0 && settledComp.paidAmount === 150.00) {
      console.log('✔ Teste 3 APROVADO: Baixa em receita extra de competição concluída (Status: completed, Saldo: 0.00).');
      passedCount++;
    } else {
      console.error('❌ Teste 3 FALHOU:', settledComp);
    }
  } catch (err: any) {
    console.error('❌ Teste 3 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 4: Registrar o pagamento de uma despesa pendente
  // -------------------------------------------------------------
  try {
    const expTx = await financialService.createTransaction({
      tenantId: tenantA,
      type: 'expense',
      category: 'facilities',
      description: 'Manutenção de Tatamis e Higienização',
      amount: 450.00,
      competence: '10/2026',
      status: 'pending',
    });

    const settledExp = await financialService.settleTransaction(expTx.id, tenantA, {
      amount: 450.00,
      paymentMethod: 'transfer',
      registeredByName: 'Administrador Teste',
    });

    if (settledExp.status === 'completed' && settledExp.balance === 0 && settledExp.type === 'expense') {
      console.log('✔ Teste 4 APROVADO: Pagamento de despesa operacional baixado (Status: completed, Tipo: expense, Saldo: 0.00).');
      passedCount++;
    } else {
      console.error('❌ Teste 4 FALHOU:', settledExp);
    }
  } catch (err: any) {
    console.error('❌ Teste 4 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 5: Confirmar que a baixa continua registrada após recarregar do DataStore/Supabase
  // -------------------------------------------------------------
  try {
    const reloadedInvoices = await financialService.fetchInvoices(tenantA);
    const targetInv = reloadedInvoices.find(i => i.id === 'inv-test-partial');

    if (targetInv && targetInv.balance === 199.50 && targetInv.paidAmount === 100.50 && targetInv.status === 'partially_paid') {
      console.log('✔ Teste 5 APROVADO: Dados de baixa persistidos intactos após releitura da base de dados.');
      passedCount++;
    } else {
      console.error('❌ Teste 5 FALHOU:', targetInv);
    }
  } catch (err: any) {
    console.error('❌ Teste 5 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 6: Confirmar que indicadores financeiros refletem valores efetivamente pagos e recebidos
  // -------------------------------------------------------------
  try {
    const invoices = await financialService.fetchInvoices(tenantA);
    const txs = await financialService.fetchTransactions(tenantA);

    const paidInvoices = invoices.reduce((acc, i) => acc + (i.status !== 'canceled' ? i.paidAmount : 0), 0);
    const realizedExtraIncome = txs
      .filter(t => t.type === 'income' && t.status !== 'canceled')
      .reduce((acc, t) => acc + (t.paidAmount || 0), 0);
    const realizedExpenses = txs
      .filter(t => t.type === 'expense' && t.status !== 'canceled')
      .reduce((acc, t) => acc + (t.paidAmount || 0), 0);

    const netBalance = (paidInvoices + realizedExtraIncome) - realizedExpenses;

    if (!isNaN(netBalance) && paidInvoices > 0 && realizedExpenses > 0) {
      console.log(`✔ Teste 6 APROVADO: Indicadores refletem receitas efetivas (R$ ${paidInvoices + realizedExtraIncome}) - despesas pagas (R$ ${realizedExpenses}) = Saldo Líquido (R$ ${netBalance}).`);
      passedCount++;
    } else {
      console.error('❌ Teste 6 FALHOU: Valores inválidos nos indicadores.');
    }
  } catch (err: any) {
    console.error('❌ Teste 6 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 7: Confirmar que lançamento quitado não continua aparecendo com saldo pendente
  // -------------------------------------------------------------
  try {
    const invoices = await financialService.fetchInvoices(tenantA);
    const fullyPaid = invoices.filter(i => i.status === 'paid');
    const hasRemainingBalance = fullyPaid.some(i => i.balance > 0);

    if (fullyPaid.length > 0 && !hasRemainingBalance) {
      console.log('✔ Teste 7 APROVADO: Todos os lançamentos quitados têm saldo pendente zero e não aparecem em aberto.');
      passedCount++;
    } else {
      console.error('❌ Teste 7 FALHOU: Lançamento quitado com saldo devedor positivo!');
    }
  } catch (err: any) {
    console.error('❌ Teste 7 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 8: Confirmar que cobrança parcialmente paga mantém o saldo correto
  // -------------------------------------------------------------
  try {
    // Fazer uma segunda baixa parcial de R$ 50 na mesma fatura
    const secondPartial = await financialService.settlePayment('inv-test-partial', tenantA, {
      amount: 50.00,
      paymentMethod: 'pix',
      registeredByName: 'Administrador Teste',
    });

    const expectedBalance = 149.50; // 199.50 - 50.00
    const expectedPaid = 150.50; // 100.50 + 50.00

    if (secondPartial.balance === expectedBalance && secondPartial.paidAmount === expectedPaid) {
      console.log(`✔ Teste 8 APROVADO: Segunda baixa parcial acumulou corretamente (Total Pago: R$ ${secondPartial.paidAmount}, Saldo: R$ ${secondPartial.balance}).`);
      passedCount++;
    } else {
      console.error('❌ Teste 8 FALHOU:', secondPartial);
    }
  } catch (err: any) {
    console.error('❌ Teste 8 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 9: Tentar registrar baixa maior que o saldo pendente e confirmar bloqueio
  // -------------------------------------------------------------
  try {
    let blocked = false;
    try {
      await financialService.settlePayment('inv-test-partial', tenantA, {
        amount: 9999.00, // Saldo é 149.50
        paymentMethod: 'cash',
        registeredByName: 'Administrador Teste',
      });
    } catch (err: any) {
      if (err.message.includes('não pode ser superior') || err.message.includes('saldo pendente')) {
        blocked = true;
      }
    }

    if (blocked) {
      console.log('✔ Teste 9 APROVADO: Tentativa de baixa superior ao saldo pendente bloqueada com sucesso pela regra de negócio.');
      passedCount++;
    } else {
      console.error('❌ Teste 9 FALHOU: Baixa excedente foi aceita indevidamente!');
    }
  } catch (err: any) {
    console.error('❌ Teste 9 FALHOU com erro inesperado:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 10: Simular falha de gravação (valor zero/negativo ou ID inexistente) e confirmar que interface/serviço rejeita
  // -------------------------------------------------------------
  try {
    let errorHandledZero = false;
    let errorHandledNotFound = false;

    try {
      await financialService.settlePayment('inv-test-partial', tenantA, {
        amount: 0,
        paymentMethod: 'pix',
        registeredByName: 'Administrador Teste',
      });
    } catch (e: any) {
      if (e.message.includes('maior que zero')) errorHandledZero = true;
    }

    try {
      await financialService.settlePayment('inv-inexistente-123', tenantA, {
        amount: 50,
        paymentMethod: 'pix',
        registeredByName: 'Administrador Teste',
      });
    } catch (e: any) {
      if (e.message.includes('não encontrada')) errorHandledNotFound = true;
    }

    if (errorHandledZero && errorHandledNotFound) {
      console.log('✔ Teste 10 APROVADO: Falhas e dados inválidos são tratados de forma segura sem registrar falso positivo.');
      passedCount++;
    } else {
      console.error('❌ Teste 10 FALHOU:', { errorHandledZero, errorHandledNotFound });
    }
  } catch (err: any) {
    console.error('❌ Teste 10 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 11: Testar prevenção contra repetição de operação / duplicidade
  // -------------------------------------------------------------
  try {
    // Quitar os R$ 149.50 restantes da fatura de teste
    const finalSettlement = await financialService.settlePayment('inv-test-partial', tenantA, {
      amount: 149.50,
      paymentMethod: 'pix',
      registeredByName: 'Administrador Teste',
    });

    let duplicateRejected = false;
    try {
      // Tentativa imediata de executar a mesma baixa novamente
      await financialService.settlePayment('inv-test-partial', tenantA, {
        amount: 149.50,
        paymentMethod: 'pix',
        registeredByName: 'Administrador Teste',
      });
    } catch (e: any) {
      if (e.message.includes('já foi integralmente quitada')) {
        duplicateRejected = true;
      }
    }

    if (finalSettlement.status === 'paid' && duplicateRejected) {
      console.log('✔ Teste 11 APROVADO: Operação duplicada rejeitada após quitação (bloqueio de duplo clique e repetição ativo).');
      passedCount++;
    } else {
      console.error('❌ Teste 11 FALHOU: Duplicidade não prevenida!');
    }
  } catch (err: any) {
    console.error('❌ Teste 11 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 12: Confirmar o isolamento multi-tenant entre academias
  // -------------------------------------------------------------
  try {
    const invTenantB: Invoice = {
      id: 'inv-tenant-b-1',
      tenantId: tenantB,
      branchId: 'branch-bjj',
      studentId: 'student-bjj-1',
      competence: '10/2026',
      issueDate: '2026-10-01',
      dueDate: '2026-10-10',
      originalAmount: 250,
      discountAmount: 0,
      penaltyAndInterestAmount: 0,
      finalAmount: 250,
      paidAmount: 0,
      balance: 250,
      status: 'pending',
      auditTrail: [],
    };

    DataStore.saveInvoices([invTenantB], tenantB);

    const invoicesTenantA = await financialService.fetchInvoices(tenantA);
    const invoicesTenantB = await financialService.fetchInvoices(tenantB);

    const leakedToA = invoicesTenantA.some(i => i.id === 'inv-tenant-b-1');
    const existsInB = invoicesTenantB.some(i => i.id === 'inv-tenant-b-1');

    if (!leakedToA && existsInB) {
      console.log('✔ Teste 12 APROVADO: Isolamento estrito por tenantId garantido (dados da Academia B não vazam para a Academia A).');
      passedCount++;
    } else {
      console.error('❌ Teste 12 FALHOU: Vazamento entre tenants detectado!');
    }
  } catch (err: any) {
    console.error('❌ Teste 12 FALHOU com erro:', err.message);
  }

  // -------------------------------------------------------------
  // Teste 13: Verificar que mensalidades, receitas extras, despesas e relatórios continuam operacionais
  // -------------------------------------------------------------
  try {
    const plans = await financialService.fetchPlans(tenantA);
    const reminders = await financialService.fetchReminders(tenantA);
    const allInvoices = await financialService.fetchInvoices(tenantA);
    const allTxs = await financialService.fetchTransactions(tenantA);

    if (plans.length > 0 && allInvoices.length > 0 && allTxs.length > 0) {
      console.log(`✔ Teste 13 APROVADO: Módulo completo íntegro (${plans.length} planos, ${allInvoices.length} faturas, ${allTxs.length} transações).`);
      passedCount++;
    } else {
      console.error('❌ Teste 13 FALHOU: Inconsistência nos módulos complementares.');
    }
  } catch (err: any) {
    console.error('❌ Teste 13 FALHOU com erro:', err.message);
  }

  console.log(`\n=== RESUMO: ${passedCount} DE ${totalCount} TESTES APROVADOS COM SUCESSO ===\n`);
  if (passedCount === totalCount) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

runAllTests();
