# Prompt: gerar site estático com nota máxima no PageSpeed

> Copie tudo abaixo da linha e cole no Claude Code, preenchendo o bloco `DADOS DO PROJETO`.
> Estes parâmetros foram validados em produção: marcoslima.com.br atingiu
> **Desempenho 100 · Acessibilidade 100 · Práticas recomendadas 100 · SEO 100 · Navegação agêntica 3/3**.

---

Crie um site estático seguindo EXATAMENTE as regras abaixo. Elas vieram de depuração real até nota máxima no PageSpeed — cada uma corrige um problema que de fato derrubou a nota. Não "melhore" nem substitua por alternativas que pareçam equivalentes.

## DADOS DO PROJETO

- Domínio: `paulahernandezoficiaç.com.br`
- Negócio: Mentoria
- Cidade/UF: Fortaleza/CE
- Serviços (um por página de cluster): Especialista em comportamentos e vendas
- WhatsApp (formato 5585999999999): 558899186253
- CNPJ:
- Endereço completo: Paula Hernandez
- Coordenadas (lat, long):
- Fonte de título / fonte de corpo:
- Paleta (5-7 cores hex):
- GA4 Measurement ID (ou "sem analytics"):

---

## 1. ARQUITETURA

Site estático puro: **sem build, sem framework, sem client-side JavaScript** (blocos JSON-LD são dados, não lógica). Estrutura de cluster SEO:

```
index.html                   ← raiz
<slug-servico-1>/index.html  ← uma pasta por serviço
<slug-servico-2>/index.html
assets/style.css             ← CSS compartilhado por TODAS as páginas
assets/fontes/*.woff2        ← fontes locais
robots.txt  sitemap.xml  llms.txt  htaccess  site.webmanifest
<chave-indexnow>.txt
```

Slugs incluem serviço + cidade: `consultoria-em-X-em-<cidade>`. Cada pasta é servida como `/slug/` pelo Apache.

## 2. FONTES — regra que mais impactou a nota

**NUNCA embutir fonte em base64 dentro do CSS.** No projeto real isso deixava o CSS em 126KB; extrair para `.woff2` derrubou para 12KB (−91%) e foi o maior ganho isolado de LCP.

- Baixe cada peso como arquivo `.woff2` separado em `/assets/fontes/`
- Um arquivo por peso real. Se dois pesos forem byte-a-byte idênticos (variable font), use um só e declare `font-weight: 700 800`
- Declare `@font-face` com `font-display:swap` **no CSS crítico inline de cada página** — não só no CSS externo. Se só existir no externo, o navegador entra em "block period" esperando decidir sobre a fonte e atrasa a pintura do texto (mediu 2500ms de atraso de renderização; com a correção caiu para 610ms)
- `<link rel="preload" as="font" type="font/woff2" href="..." crossorigin>` para as 3 fontes mais usadas, antes do `<style>`
- Zero requisição a Google Fonts CDN ou qualquer host externo de fonte

**NÃO FAÇA:** fallback com `size-adjust`/`ascent-override`/`descent-override` para casar métricas. Parece correto na teoria e é recomendado em artigos, mas no projeto real **piorou** o CLS de 0,113 para 0,197. Foi revertido.

## 3. CSS

- Um único `assets/style.css` compartilhado. **Nunca re-inlinar o arquivo inteiro** em cada página: quebra o cache compartilhado entre páginas
- CSS crítico inline no `<head>`: só `@font-face`, reset, `:root` com as variáveis, e as regras do hero (primeira dobra)
- **Não duplicar** no crítico regras que já vivem no externo (`section{padding}` etc). Tentar isso não resolveu CLS e contraria a arquitetura
- Carregamento do externo — exatamente assim:
  ```html
  <link rel="preload" as="style" href="/assets/style.css" onload="this.onload=null;this.rel='stylesheet'"/>
  <noscript><link rel="stylesheet" href="/assets/style.css"/></noscript>
  ```
  Trocar por `<link rel="stylesheet">` direto faz o Lighthouse marcar "render-blocking" (custou ~470ms)
