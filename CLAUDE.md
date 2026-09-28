# CLAUDE.md

## O que é este projeto

Site estático de cluster SEO para **Paula Hernandez — mentoria em comportamento e vendas** (Fortaleza/CE). Sem build, sem framework, **sem client-side JavaScript** (blocos JSON-LD são dados, não lógica), sem gerenciador de pacotes. Idioma: pt-BR. Deploy em Apache/cPanel via FTP.

**Este site tem nota máxima no PageSpeed (100/100/100/100 + 3/3 navegação agêntica). Preservar isso é requisito, não bônus.** As regras abaixo vieram de depuração real — cada uma corrige um problema que derrubou a nota de verdade.

## Estrutura

```
index.html                   ← raiz
mentoria-em-comportamento-e-vendas-em-fortaleza/index.html  ← cluster
assets/style.css             ← CSS de todas as páginas
assets/fontes/*.woff2        ← fontes locais
robots.txt  sitemap.xml  llms.txt  htaccess  site.webmanifest
137f9f9d492df6f9458e0da3c287f2559c864636b1c3854ea3989a4ae8df6908.txt
```

Nova página de cluster = nova pasta com `index.html`. Slug inclui serviço + cidade.

## Regras invioláveis

### Fontes
- Arquivos `.woff2` em `/assets/fontes/`. **Nunca base64 no CSS** — no projeto de origem isso inchava o CSS de 12KB para 126KB
- `@font-face` com `font-display:swap` **no CSS crítico inline de cada página**, não só no externo. Só no externo → o navegador trava a pintura do texto esperando a decisão da fonte (mediu 2500ms de atraso; corrigido caiu pra 610ms)
- `<link rel="preload" as="font" type="font/woff2" crossorigin>` para as 3 principais
- Zero Google Fonts ou qualquer CDN de fonte
- **Nunca** fallback com `size-adjust`/`ascent-override` — parece correto, mas piorou o CLS de 0,113 para 0,197 e foi revertido

### CSS
- `assets/style.css` único e compartilhado. **Nunca re-inlinar o arquivo inteiro** numa página (mata o cache entre páginas)
- Crítico inline = só `@font-face` + reset + `:root` + hero
- **Não duplicar** no crítico regras que já existem no externo
- Carregamento exato:
  ```html
  <link rel="preload" as="style" href="assets/style.css" onload="this.onload=null;this.rel='stylesheet'"/>
  <noscript><link rel="stylesheet" href="assets/style.css"/></noscript>
  ```
  **Caminhos relativos** para CSS, fontes, imagens, favicon e links internos (`assets/…` na raiz, `../assets/…` no cluster). Caminho absoluto (`/assets/…`) quebra o estilo ao abrir o HTML direto do disco (`file://` resolve para `C:/assets/`). No servidor as URLs finais são idênticas. Canonical, og e JSON-LD continuam com URL absoluta `https://`.
  `<link rel="stylesheet">` direto = "render-blocking" no Lighthouse (~470ms)
- Cores só via variáveis do `:root`
- **Nunca `opacity` em texto** — quebra contraste e derruba Acessibilidade

### JavaScript de terceiro
**Padrão: nenhum.** Caso real: o botão "Fontes Preferidas" do Google (`publisher.js`) levou Desempenho de **98 para 72** — 220KB do gstatic, 92KB não usados.

**Adiar para `window.addEventListener('load')` NÃO resolve.** O Lighthouse mede até o fim do carregamento. Só Consent Mode (que impede o download) funciona.

Antes de adicionar qualquer script externo: avisar o risco e esperar decisão.

### Analytics
GA4 atrás de Consent Mode v2 — sem aceite, `gtag.js` nunca baixa. Banner `position:fixed` num canto, `hidden` por padrão, `role="region"` + `aria-label`, escolha em `localStorage` por 12 meses. **Nunca GTM junto com gtag.js** (duplicação custava 257KB).

