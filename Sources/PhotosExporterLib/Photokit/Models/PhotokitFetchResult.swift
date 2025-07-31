/*
Copyright (C) 2025 Adam Borocz

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
import Photos

protocol PhotokitFetchResultProtocol<Element>: Sendable {
  associatedtype Element
  var count: Int { get }
  func reset() async
  func hasNext() async -> Bool
  func next() async throws -> Element?
}

protocol AssetFetchResultProtocol: PhotokitFetchResultProtocol<PhotokitAsset> {}

actor AssetFetchResult: AssetFetchResultProtocol {
  private let fetchResult: PHFetchResult<PHAsset>
  private let transformer: (PHAsset) async throws -> PhotokitFetchTransformResult<PhotokitAsset>
  public let count: Int
  private var elementIndex: Int

  init(
    _ fetchResult: PHFetchResult<PHAsset>,
    _ transformer: @escaping @Sendable (PHAsset) async throws -> PhotokitFetchTransformResult<PhotokitAsset>,
  ) {
    self.fetchResult = fetchResult
    self.transformer = transformer
    self.count = fetchResult.count
    self.elementIndex = 0
  }

  func reset() {
    self.elementIndex = 0
  }

  func hasNext() -> Bool {
    return elementIndex < fetchResult.count
  }

  func next() async throws -> PhotokitAsset? {
    guard elementIndex < fetchResult.count else {
      return nil
    }

    let res = try await transformer(
      fetchResult.object(at: elementIndex)
    )
    elementIndex += 1

    switch res {
    case .success(let out): return out
    case .failure(let err): throw err
    case .skip: return try await next()
    }
  }
}

actor AssetFetchResultBatch: AssetFetchResultProtocol {
  private let fetchResults: [AssetFetchResult]
  public let count: Int
  private var fetchResultIndex: Int

  init(
    _ fetchResults: [AssetFetchResult]
  ) {
    self.fetchResults = fetchResults
    self.count = fetchResults.reduce(0) { sum, res in
      sum + res.count
    }
    self.fetchResultIndex = 0
  }

  init(
    _ fetchResult: AssetFetchResult,
  ) {
    self.init([fetchResult])
  }

  func reset() async {
    for res in self.fetchResults {
      await res.reset()
    }
    self.fetchResultIndex = 0
  }

  func hasNext() async -> Bool {
    guard fetchResultIndex < fetchResults.count else {
      return false
    }
    return await fetchResults[fetchResultIndex].hasNext()
  }

  func next() async throws -> PhotokitAsset? {
    guard fetchResultIndex < fetchResults.count else {
      // All elements of all Results emitted
      return nil
    }

    guard await fetchResults[fetchResultIndex].hasNext() else {
      fetchResultIndex += 1
      return try await next()
    }

    return try await fetchResults[fetchResultIndex].next()
  }
}

enum PhotokitFetchTransformResult<T: Sendable> {
  case success(T)
  case failure(Error)
  case skip
}
