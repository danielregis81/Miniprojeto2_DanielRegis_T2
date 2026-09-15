-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Cada pergunta e UMA consulta: um SELECT com JOIN e GROUP BY. A subconsulta
--  aparece na P2 e na P5, e serve para trazer o total da rede como denominador.
-- =====================================================================================

USE dw_pata_amiga;

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.

-- Media dos 4 intervalos + o total, por porte de loja. AVG ignora NULL, entao
-- as etapas em aberto nao puxam a media para baixo. A ultima coluna
-- (dias_total_ate_entrega) e o processo inteiro, nao um dos 4 intervalos.
SELECT
    l.porte,
    COUNT(*)                                     AS pedidos,
    ROUND(AVG(f.dias_integracao_separacao), 1)   AS med_integracao_separacao,
    ROUND(AVG(f.dias_separacao_nota), 1)         AS med_separacao_nota,
    ROUND(AVG(f.dias_nota_despacho), 1)          AS med_nota_despacho,
    ROUND(AVG(f.dias_despacho_entrega), 1)       AS med_despacho_entrega,
    ROUND(AVG(f.dias_total_ate_entrega), 1)      AS med_total_ate_entrega
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.porte
ORDER BY med_total_ate_entrega DESC;


-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.

-- Faturamento por categoria PADRONIZADA (nunca pela grafia crua) e o % do total
-- da rede. O denominador vem de uma subconsulta com o faturamento total.
SELECT
    c.nome_categoria,
    c.grupo_categoria,
    ROUND(SUM(f.vl_liquido))                                    AS faturamento,
    ROUND(100 * SUM(f.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido), 1) AS pct_do_total
FROM fato_pedido f
JOIN dim_categoria c ON c.sk_categoria = f.sk_categoria
GROUP BY c.nome_categoria, c.grupo_categoria
ORDER BY faturamento DESC;


-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.

-- Ticket medio COM e SEM desconto dentro de cada canal (sem JOIN: desconto e
-- canal ja moram na fato). Duas colunas de AVG condicional; a diferenca mostra
-- se o desconto derruba o ticket em algum canal. A ultima coluna e a fatia do
-- canal no faturamento da rede. Ignora canal e desconto Nao Informado.
SELECT
    f.canal_pedido,
    COUNT(*)                                                                          AS pedidos,
    ROUND(AVG(CASE WHEN f.houve_desconto = 'Sim' THEN f.vl_liquido END), 2)            AS ticket_com_desconto,
    ROUND(AVG(CASE WHEN f.houve_desconto = 'Nao' THEN f.vl_liquido END), 2)            AS ticket_sem_desconto,
    ROUND(100 * SUM(f.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido), 1)      AS pct_faturamento
FROM fato_pedido f
WHERE f.canal_pedido <> 'Nao Informado'
GROUP BY f.canal_pedido
ORDER BY pct_faturamento DESC;


-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.

-- Faturamento por praca, RATEADO. Caminho: fato -> dim_loja -> bridge (pelo
-- cod_loja) -> dim_praca. O JOIN com a ponte duplica o pedido, uma linha por
-- praca que a loja atende - por isso multiplica-se por b.fator_publico, senao o
-- faturamento de quem atende 2 pracas seria contado duas vezes e estouraria o
-- total da rede. Cruza com os domicilios com pet de cada praca.
SELECT
    pr.nome_praca,
    pr.regional,
    pr.domicilios_com_pet,
    ROUND(SUM(f.vl_liquido * b.fator_publico))                          AS faturamento_rateado,
    ROUND(SUM(f.vl_liquido * b.fator_publico) / pr.domicilios_com_pet, 2) AS faturamento_por_domicilio
FROM fato_pedido f
JOIN dim_loja l          ON l.sk_loja = f.sk_loja
JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja
JOIN dim_praca pr        ON pr.sk_praca = b.sk_praca
WHERE l.sk_loja <> -1
GROUP BY pr.nome_praca, pr.regional, pr.domicilios_com_pet
ORDER BY faturamento_rateado DESC;


-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens POR MIL HABITANTES (numerador na fato,
--      denominador na dimensao), calculado AQUI na consulta - nunca gravado
--      pronto. Cruze com o tempo medio de entrega.
--  (b) Mostre o faturamento por faixa de franquia e explique por que ele NAO
--      responde "quanto veio de lojas que JA ERAM Ouro na data do pedido": o
--      cadastro so tem a foto de hoje.
--  (c) Meca o que ficou de fora: pedidos sem loja, entregas nao concluidas,
--      itens e valores em branco.

-- (a) Ranking das lojas por ITENS POR MIL HABITANTES (nao valor absoluto),
--     calculado aqui na consulta: numerador (itens) na fato, denominador
--     (populacao) na dimensao. Cruzado com o tempo medio de entrega.
SELECT
    l.nome_loja,
    l.cidade,
    l.porte,
    l.faixa_franquia,
    l.populacao_cidade,
    SUM(f.qt_itens)                                                        AS itens_vendidos,
    ROUND(1000 * SUM(f.qt_itens) / l.populacao_cidade, 2)                  AS itens_por_mil_hab,
    ROUND(AVG(f.dias_total_ate_entrega), 1)                               AS med_dias_entrega
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.nome_loja, l.cidade, l.porte, l.faixa_franquia, l.populacao_cidade
ORDER BY itens_por_mil_hab DESC;

-- (b) Faturamento por faixa de franquia ATUAL. Isto NAO responde "quanto veio de
--     lojas que JA ERAM Ouro na data do pedido": o cadastro (dim_loja) so guarda
--     a foto de HOJE (DtUltimaAtualizacao = 31/03/2024), o historico foi
--     sobrescrito. A faixa de um pedido de setembro/2023 pode ter mudado ate la.
SELECT
    l.faixa_franquia,
    COUNT(*)                    AS pedidos,
    ROUND(SUM(f.vl_liquido))     AS faturamento
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.faixa_franquia
ORDER BY faturamento DESC;

-- (c) O que ficou de fora (limitacoes dos dados): pedidos sem loja, entregas nao
--     concluidas, e itens/valores em branco.
SELECT 'pedidos sem loja identificada'      AS limitacao, COUNT(*) AS qtd FROM fato_pedido WHERE sk_loja = -1
UNION ALL SELECT 'entregas ainda nao concluidas',          COUNT(*) FROM fato_pedido WHERE sk_tempo_entrega = -1
UNION ALL SELECT 'pedidos com qt_itens em branco (NULL)',  COUNT(*) FROM fato_pedido WHERE qt_itens IS NULL
UNION ALL SELECT 'pedidos com vl_liquido em branco (NULL)', COUNT(*) FROM fato_pedido WHERE vl_liquido IS NULL;
