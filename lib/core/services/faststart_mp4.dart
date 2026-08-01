import 'dart:typed_data';

/// Reassembles a non-faststart MP4 (moov atom at the end of the file) into a
/// faststart layout (ftyp + moov + rest) so that ExoPlayer can stream it
/// progressively instead of stalling on the moov-at-end structure.
///
/// The `moov` atom is moved to the front and every `stco`/`co64` chunk offset
/// inside it is shifted by the size of the `moov` box, keeping all sample
/// pointers consistent with the reassembled byte layout.
class FastStartMp4 {
  FastStartMp4._({
    required this.fileLength,
    required this.ftypEnd,
    required this.moovSize,
    required this.moov,
    required this.ftypBytes,
  });

  /// Total byte length of the original file.
  final int fileLength;

  /// End offset of the top-level `ftyp` box in the original (and reassembled)
  /// file. The reassembled layout is `[0, ftypEnd)` ftyp, then the moov box.
  final int ftypEnd;

  /// Size of the (rewritten) `moov` box, including its 8-byte header.
  final int moovSize;

  /// The rewritten `moov` box bytes (chunk offsets shifted by [moovSize]).
  final Uint8List moov;

  /// The `ftyp` box bytes `[0, ftypEnd)`.
  final Uint8List ftypBytes;

  /// Total length of the reassembled faststart file.
  int get faststartLength => fileLength + moovSize;

  /// Offset where the media region (everything after the moov box) begins in
  /// the reassembled file.
  int get mediaStart => ftypEnd + moovSize;

  /// Attempts to parse a reassemblable MP4 from the head and tail of a file.
  ///
  /// Returns `null` (so callers can fall back to passthrough serving) when the
  /// file is already faststart, is not an MP4, or the `moov` box cannot be
  /// located inside [tail].
  static FastStartMp4? tryParse({
    required Uint8List head,
    required Uint8List tail,
    required int fileLength,
  }) {
    if (head.length < 16) return null;

    final ftypEnd = _u32(head, 0);
    if (ftypEnd < 8 || ftypEnd > head.length) return null;
    if (head[4] != 0x66 || head[5] != 0x74 || head[6] != 0x79 || head[7] != 0x70) {
      return null; // not 'ftyp'
    }

    // Already faststart: moov box immediately follows ftyp.
    if (ftypEnd + 8 <= head.length &&
        head[ftypEnd + 4] == 0x6d &&
        head[ftypEnd + 5] == 0x6f &&
        head[ftypEnd + 6] == 0x6f &&
        head[ftypEnd + 7] == 0x76) {
      return null;
    }

    final tailStart = fileLength - tail.length;
    int? moovStart;
    int? moovSize;

    var idx = 0;
    while (true) {
      final i = _findFourCC(tail, idx, _kMoov);
      if (i == -1) break;
      if (i >= 4) {
        final size = _u32(tail, i - 4);
        final boxStart = tailStart + i - 4;
        if (size >= 8 &&
            boxStart + size <= fileLength &&
            (i - 4) + size <= tail.length) {
          moovStart = boxStart;
          moovSize = size;
        }
      }
      idx = i + 4;
    }

    if (moovStart == null || moovSize == null) return null;

    final moovStartInTail = moovStart - tailStart;
    final moovRaw = tail.sublist(moovStartInTail, moovStartInTail + moovSize);
    if (moovRaw.length < 8) return null;

    final rewritten = _rewriteOffsets(moovRaw, moovSize);
    if (rewritten == null) return null;

    return FastStartMp4._(
      fileLength: fileLength,
      ftypEnd: ftypEnd,
      moovSize: moovSize,
      moov: rewritten,
      ftypBytes: Uint8List.fromList(head.sublist(0, ftypEnd)),
    );
  }

  static const _kMoov = [0x6d, 0x6f, 0x6f, 0x76]; // 'moov'
  static const _kStco = [0x73, 0x74, 0x63, 0x6f]; // 'stco'
  static const _kCo64 = [0x63, 0x6f, 0x36, 0x34]; // 'co64'

  /// Shifts every chunk offset in all valid `stco`/`co64` boxes by [delta].
  static Uint8List? _rewriteOffsets(Uint8List moov, int delta) {
    final out = Uint8List.fromList(moov);
    for (final entry in const [
      (fourcc: _kStco, bytes: 4),
      (fourcc: _kCo64, bytes: 8),
    ]) {
      var idx = 0;
      while (true) {
        final i = _findFourCC(out, idx, entry.fourcc);
        if (i == -1 || i < 8) break;
        final boxSize = _u32(out, i - 4);
        final count = _u32(out, i + 8);
        if (16 + entry.bytes * count == boxSize &&
            i + 12 + entry.bytes * count <= out.length) {
          var off = i + 12;
          for (var k = 0; k < count; k++) {
            if (entry.bytes == 4) {
              final v = _u32(out, off);
              _setU32(out, off, v + delta);
            } else {
              final v = _u64(out, off);
              _setU64(out, off, v + delta);
            }
            off += entry.bytes;
          }
        }
        idx = i + 4;
      }
    }
    if (out[4] != 0x6d || out[5] != 0x6f || out[6] != 0x6f || out[7] != 0x76) {
      return null;
    }
    return out;
  }

  static int _findFourCC(Uint8List bytes, int from, List<int> fourcc) {
    for (var i = from; i <= bytes.length - 4; i++) {
      if (bytes[i] == fourcc[0] &&
          bytes[i + 1] == fourcc[1] &&
          bytes[i + 2] == fourcc[2] &&
          bytes[i + 3] == fourcc[3]) {
        return i;
      }
    }
    return -1;
  }

  static int _u32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static void _setU32(Uint8List bytes, int offset, int value) {
    bytes[offset] = (value >> 24) & 0xff;
    bytes[offset + 1] = (value >> 16) & 0xff;
    bytes[offset + 2] = (value >> 8) & 0xff;
    bytes[offset + 3] = value & 0xff;
  }

  static int _u64(Uint8List bytes, int offset) {
    var value = 0;
    for (var i = 0; i < 8; i++) {
      value = (value * 256) + bytes[offset + i];
    }
    return value;
  }

  static void _setU64(Uint8List bytes, int offset, int value) {
    for (var i = 7; i >= 0; i--) {
      bytes[offset + i] = value & 0xff;
      value >>= 8;
    }
  }
}
