class FormatUtils {
  /// Format time in milliseconds to adaptive string (e.g. 3407ms -> 3.407s)
  static String formatTime(int ms) {
    if (ms >= 1000) {
      return '${(ms / 1000).toStringAsFixed(3)}s';
    }
    return '${ms}ms';
  }

  /// Format size in bytes to adaptive string (KB, MB, GB)
  static String formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(3)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(3)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(3)} KB';
    }
    return '$bytes B';
  }

  /// Format size in MB to adaptive string
  static String formatSizeMB(double mb) {
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(3)} GB';
    }
    return '${mb.toStringAsFixed(3)} MB';
  }

  /// Format speed in Gbps (fixed unit)
  static String formatSpeedGbps(double gbps) {
    return '${gbps.toStringAsFixed(3)} Gb/s';
  }
}
