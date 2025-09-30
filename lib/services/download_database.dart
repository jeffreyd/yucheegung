import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DownloadDatabase {
  static final DownloadDatabase _instance = DownloadDatabase._internal();
  factory DownloadDatabase() => _instance;
  DownloadDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'yucheegung_downloads.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table for downloaded items (albums/playlists)
    await db.execute('''
      CREATE TABLE downloads (
        item_id TEXT PRIMARY KEY,
        item_type TEXT NOT NULL,
        item_name TEXT NOT NULL,
        artist_name TEXT,
        download_path TEXT NOT NULL,
        downloaded_at INTEGER NOT NULL,
        song_count INTEGER NOT NULL
      )
    ''');

    // Table for individual song downloads
    await db.execute('''
      CREATE TABLE downloaded_songs (
        song_id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL,
        song_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER,
        downloaded_at INTEGER NOT NULL,
        FOREIGN KEY (item_id) REFERENCES downloads (item_id) ON DELETE CASCADE
      )
    ''');

    // Index for faster lookups
    await db.execute('''
      CREATE INDEX idx_item_id ON downloaded_songs (item_id)
    ''');
  }

  /// Check if an item (album/playlist) is fully downloaded
  Future<bool> isItemDownloaded(String itemId) async {
    final db = await database;
    final result = await db.query(
      'downloads',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    return result.isNotEmpty;
  }

  /// Mark an item as downloaded
  Future<void> markItemAsDownloaded({
    required String itemId,
    required String itemType,
    required String itemName,
    String? artistName,
    required String downloadPath,
    required int songCount,
  }) async {
    final db = await database;
    await db.insert(
      'downloads',
      {
        'item_id': itemId,
        'item_type': itemType,
        'item_name': itemName,
        'artist_name': artistName,
        'download_path': downloadPath,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'song_count': songCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Add a downloaded song record
  Future<void> addDownloadedSong({
    required String songId,
    required String itemId,
    required String songName,
    required String filePath,
    int? fileSize,
  }) async {
    final db = await database;
    await db.insert(
      'downloaded_songs',
      {
        'song_id': songId,
        'item_id': itemId,
        'song_name': songName,
        'file_path': filePath,
        'file_size': fileSize,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all songs for a downloaded item
  Future<List<Map<String, dynamic>>> getSongsForItem(String itemId) async {
    final db = await database;
    return await db.query(
      'downloaded_songs',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'downloaded_at ASC',
    );
  }

  /// Get all downloaded items
  Future<List<Map<String, dynamic>>> getAllDownloads() async {
    final db = await database;
    return await db.query(
      'downloads',
      orderBy: 'downloaded_at DESC',
    );
  }

  /// Delete a downloaded item and all its songs
  Future<void> deleteDownload(String itemId) async {
    final db = await database;
    // First delete all songs (cascade should handle this, but being explicit)
    await db.delete(
      'downloaded_songs',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    // Then delete the item record
    await db.delete(
      'downloads',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  /// Get total download count
  Future<int> getDownloadCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM downloads');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total storage used (sum of all file sizes)
  Future<int> getTotalStorageUsed() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(file_size) as total FROM downloaded_songs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all downloads (for testing/cleanup)
  Future<void> clearAllDownloads() async {
    final db = await database;
    await db.delete('downloaded_songs');
    await db.delete('downloads');
  }
}