- Cores sempre via variáveis do `:root`, nunca hex solto
- **Nunca `opacity` em texto** — derruba contraste e quebra Acessibilidade. Use a cor sólida da variável

## 4. ORDEM DO `<head>`

```html
<!DOCTYPE html>
<html lang="pt-BR"><head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>…</title>                        <!-- 40-60 caracteres -->
<meta name="description" content="…"/>  <!-- 120-160 caracteres -->
<meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1"/>
<link rel="canonical" href="https://DOMINIO/CAMINHO/"/>
<meta name="theme-color" content="#COR"/>
<link rel="icon" type="image/webp" href="/favicon.webp"/>
<link rel="apple-touch-icon" href="/favicon.png"/>
<link rel="manifest" href="/site.webmanifest"/>
<meta name="author" content="…"/>
<!-- og: e twitter: — DEVEM repetir o title/description desta página, nunca de outra -->
<link rel="preload" as="font" …>        <!-- 3 fontes principais -->
<style>/* @font-face + reset + :root + hero */</style>
<link rel="preload" as="style" href="/assets/style.css" onload="…"/>
<noscript>…</noscript>
</head>
```

Title, description, `og:title`, `og:description`, `twitter:title`, `twitter:description` e `JSON-LD WebPage.name` **precisam contar a mesma história**. Desalinhamento entre eles dilui o sinal — aconteceu no projeto real após uma mudança de posicionamento e só foi notado numa auditoria posterior.

## 5. JAVASCRIPT DE TERCEIRO — a regra mais cara

**Padrão: nenhum.** Cada script externo é dívida direta de nota.

Caso real: o botão "Adicionar a Fontes Preferidas" do Google (`publisher.js`) derrubou **Desempenho de 98 para 72**. Ele puxa 220KB do gstatic, 92KB nunca usados, sem cache adequado. Foi removido.

**Adiar para `window.addEventListener('load')` NÃO resolve** — o Lighthouse mede até o fim do carregamento e conta o peso do mesmo jeito.

A única técnica que funciona de verdade é impedir o download: Consent Mode v2, onde o script só é criado após clique real.

## 6. GOOGLE ANALYTICS (se houver)

Consent Mode v2 — sem aceite, o `gtag.js` nunca baixa, e o PageSpeed não mede o que não aconteceu:

```html
<script>
window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('consent', 'default', {analytics_storage:'denied', ad_storage:'denied', ad_user_data:'denied', ad_personalization:'denied', wait_for_update: 500});
gtag('js', new Date());
window.ligarMedicao = function(){
  if (window.__medicaoLigada) return; window.__medicaoLigada = true;
  gtag('consent', 'update', {analytics_storage:'granted', ad_storage:'granted', ad_user_data:'granted', ad_personalization:'granted'});
  var s = document.createElement('script');
  s.async = true;
  s.src = 'https://www.googletagmanager.com/gtag/js?id=GA_ID';
  document.head.appendChild(s);
  gtag('config', 'GA_ID');
};
(function(){
  var c = null;
  try { var j = JSON.parse(localStorage.getItem('ck-consent') || 'null'); if (j && j.ate > Date.now()) c = j.v; } catch (e) {}
  if (c === 'aceito') window.ligarMedicao();
})();
</script>
```

Banner: `position:fixed` num canto (não pode colidir com sticky-bar de CTA), `hidden` por padrão, `role="region"` + `aria-label`, dois botões ("Aceitar" / "Só o necessário"), escolha salva em `localStorage` por 12 meses. Por ser `position:fixed`, não gera CLS.

**Nunca usar GTM junto com gtag.js** — duplica bibliotecas de tracking. No projeto real essa duplicação custava 257KB.

## 7. JSON-LD (um bloco `@graph` por página)

Raiz carrega: `ProfessionalService` + `Person` + `WebSite` + `WebPage` + `FAQPage`.
Cluster carrega: `Service` + `WebPage` + `BreadcrumbList` + `FAQPage`, escopado à própria URL.

