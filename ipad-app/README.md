# Gravador de Aulas — App para iPad

App nativo em **SwiftUI** para iPadOS que grava aulas em tempo real, transcreve
a voz automaticamente e salva a transcrição em **Word (.docx)** na pasta de
arquivos do iPad (visível no app **Arquivos**).

## O que ele faz

1. Você toca no botão grande de microfone → o app pede permissão de microfone e
   de reconhecimento de voz e começa a **gravar**.
2. A fala aparece **transcrita em tempo real** na tela (você pode editar o texto).
3. Ao tocar em **parar**, você dá um título e toca em **Salvar em Word (.docx)**.
4. O arquivo `.docx` é gravado na pasta **Documents** do app, que aparece em
   **Arquivos › No meu iPad › Gravador de Aulas**. Dá para abrir no Word/Pages,
   compartilhar ou enviar por e-mail.

A transcrição usa o framework **Speech** da Apple, com reconhecimento
**no próprio dispositivo** quando disponível (o áudio não sai do iPad), e
reinicia automaticamente as sessões de reconhecimento para dar conta de
**aulas longas**.

## Como abrir e rodar

Requer **macOS com Xcode 16+** e um **iPad com iPadOS 17+** (o reconhecimento
de voz não funciona no Simulador — use um iPad real).

1. Abra `GravadorDeAulas.xcodeproj` no Xcode.
2. Em **Signing & Capabilities**, selecione seu *Team* (conta Apple gratuita
   serve para instalar no seu próprio iPad).
3. Conecte o iPad, selecione-o como destino e clique em **Run** (▶).
4. Na primeira gravação, aceite as permissões de **Microfone** e de
   **Reconhecimento de Voz**.

## Estrutura do código

| Arquivo | Responsabilidade |
|---|---|
| `GravadorDeAulasApp.swift` | Ponto de entrada do app. |
| `ContentView.swift` | Interface (iPad): botão de gravar, transcrição ao vivo, lista de aulas salvas. |
| `LectureRecorder.swift` | Gravação de áudio (`AVAudioEngine`) + transcrição em tempo real (`SFSpeechRecognizer`). |
| `DocxExporter.swift` | Monta o pacote `.docx` (Office Open XML) a partir do texto. |
| `ZipArchive.swift` | Escreve o contêiner ZIP do `.docx` em Swift puro, sem dependências. |
| `RecordingsStore.swift` | Salva/lista/apaga os `.docx` na pasta Documents. |

## Ajustes úteis

- **Idioma da transcrição:** em `LectureRecorder.swift`, o `localeIdentifier`
  padrão é `"pt-BR"`. Troque para outro idioma se precisar.
- **Aparecer no app Arquivos:** garantido pelas chaves `UIFileSharingEnabled` e
  `LSSupportsOpeningDocumentsInPlace`, já configuradas no projeto.

## Limitações

- O reconhecimento on-device pode variar de qualidade conforme o idioma e o
  ruído do ambiente; a transcrição é editável antes de salvar.
- O app grava a **transcrição** em `.docx`. Se quiser guardar também o **áudio**
  (`.m4a`), dá para estender o `LectureRecorder` para gravar o arquivo em
  paralelo — é um próximo passo natural.
