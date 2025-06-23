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

public enum TestData {
  public enum RunStatus {
    public static func notStarted() -> PhotosExporterLib.RunStatus {
      return PhotosExporterLib.RunStatus()
    }

    public static func started() -> PhotosExporterLib.RunStatus {
      let status = PhotosExporterLib.RunStatus()
      status.start()
      return status
    }

    public static func skipped() -> PhotosExporterLib.RunStatus {
      let status = PhotosExporterLib.RunStatus()
      status.skipped()
      return status
    }

    public static func complete(runTime: Double) -> PhotosExporterLib.RunStatus {
      let status = PhotosExporterLib.RunStatus()
      status.complete(runTime: runTime)
      return status
    }

    public static func failed(error: String) -> PhotosExporterLib.RunStatus {
      let status = PhotosExporterLib.RunStatus()
      status.failed(error: error)
      return status
    }
  }

  public enum RunStatusWithProgress {
    public static func notStarted() -> PhotosExporterLib.RunStatusWithProgress {
      return PhotosExporterLib.RunStatusWithProgress()
    }

    public static func started() -> PhotosExporterLib.RunStatusWithProgress {
      let status = PhotosExporterLib.RunStatusWithProgress()
      status.start()
      return status
    }

    public static func progress(progress: Double) -> PhotosExporterLib.RunStatusWithProgress {
      let status = PhotosExporterLib.RunStatusWithProgress()
      status.start()
      status.startProgress(toProcess: Int(100.0 / progress))
      status.processed(count: 100)
      return status
    }

    public static func skipped() -> PhotosExporterLib.RunStatusWithProgress {
      let status = PhotosExporterLib.RunStatusWithProgress()
      status.skipped()
      return status
    }

    public static func complete(runTime: Double) -> PhotosExporterLib.RunStatusWithProgress {
      let status = PhotosExporterLib.RunStatusWithProgress()
      status.complete(runTime: runTime)
      return status
    }

    public static func failed(error: String) -> PhotosExporterLib.RunStatusWithProgress {
      let status = PhotosExporterLib.RunStatusWithProgress()
      status.failed(error: error)
      return status
    }
  }

  public enum PhotosExporter {
    public static func started(
      assetExporterStatus: AssetExporterStatus? = nil,
      collectionExporterStatus: CollectionExporterStatus? = nil,
      fileExporterStatus: FileExporterStatus? = nil,
      symlinkCreatorStatus: SymlinkCreatorStatus? = nil,
    ) -> PhotosExporterLib.Status {
      let status = PhotosExporterLib.Status(
        assetExporterStatus: assetExporterStatus ?? AssetExporter.notStarted(),
        collectionExporterStatus: collectionExporterStatus ?? CollectionExporter.notStarted(),
        fileExporterStatus: fileExporterStatus ?? FileExporter.notStarted(),
        symlinkCreatorStatus: symlinkCreatorStatus ?? SymlinkCreator.notStarted(),
      )
      status.start()
      return status
    }
  }

  public enum AssetExporter {
    public static func notStarted(
      exportAssetStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
      markDeletedStatus: PhotosExporterLib.RunStatus? = nil,
      removeExpiredStatus: PhotosExporterLib.RunStatus? = nil,
    ) -> AssetExporterStatus {
      return AssetExporterStatus(
        exportAssetStatus: exportAssetStatus,
        markDeletedStatus: markDeletedStatus,
        removeExpiredStatus: removeExpiredStatus,
      )
    }

    public static func started(
      exportAssetStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
      markDeletedStatus: PhotosExporterLib.RunStatus? = nil,
      removeExpiredStatus: PhotosExporterLib.RunStatus? = nil,
    ) -> AssetExporterStatus {
      let status = AssetExporterStatus(
        exportAssetStatus: exportAssetStatus,
        markDeletedStatus: markDeletedStatus,
        removeExpiredStatus: removeExpiredStatus,
      )
      status.start()
      return status
    }

    public static func skipped() -> AssetExporterStatus {
      let status = AssetExporterStatus()
      status.skipped()
      return status
    }

    public static func complete(
      runTime: Double,
      exportAssetStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
      markDeletedStatus: PhotosExporterLib.RunStatus? = nil,
      removeExpiredStatus: PhotosExporterLib.RunStatus? = nil,
    ) -> AssetExporterStatus {
      let status = AssetExporterStatus(
        exportAssetStatus: exportAssetStatus,
        markDeletedStatus: markDeletedStatus,
        removeExpiredStatus: removeExpiredStatus,
      )
      status.complete(runTime: runTime)
      return status
    }

    public static func failed(
      error: String,
      exportAssetStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
      markDeletedStatus: PhotosExporterLib.RunStatus? = nil,
      removeExpiredStatus: PhotosExporterLib.RunStatus? = nil,
    ) -> AssetExporterStatus {
      let status = AssetExporterStatus(
        exportAssetStatus: exportAssetStatus,
        markDeletedStatus: markDeletedStatus,
        removeExpiredStatus: removeExpiredStatus,
      )
      status.failed(error: error)
      return status
    }
  }

  public enum CollectionExporter {
    public static func notStarted() -> CollectionExporterStatus {
      return CollectionExporterStatus()
    }
  }

  public enum FileExporter {
    public static func notStarted(
      copyStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
      deleteStatus: PhotosExporterLib.RunStatusWithProgress? = nil,
    ) -> FileExporterStatus {
      return FileExporterStatus(
        copyStatus: copyStatus,
        deleteStatus: deleteStatus,
      )
    }
  }

  public enum SymlinkCreator {
    public static func notStarted() -> SymlinkCreatorStatus {
      return SymlinkCreatorStatus()
    }
  }
}
