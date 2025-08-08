# Photos Exporter Library

[![PhotosExporterLib CI](https://github.com/motns/PhotosExporterLib.swift/actions/workflows/CI.yml/badge.svg)](https://github.com/motns/PhotosExporterLib.swift/actions/workflows/CI.yml)

A Swift Library used to replicate the local Apple Photos library on MacOS into a target folder by:
* Mirroring Assets, Resources, Albums and Folders into a SQLite database in the export folder
* Copying all Resources into the export folder, organised by date and location (where available)
* Recreating the Album and Folder structures using symlinks pointing to the copied Resources

Under the hood it mainly uses the Photokit API to access the Photos Library; the only exception
is when retrieving reverse geocoding data for Assets, which is not available via the API - this is
instead read directly from the SQLite database that Photos uses internally.

## Usage

The library can be instantiated by giving it a folder to export into (if the folder doesn't exist,
it will be created). It can then simply be run by calling `.export()`.
```swift
import PhotosExporterLib

let exporter = try await PhotosExporterLib.create(exportBaseDir: "/tmp/export")
let result = try await exporter.export()
print(result)
/*
PhotosExporterLib.Result(
  assetExport: PhotosExporterLib.AssetExportResult(
    assetInserted: 0,
    assetUpdated: 0,
    assetUnchanged: 0,
    assetSkipped: 0,
    assetMarkedForDeletion: 0,
    assetDeleted: 0,
    fileInserted: 0,
    fileUpdated: 0,
    fileUnchanged: 0,
    fileSkipped: 0,
    fileMarkedForDeletion: 0,
    fileDeleted: 0,
    runTime: 0
  ),
  collectionExport: PhotosExporterLib.CollectionExportResult(
    folderInserted: 0,
    folderUpdated: 0,
    folderUnchanged: 0,
    folderDeleted: 0,
    albumInserted: 0,
    albumUpdated: 0,
    albumUnchanged: 0,
    albumDeleted: 0,
    runTime: 0
  ),
  fileExport: PhotosExporterLib.FileCopyResult(
    copied: 0,
    deleted: 0,
    runTime: 0
  ),
  runTime: 0
)
*/
```

A custom logger can be provided to the library - by default it will log to
standard out at INFO level.
```swift
import Logging
import PhotosExporterLib

var logger = Logger(label: "com.example.PhotosExporter")
logger.logLevel = .debug

let exporter = try await PhotosExporterLib.create(
  exportBaseDir: "/tmp/export",
  logger: logger,
)
let result = try await exporter.export()
```

It is also possible to disable individual modules in the exporter via arguments
to the `.export()` method. There's more on the behaviour of these modules further below.
```swift
let result = try await exporter.export(
  assetExportEnabled: true, // Syncs Assets and Resources to the DB
  collectionExportEnabled: true, // Syncs Albums and Folders to the DB
  fileManagerEnabled: false, // Copies new Resources and deletes removed ones
  symlinkCreatorEnabled: false, // Creates symlinks for folder/album structure locally
)
```

By default Assets and Resources are removed from the DB and the local file system
30 days after they were detected as deleted in Photokit. This can be changed via an
argument when initialising the library.
```swift
let exporter = try await PhotosExporterLib.create(
  exportBaseDir: "/tmp/export",
  expiryDays: 15,
)
```