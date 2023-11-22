//
//  DataSessionDelegate.swift
//  ZonPlayer
//
//  Created by 李文康 on 2023/11/15.
//

import CoreServices

final class DataSessionDelegate: NSObject {
    let onMetaData = ZPDelegate<(URLSessionTask, ZPC.MetaData), Void>()
    let onData = ZPDelegate<(URLSessionTask, Data), Void>()
    let onFinished = ZPDelegate<URLSessionTask, Void>()
    let onFailed = ZPDelegate<(URLSessionTask, ZonPlayer.Error), Void>()

    @Protected private var _buffer = Data()

    private let _bufferSize = 10 * 1024
}

extension DataSessionDelegate: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                credential = URLCredential(trust: serverTrust)
                disposition = .useCredential
            }
        } else {
            disposition = .cancelAuthenticationChallenge
        }

        completionHandler(disposition, credential)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let metaData = response.__zon_metaData {
            onMetaData.call((dataTask, metaData))
            completionHandler(.allow)
        } else {
            onFailed.call((dataTask, .cacheFailed(.invalidStreamingResponse(response))))
            completionHandler(.cancel)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        $_buffer.write {
            $0.append(data)

            if $0.count > _bufferSize {
                onData.call((dataTask, $0))
                $0 = Data()
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        $_buffer.write {
            if $0.count > 0 && error == nil {
                onData.call((task, $0))
                $0 = Data()
            }
        }

        if let originalError = error {
            let error = ZonPlayer.Error.cacheFailed(.streamingRequestFailed(task, originalError))
            onFailed.call((task, error))
        } else {
            onFinished.call(task)
        }
    }
}

extension URLResponse {
    fileprivate var __zon_metaData: ZPC.MetaData? {
        let mimeType = mimeType ?? ""
        var isSupported = false
        for type in ["video/", "audio/", "application"] where mimeType.range(of: type) != nil {
            isSupported = true; break
        }

        let contentType = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassMIMEType,
            mimeType as CFString,
            nil
        )?.takeRetainedValue() as? String
        guard isSupported, let contentType else { return nil }

        var isByteRangeAccessSupported: Bool = false
        var contentLength: Int64 = expectedContentLength
        if let httpResponse = self as? HTTPURLResponse {
            let arKeys = ["Accept-Ranges", "accept-ranges", "Accept-ranges", "accept-Ranges"]
            let crKeys = ["Content-Range", "content-range", "Content-range", "content-Range"]
            for arKey in arKeys where (httpResponse.allHeaderFields[arKey] as? String) == "bytes" {
                isByteRangeAccessSupported = true
            }
            for crKey in crKeys {
                if let value = httpResponse.allHeaderFields[crKey] as? String,
                   let bytesInInt64 = Int64(value.split(separator: "/").last ?? "") {
                    contentLength = bytesInInt64
                }
            }
        }

        return .init(
            contentType: contentType,
            isByteRangeAccessSupported: isByteRangeAccessSupported,
            contentLength: Int(contentLength)
        )
    }
}
