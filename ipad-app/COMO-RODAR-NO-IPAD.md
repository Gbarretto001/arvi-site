# Como rodar o app direto no iPad (sem Mac)

Você vai usar o **Swift Playgrounds**, um app gratuito da Apple que compila e
roda apps de verdade no próprio iPad. Use a pasta **`GravadorDeAulas.swiftpm`**
(a versão em formato Xcode, na pasta `GravadorDeAulas/`, é para quem tem Mac).

## Passo a passo

### 1. Instale o Swift Playgrounds
Abra a **App Store** no iPad e instale o **Swift Playgrounds** (grátis). Requer
**iPadOS 17 ou mais recente**.

### 2. Baixe o projeto para o iPad
Escolha uma das formas:

- **Pelo GitHub (app Arquivos):** no repositório do projeto no GitHub, toque em
  **Code → Download ZIP**. O ZIP vai para a pasta **Downloads** no app Arquivos.
  Toque no ZIP para descompactar e entre em `ipad-app`.
- **Pelo app GitHub / Working Copy:** se usar um app de Git no iPad, clone o
  repositório normalmente.

### 3. Abra no Swift Playgrounds
1. Abra o app **Arquivos** e navegue até a pasta `ipad-app`.
2. Toque em **`GravadorDeAulas.swiftpm`** — ela abre automaticamente no Swift
   Playgrounds. (Se não abrir, deixe o dedo pressionado nela → **Compartilhar** →
   **Swift Playgrounds**.)

### 4. Rode
Toque no botão **▶ (Run)** no canto superior. O app abre em tela cheia dentro do
Swift Playgrounds.

- Na primeira gravação, o iPad vai pedir permissão de **Microfone** e de
  **Reconhecimento de Voz** — toque em **Permitir** nas duas.
- Toque no botão de microfone, fale, e veja a transcrição aparecer.
- Toque em parar, dê um título e toque em **Salvar em Word (.docx)**.

### 5. Onde ficam as aulas salvas
Os arquivos `.docx` ficam no app **Arquivos**, em
**No meu iPad → Gravador de Aulas**. Dá para abrir no Word/Pages, compartilhar
ou enviar por e-mail.

## Instalar como app fixo na tela inicial (opcional)
Dentro do Swift Playgrounds, no menu do projeto (ícone **•••** ou o nome do app
no topo), escolha a opção de **instalar/criar app**. Ele passa a aparecer como
um ícone normal na tela inicial do iPad, sem precisar abrir o Swift Playgrounds.

## Se aparecer algum erro
- **"Reconhecimento de voz indisponível":** confirme que o iPad está com
  internet na primeira vez e que o idioma português está disponível em
  **Ajustes → Geral → Teclado → Ditado**.
- **App fecha ao pedir permissão:** confira se o arquivo `Info.plist` está na
  pasta `.swiftpm` (ele é o que autoriza microfone + voz).

## Dúvidas comuns
- **Precisa de conta paga de desenvolvedor?** Não. Uma conta Apple normal
  (gratuita) já roda o app no seu próprio iPad.
- **Funciona no Simulador?** Não há simulador aqui — e é melhor assim: roda no
  aparelho real, que é onde o microfone e a transcrição funcionam de verdade.
