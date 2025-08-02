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

public protocol Timeable {
  var runTime: Double { get }
}

public struct EmptyTaskSuccess: Timeable, Sendable {
  public let runTime: Double
  public init(runTime: Double) {
    self.runTime = runTime
  }
}

public struct TaskProgress: Sendable {
  public let toProcess: Int
  public let processed: Int
  public let progress: Double

  public init(
    toProcess: Int,
    processed: Int,
  ) {
    self.toProcess = toProcess
    self.processed = processed
    self.progress = toProcess == 0 ? 0 : Double(processed) / Double(toProcess)
  }

  public init(toProcess: Int) {
    self.toProcess = toProcess
    self.processed = 0
    self.progress = 0
  }

  func processed(_ count: Int = 1) -> TaskProgress {
    return TaskProgress(
      toProcess: toProcess,
      processed: processed + count,
    )
  }
}

public enum TaskStatus<SuccessResult: Sendable & Timeable>: Sendable {
  case notStarted, skipped, cancelled
  case running(TaskProgress?)
  case complete(SuccessResult)
  case failed(String)
}
