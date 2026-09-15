-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
--
--  Regra geral: a limpeza dos dados fica nas dimensoes; a fato apenas procura a
--  linha correta (por JOIN). Nenhuma FK fica nula: quando o dado falta, ela
--  aponta para a linha -1 (CASE WHEN ... IS NULL THEN -1).
--
--  Sugestao: comece pelo esqueleto (numero_pedido + as duas FKs de tempo +
--  FROM), rode e confira 4.044 linhas; depois acrescente as colunas aos poucos.
-- =====================================================================================

USE dw_pata_amiga;

INSERT INTO fato_pedido (
    numero_pedido,
    sk_tempo_pedido, sk_tempo_entrega,
    sk_loja, sk_categoria,
    houve_desconto, canal_pedido, dt_pedido,
    qt_itens, vl_liquido,
    dias_integracao_separacao, dias_separacao_nota, dias_nota_despacho,
    dias_despacho_entrega, dias_total_ate_entrega
)
SELECT
    p.`NumeroPedido` AS numero_pedido,

    -- ---- FKs de tempo (dois papeis da MESMA dim_tempo: role-playing) ----
    -- Data do pedido: formato AMERICANO com AM/PM. A mascara '%m/%d/%Y %h:%i %p'
    -- devolve 4044 datas validas; a brasileira devolveria NULL/datas trocadas
    -- em silencio. A chave e a data em numero (AAAAMMDD).
    CAST(DATE_FORMAT(STR_TO_DATE(p.`DtHoraPedido`, '%m/%d/%Y %h:%i %p'), '%Y%m%d') AS SIGNED)
        AS sk_tempo_pedido,

    -- Entrega: marco ja vem em ISO (AAAA-MM-DD). Em branco = processo em aberto,
    -- entao a FK aponta para a linha -1 (nunca nula).
    CASE
        WHEN p.`DtEntregaCliente` = '' THEN -1
        ELSE CAST(DATE_FORMAT(DATE(p.`DtEntregaCliente`), '%Y%m%d') AS SIGNED)
    END AS sk_tempo_entrega,

    -- ---- FK de loja: lookup pelo nome limpo; sem par -> -1 ----
    CASE WHEN dl.sk_loja IS NULL THEN -1 ELSE dl.sk_loja END AS sk_loja,

    -- ---- FK de categoria: lookup pela grafia crua; sem par -> -1 ----
    CASE WHEN dc.sk_categoria IS NULL THEN -1 ELSE dc.sk_categoria END AS sk_categoria,

    -- ---- houve_desconto: padronizado na propria fato (UPPER + TRIM) ----
    CASE
        WHEN UPPER(TRIM(p.`HouveDesconto`)) IN ('S','SIM','1','X','TRUE','V')  THEN 'Sim'
        WHEN UPPER(TRIM(p.`HouveDesconto`)) IN ('N','NAO','0','FALSE','F')     THEN 'Nao'
        ELSE 'Nao Informado'
    END AS houve_desconto,

    -- ---- canal_pedido: A ORDEM IMPORTA. 'WHATSAPP' contem 'APP', entao WHATS
    --      e testado ANTES de APP - senao os 414 pedidos de WhatsApp cairiam
    --      dentro do App e a P3 sairia errada.
    CASE
        WHEN UPPER(TRIM(p.`CanalPedido`)) LIKE '%WHATS%' THEN 'WhatsApp'
        WHEN UPPER(TRIM(p.`CanalPedido`)) LIKE '%APP%'   THEN 'App'
        WHEN UPPER(TRIM(p.`CanalPedido`)) LIKE '%SITE%'  THEN 'Site'
        WHEN UPPER(TRIM(p.`CanalPedido`)) LIKE '%LOJA%'  THEN 'Loja Fisica'
        WHEN UPPER(TRIM(p.`CanalPedido`)) LIKE '%TEL%'   THEN 'Telefone'
        ELSE 'Nao Informado'
    END AS canal_pedido,

    -- data e hora do pedido, ja convertida
    STR_TO_DATE(p.`DtHoraPedido`, '%m/%d/%Y %h:%i %p') AS dt_pedido,

    -- ---- qt_itens: '' vira NULL (nunca 0); senao converte para inteiro ----
    CASE WHEN TRIM(p.`QTD.Itens`) IN ('', '-', 'N/I', 'n/d')
         THEN NULL ELSE CAST(p.`QTD.Itens` AS SIGNED) END AS qt_itens,

    -- ---- vl_liquido: a regra dos numeros. '' e '-' viram NULL, nunca 0.
    --      Trata 'R$ 1.850,00' (milhar + virgula), '1850.00' e '1.200' (milhar).
    CASE
        WHEN TRIM(REPLACE(p.`ValorLiquidoPedido(R$)`, 'R$', '')) IN ('', '-') THEN NULL
        WHEN p.`ValorLiquidoPedido(R$)` LIKE '%,%'
            THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(p.`ValorLiquidoPedido(R$)`,'R$',''),' ',''),'.',''),',','.') AS DECIMAL(15,2))
        ELSE CAST(REPLACE(REPLACE(p.`ValorLiquidoPedido(R$)`,'R$',''),' ','') AS DECIMAL(15,2))
    END AS vl_liquido,

    -- ---- os 5 lags do processo, em dias. Marco de fim em branco -> NULL
    --      (nunca 0). A integracao tem hora, entao DATE() em volta.
    CASE WHEN p.`Dt Separacao Estoque` = '' THEN NULL
         ELSE DATEDIFF(DATE(p.`Dt Separacao Estoque`), DATE(STR_TO_DATE(p.`DtHoraIntegracaoERP`, '%m/%d/%Y %h:%i %p')))
    END AS dias_integracao_separacao,

    CASE WHEN p.`Dt Separacao Estoque` = '' OR p.`DtNotaFiscal` = '' THEN NULL
         ELSE DATEDIFF(DATE(p.`DtNotaFiscal`), DATE(p.`Dt Separacao Estoque`))
    END AS dias_separacao_nota,

    CASE WHEN p.`DtNotaFiscal` = '' OR p.`Dt_Despacho_Transportadora` = '' THEN NULL
         ELSE DATEDIFF(DATE(p.`Dt_Despacho_Transportadora`), DATE(p.`DtNotaFiscal`))
    END AS dias_nota_despacho,

    CASE WHEN p.`Dt_Despacho_Transportadora` = '' OR p.`DtEntregaCliente` = '' THEN NULL
         ELSE DATEDIFF(DATE(p.`DtEntregaCliente`), DATE(p.`Dt_Despacho_Transportadora`))
    END AS dias_despacho_entrega,

    CASE WHEN p.`DtEntregaCliente` = '' THEN NULL
         ELSE DATEDIFF(DATE(p.`DtEntregaCliente`), DATE(STR_TO_DATE(p.`DtHoraIntegracaoERP`, '%m/%d/%Y %h:%i %p')))
    END AS dias_total_ate_entrega

