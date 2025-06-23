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
import Foundation
import Logging

struct SymlinkCreator {
  private let albumsDirURL: URL
  private let filesDirURL: URL
  private let locationsDirURL: URL
  private let topShotsDirURL: URL
  private let exporterDB: ExporterDB
  private let fileManager: ExporterFileManagerProtocol
  private let scoreThreshold: Int64
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  init(
    albumsDirURL: URL,
    filesDirURL: URL,
    locationsDirURL: URL,
    topShotsDirURL: URL,
    exporterDB: ExporterDB,
    fileManager: ExporterFileManagerProtocol,
    scoreThreshold: Int64,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.albumsDirURL = albumsDirURL
    self.filesDirURL = filesDirURL
    self.locationsDirURL = locationsDirURL
    self.topShotsDirURL = topShotsDirURL
    self.exporterDB = exporterDB
    self.fileManager = fileManager
    self.scoreThreshold = scoreThreshold
    self.timeProvider = timeProvider
    self.logger = ClassLogger(className: "SymlinkCreator", logger: logger)
  }

  func create(isEnabled: Bool = true) throws {
    guard isEnabled else {
      logger.warning("Symlink creator disabled - skipping")
      return
    }

    logger.info("Removing and recreating symlink folders...")
    let startDate = timeProvider.getDate()

    _ = try fileManager.remove(url: albumsDirURL)
    _ = try fileManager.createDirectory(url: albumsDirURL)

    logger.debug("Creating Album directories and symlinks...")
    try createAlbumFolderSymlinks(
      folderId: Photokit.RootFolderId,
      folderDirURL: albumsDirURL,
    )

    logger.debug("Creating location symlinks...")
    try createLocationSymlinks()

    logger.debug("Creating top shot symlinks...")
    try createTopShotsSymlinks()

    logger.info("Symlink folders created in \(timeProvider.secondsPassedSince(startDate))s")
  }

  private func createAlbumFolderSymlinks(folderId: String, folderDirURL: URL) throws {
    logger.debug("Creating symlinks and directories for Folder...", [
      "folder_id": "\(folderId)",
      "folder_dir": "\(folderDirURL)",
    ])

    let subfolders = try exporterDB.getFoldersWithParent(parentId: folderId)
    try createSubfolderSymlinks(subfolders: subfolders, folderDirURL: folderDirURL)

    let albums = try exporterDB.getAlbumsInFolder(folderId: folderId)
    try createAlbumSymlinks(albums: albums, folderDirURL: folderDirURL)
  }

  private func createSubfolderSymlinks(
    subfolders: [ExportedFolder],
    folderDirURL: URL,
  ) throws {
    for subfolder in subfolders {
      let pathSafeName = FileHelper.normaliseForPath(subfolder.name)

      if !pathSafeName.isEmpty {
        let subfolderDirURL = folderDirURL.appending(path: pathSafeName)

        logger.trace("Creating subdirectory for Subfolder...", [
          "folder_id": "\(subfolder.id)",
          "folder_dir": "\(subfolderDirURL.path(percentEncoded: false))",
        ])
        _ = try fileManager.createDirectory(url: subfolderDirURL)

        try createAlbumFolderSymlinks(
          folderId: subfolder.id,
          folderDirURL: subfolderDirURL,
        )
      } else {
        logger.warning("Cannot convert Folder name to path-safe version - skipping...", [
          "folder_id": "\(subfolder.id)",
          "name": "\(subfolder.name)",
        ])
      }
    }
  }

