-- Balanço Certo — schema multi-empresa (Supabase / Postgres)
-- Rode este arquivo uma vez no SQL Editor do seu projeto Supabase.

create extension if not exists "pgcrypto";

-- Empresas (tenants). "codigo" é o que o usuário digita no login.
create table empresas (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nome text not null,
  criado_em timestamptz default now()
);

-- Um perfil por usuário do Supabase Auth. Define empresa + papel.
-- O papel NÃO é escolhido pelo usuário no app — só por quem tem acesso
-- ao banco (ou uma futura tela de administração).
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  empresa_id uuid not null references empresas(id),
  nome text not null,
  papel text not null check (papel in ('operador','conferente','supervisor','gestor')),
  criado_em timestamptz default now()
);

-- Balanços (audits). O app gera o próprio id (ex.: "bal-abc123"), por
-- isso "id" é text, não uuid. Os campos de resumo (pendentes,
-- divergentes, etc.) são mantidos pelo próprio app a cada contagem —
-- mesmo padrão já usado no armazenamento local do protótipo.
create table balancos (
  id text primary key,
  empresa_id uuid not null references empresas(id),
  nome text not null,
  local text,
  responsavel text,
  tolerancia numeric default 0,
  criado_em timestamptz default now(),
  total_itens int not null default 0,
  pendentes int not null default 0,
  divergentes int not null default 0,
  aguardando_validacao int not null default 0,
  alertas_gestor int not null default 0,
  resolvidos int not null default 0,
  pronto_para_autorizacao boolean not null default false,
  autorizado_por text,
  autorizado_em timestamptz,
  observacao_encerramento text
);

-- Itens de cada balanço. Id composto pelo app (ex.: "bal-abc123__SKU1").
create table itens (
  id text primary key,
  empresa_id uuid not null references empresas(id),
  balanco_id text not null references balancos(id) on delete cascade,
  sku text not null,
  descricao text,
  categoria text,
  localizacao text,
  unidade text default 'un',
  qtd_sistema numeric not null default 0,
  qtd_contada numeric,
  status text not null default 'pendente',
  num_contagens int not null default 0,
  contagens jsonb not null default '[]',
  contado_por text, contado_em timestamptz, observacao_contagem text,
  conferido_por text, conferido_em timestamptz, observacao_conferencia text,
  validado_por text, validado_em timestamptz, observacao_validacao text
);

create index itens_balanco_id_idx on itens (balanco_id);
create index itens_empresa_status_idx on itens (empresa_id, status);

-- Row-Level Security: cada empresa só acessa os próprios dados.
alter table empresas enable row level security;
alter table profiles enable row level security;
alter table balancos enable row level security;
alter table itens enable row level security;

-- Resolve a empresa do usuário autenticado (usada nas policies abaixo).
create or replace function my_empresa_id() returns uuid
language sql stable security definer as $$
  select empresa_id from profiles where id = auth.uid()
$$;

-- Leitura pública (sem login) só do id/código/nome — necessário para o
-- passo 1 do login ("código da empresa") resolver a empresa antes de
-- autenticar. Nenhum dado de balanço/item é exposto por essa policy.
create policy "empresas: leitura pública para login" on empresas
  for select using (true);

create policy "profiles: cada usuário só lê o próprio perfil" on profiles
  for select using (id = auth.uid());

create policy "balancos: isolado por empresa" on balancos
  for all using (empresa_id = my_empresa_id()) with check (empresa_id = my_empresa_id());

create policy "itens: isolado por empresa" on itens
  for all using (empresa_id = my_empresa_id()) with check (empresa_id = my_empresa_id());

-- ---------------------------------------------------------------
-- Provisionamento manual (rode depois de criar o schema acima):
--
-- 1) Criar a empresa:
--    insert into empresas (codigo, nome) values ('ACME01', 'Empresa Exemplo');
--
-- 2) Criar o primeiro usuário: aba Authentication > Users do painel
--    Supabase, "Add user" (e-mail + senha).
--
-- 3) Vincular o perfil (troque os uuids pelos ids reais gerados acima):
--    insert into profiles (id, empresa_id, nome, papel)
--    values ('<uuid do usuário>', '<uuid da empresa>', 'Nome da Pessoa', 'gestor');
-- ---------------------------------------------------------------
