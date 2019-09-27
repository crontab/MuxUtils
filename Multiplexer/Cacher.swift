//
//  Cacher.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


let STANDARD_TTL: TimeInterval = 30 * 60

internal let jsonDecoder: JSONDecoder = { JSONDecoder() }()
internal let jsonEncoder: JSONEncoder = { JSONEncoder() }()


protocol Cacher {
	associatedtype T: Codable
	typealias K = String

	static func useCachedResultOn(error: Error) -> Bool
	static var timeToLive: TimeInterval { get }

	static func loadFromCache<T: Codable>(key: K, domain: String?) -> T?
	static func saveToCache<T: Codable>(_ result: T, key: K, domain: String?)
	static func clearCache(key: K, domain: String?)
	static func clearCacheMap(domain: String)
}


final class NoCacher<T: Codable>: Cacher {
	static func useCachedResultOn(error: Error) -> Bool { false }
	static var timeToLive: TimeInterval { 0 }

	static func loadFromCache<T: Codable>(key: K, domain: String?) -> T? { nil }
	static func saveToCache<T: Codable>(_ result: T, key: K, domain: String?) { }
	static func clearCache(key: K, domain: String?) { }
	static func clearCacheMap(domain: String) { }
}


extension FileManager {

	class func cacheDirectory(subDirectory: String, create: Bool) -> URL {
		let result = `default`.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(subDirectory)
		if create && !`default`.fileExists(atPath: result.path) {
			try! `default`.createDirectory(at: result, withIntermediateDirectories: true, attributes: nil)
		}
		return result
	}

	class func removeRecursively(_ url: URL?) {
		if let url = url {
			try? `default`.removeItem(at: url)
		}
	}
}


final class JSONDiskCacher<T: Codable>: Cacher {

	static func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }

	static var timeToLive: TimeInterval { STANDARD_TTL }

	static func loadFromCache<T: Codable>(key: K, domain: String?) -> T? {
		return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL(key: key, domain: domain, create: false)))
	}

	static func saveToCache<T: Codable>(_ result: T, key: K, domain: String?) {
		try! jsonEncoder.encode(result).write(to: cacheFileURL(key: key, domain: domain, create: true), options: .atomic)
	}

	static func clearCache(key: K, domain: String?) {
		FileManager.removeRecursively(cacheFileURL(key: key, domain: domain, create: false))
	}

	static func clearCacheMap(domain: String) {
		FileManager.removeRecursively(cacheDirURL(domain: domain, create: false))
	}

	private static func cacheFileURL(key: K, domain: String?, create: Bool) -> URL {
		return cacheDirURL(domain: domain, create: create).appendingPathComponent(key.description).appendingPathExtension("json")
	}

	private static func cacheDirURL(domain: String?, create: Bool) -> URL {
		let dir = "Mux/" + (domain != nil ? domain! + ".Map" : "")
		return FileManager.cacheDirectory(subDirectory: dir, create: create)
	}
}