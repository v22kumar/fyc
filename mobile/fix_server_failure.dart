import 'dart:io';

void main() {
  final dir = Directory('/root/fyc/mobile/lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  int count = 0;
  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('ServerFailure(e.toString())')) {
      content = content.replaceAll('ServerFailure(e.toString())', 'ServerFailure()');
      file.writeAsStringSync(content);
      count++;
    }
  }
  print('Replaced in $count files.');
}
