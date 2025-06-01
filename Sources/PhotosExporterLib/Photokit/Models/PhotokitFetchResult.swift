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

protocol PhotokitFetchResultProtocol<Element> {
  associatedtype Element
  var count: Int { get }
  func reset()
  func hasNext() -> Bool
  func next() async throws -> Element?
}

protocol AssetFetchResultProtocol: PhotokitFetchResultProtocol<PhotokitAsset> {}

class PhotokitFetchResult<IN: AnyObject, OUT> {
  private let fetchResult: PHFetchResult<IN>
  private let transformer: (IN) async throws -> PhotokitFetchTransformResult<OUT>
  public let count: Int
  private var elementIndex: Int

  init(
    _ fetchResult: PHFetchResult<IN>,
    _ transformer: @escaping (IN) async throws -> PhotokitFetchTransformResult<OUT>,
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

  func next() async throws -> OUT? {
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

class PhotokitFetchResultBatch<IN: AnyObject, OUT> {
  private let fetchResults: [PhotokitFetchResult<IN, OUT>]
  public let count: Int
  private var fetchResultIndex: Int

  init(
    _ fetchResults: [PhotokitFetchResult<IN, OUT>]
  ) {
    self.fetchResults = fetchResults
    self.count = fetchResults.reduce(0) { sum, res in
      sum + res.count
    }
    self.fetchResultIndex = 0
  }

  convenience init(
    _ fetchResult: PhotokitFetchResult<IN, OUT>,
  ) {
    self.init([fetchResult])
  }

  func reset() {
    for res in self.fetchResults {
      res.reset()
    }
    self.fetchResultIndex = 0
  }

  func hasNext() -> Bool {
    guard fetchResultIndex < fetchResults.count else {
      return false
    }
    return fetchResults[fetchResultIndex].hasNext()
  }

  func next() async throws -> OUT? {
    guard fetchResultIndex < fetchResults.count else {
      // All elements of all Results emitted
      return nil
    }

    guard fetchResults[fetchResultIndex].hasNext() else {
      fetchResultIndex += 1
      return try await next()
    }

    return try await fetchResults[fetchResultIndex].next()
  }
}

class AssetFetchResult: PhotokitFetchResult<PHAsset, PhotokitAsset>, AssetFetchResultProtocol {}
class AssetFetchResultBatch: PhotokitFetchResultBatch<PHAsset, PhotokitAsset>, AssetFetchResultProtocol {}

enum PhotokitFetchTransformResult<T> {
  case success(T)
  case failure(Error)
  case skip
}