  private func createAlbumSymlinks(
    albums: [ExportedAlbum],
    folderDirURL: URL,
  ) throws {
    for album in albums {
      let pathSafeName = FileHelper.normaliseForPath(album.name)

      if !pathSafeName.isEmpty {
        let albumDirURL = folderDirURL.appending(path: pathSafeName)
        logger.trace("Creating subdirectory for Album...", [
          "album_id": "\(album.id)",
          "album_dir": "\(albumDirURL.path(percentEncoded: false))",
        ])
        _ = try fileManager.createDirectory(url: albumDirURL)

        for file in try exporterDB.getFilesForAlbum(albumId: album.id) {
          let linkSrc = filesDirURL
            .appending(path: file.importedFileDir)
            .appending(path: file.id)
          let linkDest = albumDirURL.appending(path: file.id)

          let res = try fileManager.createSymlink(src: linkSrc, dest: linkDest)
          if res == .exists {
            logger.trace("Symlink for Album File already exists", [
              "album_id": "\(album.id)",
              "link_src": "\(linkSrc.path(percentEncoded: false))",
              "link_dest": "\(linkDest.path(percentEncoded: false))",
            ])
          } else {
            logger.trace("Created symlink for Album File", [
              "album_id": "\(album.id)",
              "link_src": "\(linkSrc.path(percentEncoded: false))",
              "link_dest": "\(linkDest.path(percentEncoded: false))",
            ])
          }
        }
      } else {
        logger.warning("Cannot convert Album name to path-safe version - skipping", [
          "album_id": "\(album.id)",
          "name": "\(album.name)",
        ])
      }
    }
  }

  private func createLocationSymlinks() throws {
    let filesWithLocation = try exporterDB.getFilesWithLocation()

    for fileWithLocation in filesWithLocation {
      let file = fileWithLocation.exportedFile
      logger.trace("Creating location symlink for file...", [
        "file_id": "\(file.id)",
      ])

      let country = FileHelper.normaliseForPath(fileWithLocation.country)
      guard !country.isEmpty else {
        logger.warning("Cannot convert country name to path-safe version - skipping...", [
          "file_id": "\(file.id)",
          "country": "\(country)",
        ])
        continue
      }
      let city = FileHelper.normaliseForPath(fileWithLocation.city ?? "unknown")

      let dirURL = locationsDirURL
        .appending(path: country)
        .appending(path: city)
        .appending(path: DateHelper.getYearStr(fileWithLocation.createdAt))
        .appending(path: DateHelper.getYearMonthStr(fileWithLocation.createdAt))

      _ = try fileManager.createDirectory(url: dirURL)

      let linkSrc = filesDirURL
        .appending(path: file.importedFileDir)
        .appending(path: file.id)
      let linkDest = dirURL.appending(path: file.id)

      let res = try fileManager.createSymlink(src: linkSrc, dest: linkDest)
      if res == .exists {
        logger.trace("Symlink for file at geolocation already exists", [
          "file_id": "\(file.id)",
          "link_src": "\(linkSrc.path(percentEncoded: false))",
          "link_dest": "\(linkDest.path(percentEncoded: false))",
        ])
      } else {
        logger.trace("Created symlink for file at geolocation", [
          "file_id": "\(file.id)",
          "link_src": "\(linkSrc.path(percentEncoded: false))",
          "link_dest": "\(linkDest.path(percentEncoded: false))",
        ])
      }
    }
  }

  private func createTopShotsSymlinks() throws {
    let filesWithScore = try exporterDB.getFilesWithScore(threshold: scoreThreshold)
    _ = try fileManager.createDirectory(url: topShotsDirURL)

    for fileWithScore in filesWithScore {
      let file = fileWithScore.exportedFile
      logger.trace("Creating score symlink for file...", [
        "file_id": "\(file.id)",
      ])

      let linkSrc = filesDirURL
        .appending(path: file.importedFileDir)
        .appending(path: file.id)
      let linkDest = topShotsDirURL.appending(path: "\(fileWithScore.score)-\(file.id)")

      let res = try fileManager.createSymlink(src: linkSrc, dest: linkDest)
      if res == .exists {
        logger.trace("Symlink for file with score already exists", [
          "file_id": "\(file.id)",
          "link_src": "\(linkSrc.path(percentEncoded: false))",
          "link_dest": "\(linkDest.path(percentEncoded: false))",
        ])
      } else {
        logger.trace("Created symlink for file with score", [
          "file_id": "\(file.id)",
          "link_src": "\(linkSrc.path(percentEncoded: false))",
          "link_dest": "\(linkDest.path(percentEncoded: false))",
        ])
      }
    }
  }
}
