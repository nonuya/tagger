import 'package:image_extractor/image_extractor.dart' as image_extractor;

void main(List<String> arguments) async {
  final task = image_extractor.get_image_url_from_hitomi_url("https://hitomi.la/reader/3855946.html#2-3");
  final o = task.run();

  print(await o);
}