FROM stg_pedido p

-- LOJA: o nome sai limpo no proprio ON. REPLACE tira o sufixo '/SC' e o espaco
-- duplo; um CASE resolve as 3 grafias que REPLACE nao pega (erro de digitacao,
-- apelido e abreviacao). A collation padrao ignora acento e caixa, entao
-- 'Timbo', 'TIMBO' e 'Timbo' (com acento) casam com a chave_loja igualmente.
LEFT JOIN dim_loja dl
    ON dl.chave_loja = TRIM(REPLACE(REPLACE(
        CASE TRIM(REPLACE(p.`Loja-Nome`, '/SC', ''))
            WHEN 'PATA AMIGA BLUMENAL CENTRO' THEN 'PATA AMIGA BLUMENAU CENTRO'
            WHEN 'PATA AMIGA FLORIPA NORTE'   THEN 'PATA AMIGA FLORIANOPOLIS NORTE'
            WHEN 'PATA AMIGA JGUA DO SUL'     THEN 'PATA AMIGA JARAGUA DO SUL'
            ELSE p.`Loja-Nome`
        END, '/SC', ''), '  ', ' '))

-- CATEGORIA: lookup de uma linha so, pela grafia crua.
LEFT JOIN dim_categoria dc
    ON dc.categoria_origem = p.`CategoriaProduto`;
--
--  Roteiro das colunas:
--
--  * sk_tempo_pedido / sk_tempo_entrega: a chave e a data no formato AAAAMMDD.
--    Monte com CAST(DATE_FORMAT(<a data>, '%Y%m%d') AS SIGNED). A data do PEDIDO
--    vem no formato americano com AM/PM: a mascara e '%m/%d/%Y %h:%i %p'
--    (STR_TO_DATE). Usar '%d/%m/%Y' NAO da erro - ela devolve NULL e datas
--    erradas em silencio, que e pior. Os marcos da entrega ja vem em ISO:
--    DATE() basta. Entrega em branco -> -1.
--
--  * sk_loja, sk_categoria: vem de LEFT JOIN; se nao achou par, -1.
--
--  * LOJA (LEFT JOIN dim_loja): limpe o nome no ON. REPLACE tira '/SC' e o espaco
--    duplo; um CASE resolve 3 grafias (digitacao, apelido, abreviacao). Acento e
--    maiuscula nao atrapalham: a collation padrao do MySQL trata 'Timbo', 'TIMBO'
--    e 'Timbo' com acento como o mesmo texto.
--
--  * CATEGORIA (LEFT JOIN dim_categoria): uma linha so -
--    ON dc.categoria_origem = p.`CategoriaProduto`.
--
--  * houve_desconto e canal_pedido: padronize com CASE e grave na PROPRIA fato
--    (nao ha dimensao para eles). O de-para completo dos dois campos esta no
--    ENUNCIADO, na secao 7 ("Como padronizar o desconto e o canal").
--    A ordem importa: 'WHATSAPP' contem 'APP',
--    entao teste WHATS antes de APP.
--
--  * dinheiro e itens: '' e '-' viram NULL; tire "R$" e trate o milhar.
--
--  * os lags em dias: DATEDIFF(<fim>, <inicio>). Etapa nao cumprida grava NULL,
--    nunca 0. Use DATE() em volta da integracao (ela tem hora).

-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 04").
-- =====================================================================================