Todo `@id` é URL absoluta ancorada na página da entidade. Elementos que elevam E-E-A-T e capacidade de citação por IA:

- **`knowsAbout` com `@id` de Wikidata** + nós `Thing` correspondentes no grafo. Ancorar em entidade pública faz a máquina parar de adivinhar o assunto. Ex: `https://www.wikidata.org/wiki/Q11660` (inteligência artificial)
- **`DefinedTerm`** nomeando o método proprietário, com `@id`, `description`, `inDefinedTermSet` e `creator`. IA cita nome, não descrição genérica
- **`hasCredential`** com `EducationalOccupationalCredential` + `recognizedBy` para cada formação
- **`openingHoursSpecification`**, `address`, `geo`, `hasMap`, `areaServed`
- **`aggregateRating`** só se houver avaliações reais e verificáveis
- `alternateName` com as variações do nome
- `sameAs` com todos os perfis sociais

**As credenciais precisam aparecer no HTML visível também.** Schema que afirma o que a página não mostra vale menos e pode ser ignorado.

Valide o JSON antes de publicar:
```bash
python -c "
import re,json
h=open('index.html',encoding='utf-8').read()
for b in re.findall(r'<script type=\"application/ld\+json\">(.*?)</script>',h,re.S):
    d=json.loads(b); print('OK —',[n.get('@type') for n in d.get('@graph',[])])
"
```

## 8. CONTEÚDO E SEMÂNTICA

- Um `<h1>` por página, hierarquia H1→H2→H3 sem pular nível
- Mínimo ~1000 palavras por página (abaixo disso é thin content)
- Toda `<img>` com `width`, `height`, `alt` descritivo e `loading="lazy"` (exceto a do LCP, se houver)
- Todo link e botão com nome acessível
- FAQ com respostas diretas na primeira frase — é o formato que vira featured snippet e citação de IA
- Números afirmados levam fonte e data ao lado ("dado próprio · set/2026"). Número sem procedência IA não cita
- Cross-link entre raiz e cluster com `<a href="/slug/">`. Varie o texto âncora entre as variantes do termo-alvo

## 9. ARQUIVOS DE APOIO

**`llms.txt`** na raiz — resumo em markdown para IA generativa: título com o termo-alvo, blockquote de uma frase, parágrafo de contexto, `## Serviços` com link+descrição de cada, `## Páginas`, `## Contato`.

**`robots.txt`** — allow geral, disallow de admin/wp/tmp/`?utm_`, `Sitemap:` apontando para o sitemap.

**`sitemap.xml`** — todas as URLs reais com `lastmod`, `changefreq`, `priority`. Antes de publicar, confirme que cada URL responde 200:
```bash
for p in "" "slug-1/" "slug-2/"; do
  echo -n "$p => "; curl -s -o /dev/null -w "%{http_code}\n" "https://DOMINIO/$p"
done
```

**`site.webmanifest`** — `theme_color` igual ao `<meta name="theme-color">`.

**IndexNow** — gere a chave (`openssl rand -hex 32`), crie `<chave>.txt` na raiz contendo a própria chave. Notifique a cada publicação:
```bash
curl -s -X POST "https://api.indexnow.org/indexnow" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{"host":"DOMINIO","key":"CHAVE","keyLocation":"https://DOMINIO/CHAVE.txt","urlList":["https://DOMINIO/"]}' \
  -w "\nHTTP %{http_code}\n"
```
202 ou 200 = aceito. Cobre Bing, Yandex e Seznam — o Google não adota, continua exigindo Search Console.

## 10. `.htaccess`

Arquivo versionado como `htaccess` (sem ponto), renomeado no servidor. Conteúdo:

