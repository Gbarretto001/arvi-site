import Foundation

/// Gera um documento Word (.docx) a partir do texto transcrito.
/// Um .docx é um pacote ZIP com arquivos XML no formato Office Open XML.
enum DocxExporter {

    static func makeDocx(title: String, body: String) -> Data {
        let entries: [ZipArchive.Entry] = [
            .init(path: "[Content_Types].xml", data: Data(contentTypesXML.utf8)),
            .init(path: "_rels/.rels", data: Data(relsXML.utf8)),
            .init(path: "word/document.xml", data: Data(documentXML(title: title, body: body).utf8))
        ]
        return ZipArchive.create(entries: entries)
    }

    // MARK: - Partes fixas do pacote

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """

    private static let relsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """

    // MARK: - Corpo do documento

    private static func documentXML(title: String, body: String) -> String {
        var paragraphs = titleParagraph(title)

        let lines = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            paragraphs += bodyParagraph("(Sem transcrição.)")
        } else {
            for line in lines {
                paragraphs += bodyParagraph(line)
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
        \(paragraphs)
            <w:sectPr>
              <w:pgSz w:w="11906" w:h="16838"/>
              <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
            </w:sectPr>
          </w:body>
        </w:document>
        """
    }

    private static func titleParagraph(_ text: String) -> String {
        """
            <w:p>
              <w:pPr><w:spacing w:after="240"/></w:pPr>
              <w:r>
                <w:rPr><w:b/><w:sz w:val="36"/></w:rPr>
                <w:t xml:space="preserve">\(escape(text))</w:t>
              </w:r>
            </w:p>
        """
    }

    private static func bodyParagraph(_ text: String) -> String {
        """
            <w:p>
              <w:pPr><w:spacing w:after="120"/></w:pPr>
              <w:r>
                <w:rPr><w:sz w:val="24"/></w:rPr>
                <w:t xml:space="preserve">\(escape(text))</w:t>
              </w:r>
            </w:p>
        """
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
