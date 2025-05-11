# Photos Exporter Library

A Swift Library used to replicate the local Apple Photos library on MacOS into a target folder by:
* Mirroring Assets, Resources, Albums and Folders into a SQLite database in the export folder
* Copying all Resources into the export folder, organised by date and location (where available)
* Recreating the Album and Folder structures using symlinks pointing to the copied Resources

Under the hood it mainly uses the Photokit API to access the Photos Library; the only exception
is when retrieving reverse geocoding data for Assets, which is not available via the API - this is
instead read directly from the SQLite database that Photos uses internally.

## Usage

```swift
let exporter = try await PhotosExporterLib.create(exportBaseDir: "/tmp/export")
let result = try await exporter.export()
print(result)
/*
ExportResult(
  assetExport: PhotosExporterLib.AssetExportResult(
    assetInserted: 0,
    assetUpdated: 0,
    assetUnchanged: 0,
    assetSkipped: 0,
    fileInserted: 0,
    fileUpdated: 0,
    fileUnchanged: 0,
    fileSkipped: 0
  ),
  collectionExport: PhotosExporterLib.CollectionExportResult(
    folderInserted: 0,
    folderUpdated: 0,
    folderUnchanged: 0,
    albumInserted: 0,
    albumUpdated: 0,
    albumUnchanged: 0
  ),
  fileCopy: PhotosExporterLib.FileCopyResults(
    copied: 0,
    removed: 0
  )
)
*/
```