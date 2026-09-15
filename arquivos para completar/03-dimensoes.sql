-- =====================================================================================
--  ARQUIVO 3:  AS DIMENSOES QUE VOCE PREENCHE
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 01-carga-staging.sql  e  02-dimensoes-prontas.sql
--
--  As tabelas ja existem, vazias, criadas no arquivo 02. Aqui voce as PREENCHE.
--  Sao duas dimensoes e uma ponte:
--      dim_categoria       o de-para das grafias
--      dim_praca           uma linha por praca de atendimento
--      bridge_loja_praca   a ligacao N:N entre loja e praca, com o rateio
--
--  Regras para as duas dimensoes:
--    * PK = surrogate key inteira (AUTO_INCREMENT)
--    * a chave natural (a grafia, o cod da praca) fica como atributo
--    * sempre a linha -1 = "Nao Informado", inserida ANTES do INSERT ... SELECT
--    * as tabelas stg_ NAO se alteram
--
--  Comandos: INSERT ... VALUES, INSERT ... SELECT, SELECT DISTINCT, JOIN,
--  GROUP BY, CASE WHEN, REPLACE, UPPER, TRIM, CAST, MAX
-- =====================================================================================

USE dw_pata_amiga;

-- =====================================================================================
--  DIM_CATEGORIA        grao: UMA GRAFIA DA ORIGEM
-- =====================================================================================
--  Guarde a grafia CRUA em categoria_origem e a versao padronizada em
--  nome_categoria (uma linha por grafia; varias grafias podem apontar para o
--  mesmo nome). Depois a fato acha a linha por categoria_origem.
--  Insira primeiro a linha -1. No INSERT ... SELECT DISTINCT, um CASE traduz as
--  grafias em 7 categorias.
--  ATENCAO: a ordem do CASE importa - "Racao Medicamentosa" e Medicamento, entao
--  teste MED antes de RA. Compare em UPPER e use trechos SEM acento.

-- Linha -1: inserida ANTES do INSERT ... SELECT para nenhuma FK ficar nula.
INSERT INTO dim_categoria (sk_categoria, categoria_origem, nome_categoria, grupo_categoria)
VALUES (-1, 'N/I', 'Nao Informado', 'Nao Informado');

-- Uma linha por GRAFIA crua (SELECT DISTINCT). O CASE traduz a grafia nas 7
-- categorias padronizadas. A ORDEM importa: "Racao Medicamentosa" contem "RA",
-- entao MED e testado ANTES de RA - senao o medicamento cairia em Racao e a P2
-- sairia com o numero trocado. Todo trecho e testado em UPPER e SEM acento,
-- para o resultado nao depender da instalacao.
INSERT INTO dim_categoria (categoria_origem, nome_categoria, grupo_categoria)
SELECT DISTINCT
    p.`CategoriaProduto` AS categoria_origem,
    CASE
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%MED%'    THEN 'Medicamento'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%PETISC%' THEN 'Petisco'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%RA%'     THEN 'Racao'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%HIG%'    THEN 'Higiene'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%BRINQ%'  THEN 'Brinquedo'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%ACESS%'  THEN 'Acessorio'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%SERV%'   THEN 'Servico'
        ELSE 'Nao Informado'
    END AS nome_categoria,
    CASE
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%MED%'    THEN 'Saude e Higiene'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%PETISC%' THEN 'Alimentacao'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%RA%'     THEN 'Alimentacao'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%HIG%'    THEN 'Saude e Higiene'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%BRINQ%'  THEN 'Bem-estar'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%ACESS%'  THEN 'Bem-estar'
        WHEN UPPER(p.`CategoriaProduto`) LIKE '%SERV%'   THEN 'Bem-estar'
        ELSE 'Nao Informado'
    END AS grupo_categoria
FROM stg_pedido p
WHERE p.`CategoriaProduto` <> '';


-- =====================================================================================
--  DIM_PRACA  +  BRIDGE_LOJA_PRACA
-- =====================================================================================
--  A stg_loja_praca tem 48 linhas: a mesma loja aparece uma vez por praca. Um
--  GROUP BY por CodPraca colapsa em 12 pracas. Colunas fora do GROUP BY precisam
--  de agregacao (MAX serve). domicilios_com_pet vem como '148.000': o ponto e
--  milhar, tire-o antes do CAST.

-- Linha -1: inserida ANTES do INSERT ... SELECT.
INSERT INTO dim_praca (sk_praca, cod_praca, nome_praca, regional, domicilios_com_pet)
VALUES (-1, 'N/I', 'Nao Informado', 'Nao Informado', NULL);

-- A stg_loja_praca tem 48 linhas (a mesma praca aparece uma vez por loja que a
-- atende). Um GROUP BY por CodPraca colapsa em 12 pracas. As colunas fora do
-- GROUP BY (nome, regional, domicilios) sao iguais dentro da praca, entao MAX
-- serve para escolher o valor. domicilios_com_pet vem como '148.000': o ponto e
-- milhar, removido com REPLACE antes do CAST para inteiro.
INSERT INTO dim_praca (cod_praca, nome_praca, regional, domicilios_com_pet)
SELECT
    lp.`CodPraca`                                        AS cod_praca,
    MAX(lp.`NomePraca`)                                  AS nome_praca,
    MAX(lp.`Regional`)                                   AS regional,
    CAST(REPLACE(MAX(lp.`DomiciliosComPet`), '.', '') AS SIGNED) AS domicilios_com_pet
FROM stg_loja_praca lp
GROUP BY lp.`CodPraca`;


-- -------------------------------------------------------------------------------------
--  A TABELA PONTE
-- -------------------------------------------------------------------------------------
--  Uma loja entrega em mais de uma praca (N:N) - por isso a ligacao vive numa
--  tabela propria, com o FATOR DE RATEIO dentro (os fatores de uma loja somam
--  1,00). A ponte usa o COD DA LOJA, nao a sk_loja.

-- Uma linha por par loja x praca (as 48 da stg_loja_praca). A ponte guarda o
-- COD DA LOJA (chave natural que atravessa recargas), nao a sk_loja. A sk_praca
-- vem de um JOIN com a dim_praca pelo cod_praca. O fator_publico e o
-- PercentualPublico ('0.85') convertido para decimal - os fatores de uma loja
-- somam 1,00.
INSERT INTO bridge_loja_praca (cod_loja, sk_praca, fator_publico)
SELECT
    lp.`CodLoja`                          AS cod_loja,
    dp.sk_praca                           AS sk_praca,
    CAST(lp.`PercentualPublico` AS DECIMAL(6,4)) AS fator_publico
FROM stg_loja_praca lp
JOIN dim_praca dp ON dp.cod_praca = lp.`CodPraca`;


-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 03").
-- =====================================================================================
