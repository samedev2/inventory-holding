# inventory-holding — Balanço Certo

Protótipo mobile-first para inventários e auditorias de estoque: coleta, conferência, validação e autorização, com controle de papéis (operador, conferente, supervisor, gestor).

## Estrutura

```
web/
  balanco-certo.html   # app completo em HTML/CSS/JS puro (fonte canônica)
android/
  www/index.html        # cópia do app acima, empacotada como página standalone
  android/               # projeto Android gerado via Capacitor (Gradle)
  package.json
  capacitor.config.json
```

O app é um único arquivo HTML/CSS/JS sem build step. `web/balanco-certo.html` é a fonte de verdade; `android/www/index.html` é a mesma página envolvida em um documento HTML completo (`<!DOCTYPE>`, `<head>` com meta charset/viewport) para rodar dentro do WebView do Capacitor. Ao editar o app, atualize os dois arquivos (ou gere o segundo a partir do primeiro, veja abaixo).

## Rodando no navegador

Basta abrir `web/balanco-certo.html` num servidor estático (ex.: `npx serve` ou `python -m http.server`) — não depende de build.

- Login demo: usuário `demo`, senha `demo123`.
- Persistência local via `localStorage` quando não há um backend conectado (ex.: fora do Claude Artifact).

## Gerando o APK Android (debug)

Pré-requisitos: Node.js, JDK 17+, Android SDK (`ANDROID_HOME`/`local.properties` configurado).

```bash
cd android
npm install
npx cap sync android
cd android
./gradlew assembleDebug
```

O APK fica em `android/android/app/build/outputs/apk/debug/app-debug.apk`.

> **Nota (Windows):** se o build travar com `Unable to establish loopback connection` (Java/Gradle), defina
> `set JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\t` (crie a pasta `C:\t`) antes de rodar o Gradle — é um
> problema conhecido do socket de loopback AF_UNIX do JDK em certos ambientes Windows. Se o build falhar com
> `CreateProcess error=267` / nome de diretório inválido, mova o projeto para um caminho curto (ex.: `C:\t\android`)
> — é o limite de tamanho de caminho do Windows (MAX_PATH).

## Multi-empresa (Supabase)

Por padrão o app roda em modo demo (login `demo`/`demo123`, dados em `localStorage`, papel trocável livremente
em Perfil). Para ligar o modo real — várias empresas, cada uma vendo só os próprios dados, login de verdade:

1. Crie um projeto gratuito em [supabase.com](https://supabase.com).
2. Abra o **SQL Editor** do projeto e rode `supabase/schema.sql` (cria as tabelas, a função e as políticas de
   isolamento por empresa).
3. Provisione a primeira empresa e o primeiro usuário (passo a passo comentado no fim do próprio `schema.sql`):
   `insert into empresas (...)`, criar o usuário em Authentication → Users, depois `insert into profiles (...)`
   vinculando usuário + empresa + papel.
4. Em `web/balanco-certo.html` (e `android/www/index.html`), preencha:
   ```js
   var SUPABASE_CONFIG = { url: 'https://SEU-PROJETO.supabase.co', anonKey: 'SUA_ANON_KEY' };
   ```
   (a *anon key* é pública por design — o isolamento real é garantido pelas políticas de Row-Level Security do
   passo 2, não pela chave).
5. Publique/rode o app normalmente. A tela de login passa a pedir **Código da empresa + E-mail + Senha**, e
   cada usuário só enxerga os balanços/itens da própria empresa. O papel (operador/conferente/supervisor/gestor)
   deixa de ser trocável pelo usuário — é definido só no banco (coluna `profiles.papel`).

Com `SUPABASE_CONFIG` vazio (padrão), nada disso é ativado — o app continua funcionando 100% no modo demo local.

Fora de escopo por enquanto (ver `README`/plano de implementação): cadastro self-service de empresa, convite de
colegas, Supabase Realtime (atualização ao vivo entre aparelhos), recuperação de senha.

## Papéis e fluxo

- **Operador de Coleta** — conta os itens fisicamente.
- **Conferente** — revisa contagens com divergência; confirma ou solicita recontagem.
- **Supervisor** — valida o ajuste final de itens conferidos.
- **Gestor** — autoriza o encerramento do balanço e decide alertas de contagem.

### Regra das 3 contagens

Cada item pode ser contado até **3 vezes**. Se a 1ª contagem divergir do sistema, o conferente pode confirmar
a divergência (segue para validação do supervisor) ou solicitar recontagem. Se a **3ª contagem** ainda divergir,
o item é escalado automaticamente para **Alerta ao Gestor** — somente o papel Gestor pode registrar a decisão
final nesse caso (ajuste, quebra, furto etc.).

## Auditor de inventário externo (demo)

Na tela "Novo balanço", o gestor pode registrar os itens digitando à mão, escaneando um documento (OCR real via
Tesseract.js, sempre com revisão manual antes de salvar) ou "conectando" a um inventário externo (ex.: Granja
Norte). Essa conexão — geração de token, animação de handshake e importação dos itens — é **inteiramente mock**:
não existe integração real com nenhum sistema externo agora. Serve para demonstrar o fluxo a sócios/interessados;
o token gerado não autentica nada de verdade e os itens importados vêm de uma lista fixa de exemplo.

## Licença

Uso interno / demonstração.
