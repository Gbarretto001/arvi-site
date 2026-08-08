import Foundation

/// Cria um arquivo ZIP simples (método "store", sem compressão) totalmente em
/// Swift, sem dependências externas. É suficiente para montar um pacote .docx
/// válido (que é apenas um ZIP contendo arquivos XML).
enum ZipArchive {

    struct Entry {
        let path: String
        let data: Data
    }

    static func create(entries: [Entry]) -> Data {
        var output = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let nameData = Data(entry.path.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let localHeaderOffset = offset

            var local = Data()
            local.appendLE(UInt32(0x04034b50)) // assinatura do cabeçalho local
            local.appendLE(UInt16(20))         // versão necessária
            local.appendLE(UInt16(0))          // flags
            local.appendLE(UInt16(0))          // compressão = store
            local.appendLE(UInt16(0))          // hora de modificação
            local.appendLE(UInt16(0x21))       // data de modificação
            local.appendLE(crc)
            local.appendLE(size)               // tamanho comprimido
            local.appendLE(size)               // tamanho descomprimido
            local.appendLE(UInt16(nameData.count))
            local.appendLE(UInt16(0))          // tamanho do campo extra
            local.append(nameData)
            local.append(entry.data)

            output.append(local)
            offset += UInt32(local.count)

            centralDirectory.appendLE(UInt32(0x02014b50)) // assinatura central
            centralDirectory.appendLE(UInt16(20))         // versão criadora
            centralDirectory.appendLE(UInt16(20))         // versão necessária
            centralDirectory.appendLE(UInt16(0))          // flags
            centralDirectory.appendLE(UInt16(0))          // compressão
            centralDirectory.appendLE(UInt16(0))          // hora
            centralDirectory.appendLE(UInt16(0x21))       // data
            centralDirectory.appendLE(crc)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(UInt16(nameData.count))
            centralDirectory.appendLE(UInt16(0))          // extra
            centralDirectory.appendLE(UInt16(0))          // comentário
            centralDirectory.appendLE(UInt16(0))          // disco inicial
            centralDirectory.appendLE(UInt16(0))          // atributos internos
            centralDirectory.appendLE(UInt32(0))          // atributos externos
            centralDirectory.appendLE(localHeaderOffset)
            centralDirectory.append(nameData)
        }

        let centralOffset = offset
        let centralSize = UInt32(centralDirectory.count)
        output.append(centralDirectory)

        var end = Data()
        end.appendLE(UInt32(0x06054b50))       // fim do diretório central
        end.appendLE(UInt16(0))                // número do disco
        end.appendLE(UInt16(0))                // disco do diretório central
        end.appendLE(UInt16(entries.count))    // entradas neste disco
        end.appendLE(UInt16(entries.count))    // total de entradas
        end.appendLE(centralSize)
        end.appendLE(centralOffset)
        end.appendLE(UInt16(0))                // comentário
        output.append(end)

        return output
    }

    // MARK: - CRC32

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) == 1 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = crcTable[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendLE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