### Cada página
- `<title>` 40-60 chars, `<meta name="description">` 120-160 chars, `<link rel="canonical">` próprio
- `og:`/`twitter:`/`JSON-LD WebPage.name` **alinhados com o title da própria página**
- Nunca reaproveitar title/description de outra página (é a canibalização que o cluster existe para evitar)
- Um `<h1>`, hierarquia sem pulos, ~1000+ palavras
- Toda `<img>` com `width`, `height`, `alt`, `loading="lazy"`
- Números afirmados levam fonte e data ao lado

### JSON-LD
Raiz: `ProfessionalService` + `Person` + `WebSite` + `WebPage` + `FAQPage`.
Cluster: `Service` + `WebPage` + `BreadcrumbList` + `FAQPage` escopados à própria URL.

`@id` sempre URL absoluta da própria entidade. Incluir: `knowsAbout` com `@id` de Wikidata + nós `Thing`, `DefinedTerm` do método próprio, `hasCredential`, `openingHoursSpecification`, `geo`, `areaServed`, `alternateName`, `sameAs`.

**Credencial declarada no schema precisa aparecer no HTML visível.**

Validar antes de publicar:
```bash
python -c "
import re,json
h=open('index.html',encoding='utf-8').read()
for b in re.findall(r'<script type=\"application/ld\+json\">(.*?)</script>',h,re.S):
    d=json.loads(b); print('OK —',[n.get('@type') for n in d.get('@graph',[])])
"
```

## Deploy

```bash
# 1. subir
curl -T "index.html" "ftp://<HOST>:21/public_html/index.html" --user '<USER>:<SENHA>' -sS

# 2. conferir no ar
curl -s "https://paulahernandezoficial.com.br/" | grep -o "<trecho que mudou>"

# 3. IndexNow (Bing/Yandex — Google não adota)
curl -s -X POST "https://api.indexnow.org/indexnow" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{"host":"paulahernandezoficial.com.br","key":"137f9f9d492df6f9458e0da3c287f2559c864636b1c3854ea3989a4ae8df6908","keyLocation":"https://paulahernandezoficial.com.br/137f9f9d492df6f9458e0da3c287f2559c864636b1c3854ea3989a4ae8df6908.txt","urlList":["https://paulahernandezoficial.com.br/"]}' \
  -w "\nHTTP %{http_code}\n"
```

4. **Avisar para pedir reindexação no Google Search Console** — obrigatório a cada publicação de HTML
5. Rodar PageSpeed e comparar com a medição anterior

### Gotchas de deploy
- `htaccess` é versionado sem ponto; no servidor precisa virar `.htaccess`
- `sitemap.xml` pode listar URLs que não existem neste repo (moram direto no servidor). Antes de remover alguma, confirmar com `curl` se responde 200
- `site.webmanifest` referencia ícones que podem não estar no repo; `theme_color` deve bater com `<meta name="theme-color">`

## Quando a nota cair

Aprendido do jeito difícil — três correções encadeadas por hipótese pioraram o CLS de 0,113 para 0,197.

1. **Não corrigir por suposição.** Pedir o detalhamento que nomeia os elementos ("Causas da troca de layout", "Detalhamento da LCP")
2. **Uma mudança por vez**, medindo entre cada uma
3. **Não melhorou → reverter imediatamente.** Nunca empilhar outra teoria
4. **Suspeitar primeiro da última coisa adicionada**, sobretudo script de terceiro
5. Item "Fora da pontuação" é informativo — não vale risco

## Checklist antes de publicar

```
[ ] Zero requisição externa (fonte/CSS/JS) — exceto gtag atrás de consent
[ ] CSS externo < 20KB via preload+onload
[ ] @font-face com font-display:swap no crítico inline
[ ] preload das 3 fontes principais
[ ] Nenhum opacity em texto
[ ] Toda <img> com width + height + alt
[ ] JSON-LD valida como JSON
[ ] title 40-60 / description 120-160
[ ] og/twitter/WebPage.name alinhados
[ ] Um H1, hierarquia sem pulos
[ ] URLs do sitemap retornam 200
[ ] llms.txt, robots.txt, chave IndexNow na raiz
[ ] raiz responde 200, www responde 301
```
