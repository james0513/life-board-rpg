// Parse every shipped Dart source. No Flutter, dependencies, or network required.
import 'dart:io';

void main(List<String> args) {
  final root = args.isEmpty
      ? File.fromUri(Platform.script).parent.parent.path
      : Directory(args.single).absolute.path;
  final temporary = Directory.systemTemp.createTempSync(
    'life-syntax-regression-',
  );
  try {
    // Reproduce v0.26's unterminated ordinary string and verify rejection.
    final invalid = File('${temporary.path}/invalid.dart')
      ..writeAsStringSync("void main() { print('first\nsecond'); }\n");
    final rejected = Process.runSync(Platform.resolvedExecutable, [
      'format',
      '--output=none',
      invalid.path,
    ]);
    if (rejected.exitCode == 0 ||
        !'${rejected.stdout}${rejected.stderr}'.contains(
          'Unterminated string',
        )) {
      stderr.writeln(
        'FAIL: parser did not reject the v0.26 regression fixture',
      );
      exitCode = 1;
      return;
    }
    final files = <String>[];
    for (final folder in ['lib', 'test', 'tools']) {
      if (!Directory('$root/$folder').existsSync()) {
        stderr.writeln('FAIL: missing required source directory $folder');
        exitCode = 1;
        return;
      }
    }
    // Include top-level Dart files as well as the usual source directories.
    // Only generated/tool-cache directories are excluded, never shipped source.
    void collect(Directory directory) {
      for (final entry in directory.listSync(followLinks: false)) {
        if (entry is Directory) {
          final name = entry.uri.pathSegments.where((p) => p.isNotEmpty).last;
          if (!{'.git', '.dart_tool', 'build'}.contains(name)) collect(entry);
        } else if (entry is File && entry.path.endsWith('.dart')) {
          files.add(entry.path);
        }
      }
    }

    collect(Directory(root));
    files.sort();
    var failures = 0;
    for (final file in files) {
      final result = Process.runSync(Platform.resolvedExecutable, [
        'format',
        '--output=none',
        file,
      ], workingDirectory: root);
      stdout.writeln('PARSE exit=${result.exitCode}: $file');
      if (result.exitCode != 0) {
        failures++;
        stderr.writeln('FAIL (exit ${result.exitCode}): $file');
        stderr.write(result.stdout);
        stderr.write(result.stderr);
      }
    }
    stdout.writeln(
      'Parsed ${files.length} Dart files; failures=$failures. '
      'Invalid-newline regression rejected (exit ${rejected.exitCode}).',
    );
    if (failures > 0) exitCode = 1;
  } finally {
    temporary.deleteSync(recursive: true);
  }
}