```apache
AddDefaultCharset utf-8

# Host canônico + HTTPS numa regra só
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteCond %{HTTPS} off [OR]
  RewriteCond %{HTTP_HOST} ^www\.DOMINIO$ [NC]
  RewriteRule ^(.*)$ https://DOMINIO/$1 [L,R=301]
</IfModule>

# Compressão (fontes/imagens já comprimidas ficam de fora)
<IfModule mod_brotli.c>
  AddOutputFilterByType BROTLI_COMPRESS text/html text/plain text/css text/xml \
    text/javascript application/javascript application/json application/xml \
    application/rss+xml image/svg+xml
</IfModule>
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/plain text/css text/xml \
    text/javascript application/javascript application/json application/xml \
    application/rss+xml image/svg+xml
  SetEnvIfNoCase Request_URI \.(?:woff2?|gif|jpe?g|png|webp|avif|ico|zip|gz|mp4|webm)$ no-gzip dont-vary
</IfModule>

# Cache: HTML revalida sempre, estáticos 1 ano
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType text/html "access plus 0 seconds"
  ExpiresByType text/css "access plus 1 year"
  ExpiresByType application/javascript "access plus 1 year"
  ExpiresByType image/webp "access plus 1 year"
  ExpiresByType image/png "access plus 1 year"
  ExpiresByType image/jpeg "access plus 1 year"
  ExpiresByType image/svg+xml "access plus 1 year"
  ExpiresByType font/woff2 "access plus 1 year"
</IfModule>

<IfModule mod_headers.c>
  <FilesMatch "\.(css|js|svg|png|jpe?g|webp|avif|gif|ico|woff2?)$">
    Header set Cache-Control "public, max-age=31536000, immutable"
  </FilesMatch>
  <FilesMatch "\.html?$">
    Header set Cache-Control "public, max-age=0, must-revalidate"
  </FilesMatch>
  Header append Vary Accept-Encoding

  Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
  Header always set X-Content-Type-Options "nosniff"
  Header always set X-Frame-Options "DENY"
  Header always set Referrer-Policy "strict-origin-when-cross-origin"
  Header always set Content-Security-Policy "default-src 'self' https:; style-src 'self' 'unsafe-inline' https:; font-src 'self' data: https:; img-src 'self' data: https:; script-src 'self' 'unsafe-inline' https:; connect-src 'self' https:; frame-src https:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"

  Header unset ETag
</IfModule>
FileETag None
```

## 11. CHECKLIST ANTES DE PUBLICAR

```
[ ] Zero requisição a host externo (fonte, CSS, JS) — exceto gtag atrás de consent
[ ] CSS externo < 20KB, carregado via preload+onload
[ ] @font-face com font-display:swap presente no CSS crítico inline
[ ] preload das 3 fontes principais no <head>
[ ] Nenhum `opacity` em texto
[ ] Toda <img> com width + height + alt
[ ] JSON-LD validando como JSON
[ ] title 40-60 / description 120-160 em toda página
[ ] og/twitter/JSON-LD WebPage.name alinhados com o title da própria página
[ ] Um H1 por página, hierarquia sem pulos
[ ] Todas as URLs do sitemap retornam 200
[ ] llms.txt, robots.txt, chave IndexNow na raiz
[ ] htaccess renomeado para .htaccess no servidor
[ ] Testar: raiz responde 200, versão www responde 301
```

## 12. QUANDO A NOTA CAIR — protocolo

Aprendido do jeito difícil: três correções encadeadas por hipótese pioraram o CLS de 0,113 para 0,197 antes de alguém reverter.

1. **Não corrija por suposição.** Peça o detalhamento que nomeia os elementos ("Causas da troca de layout", "Detalhamento da LCP")
2. **Uma mudança por vez**, medindo entre cada uma
3. **Se não melhorou, reverta imediatamente** — não empilhe outra teoria sobre a anterior
4. **Suspeite primeiro da última coisa adicionada**, especialmente se for script de terceiro
5. Item marcado "Fora da pontuação" é informativo e não afeta nota — não vale assumir risco para mexer nele

## 13. FLUXO DE PUBLICAÇÃO

1. Upload dos arquivos alterados
2. Verificar no ar com `curl` que a mudança chegou
3. Notificar IndexNow (Bing/Yandex)
4. **Avisar para pedir reindexação no Google Search Console** — o Google não usa IndexNow
5. Rodar PageSpeed e comparar com a medição anterior
