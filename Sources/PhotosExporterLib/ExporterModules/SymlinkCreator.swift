import Foundation
import Logging

struct SymlinkCreator {
  private let albumsDirURL: URL
  private let filesDirURL: URL
  private let exporterDB: ExporterDB
  private let fileManager: ExporterFileManagerProtocol
  private let timeProvider: TimeProvider
  private let logger: ClassLogger

  init(
    albumsDirURL: URL,
    filesDirURL: URL,
    exporterDB: ExporterDB,
    fileManager: ExporterFileManagerProtocol,
    timeProvider: TimeProvider,
    logger: Logger,
  ) {
    self.albumsDirURL = albumsDirURL
    self.filesDirURL = filesDirURL
    self.exporterDB = exporterDB
    self.fileManager = fileManager
    self.timeProvider = timeProvider
    self.logger = ClassLogger(logger: logger, className: "SymlinkCreator")
  }

  func create() throws {
    logger.info("Removing and recreating Album folders...")
    let startDate = timeProvider.getDate()

    _ = try fileManager.remove(url: albumsDirURL)
    _ = try fileManager.createDirectory(url: albumsDirURL)

    logger.debug("Creating Album directories and symlinks...")
    try createAlbumFolderSymlinks(
      folderId: Photokit.RootFolderId,
      folderDirURL: albumsDirURL,
    )
    logger.info("Albums folders created in \(timeProvider.secondsPassedSince(startDate))s")
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
            .appending(path: file.importedFileName)

          let linkDest = albumDirURL.appending(path: file.importedFileName)

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
}
