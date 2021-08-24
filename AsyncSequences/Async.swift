//
//  Async.swift
//  Async
//
//  Created by Chris Eidhof on 23.08.21.
//

import Foundation

func sample() async throws {
    let start = Date.now
    let url = Bundle.main.url(forResource: "enwik8", withExtension: "zlib")!
    var counter = 0
    let fileHandle = try FileHandle(forReadingFrom: url)
    for try await chunk in fileHandle.bytes.chunked.decompressed {
        print(String(decoding: chunk, as: UTF8.self))
        counter += 1
    }
    print(counter)
    print("Duration: \(Date.now.timeIntervalSince(start))")
}

extension AsyncSequence where Element == UInt8 {
    var chunked: Chunked<Self> {
        Chunked(base: self)
    }
}

struct Chunked<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    var base: Base
    var chunkSize: Int = Compressor.bufferSize // todo
    typealias Element = Data
    
    struct AsyncIterator: AsyncIteratorProtocol {
        var base: Base.AsyncIterator
        var chunkSize: Int
        
        mutating func next() async throws -> Data? {
            var result = Data()
            while let element = try await base.next() {
                result.append(element)
                if result.count == chunkSize { return result }
            }
            return result.isEmpty ? nil : result
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator(), chunkSize: chunkSize)
    }
}

extension AsyncSequence where Element == Data {
    var decompressed: Compressed<Self> {
        Compressed(base: self, method: .decompress)
    }
}

struct Compressed<Base: AsyncSequence>: AsyncSequence where Base.Element == Data {
    var base: Base
    var method: Compressor.Method
    typealias Element = Data
    
    struct AsyncIterator: AsyncIteratorProtocol {
        var base: Base.AsyncIterator
        var compressor: Compressor
        
        mutating func next() async throws -> Data? {
            if let chunk = try await base.next() {
                return try compressor.compress(chunk)
            } else {
                let result = try compressor.eof()
                return result.isEmpty ? nil : result
            }
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        let c = Compressor(method: method)
        return AsyncIterator(base: base.makeAsyncIterator(), compressor: c)
    }
}
