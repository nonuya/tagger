import 'package:flutter/material.dart';
import 'package:tagger/theme.dart';
import 'package:tagger/serializer.dart';
import 'package:toastification/toastification.dart';
import 'package:tagger/home_page.dart' as home;
import 'package:tagger/add_page.dart' as add;

final test_artist = Artist(
  name: NonEmptyString.unsafeMake("Artista 1"),
  tags: [
    ArtistTag(
      tag_id: 0,
      image_url: NonEmptyString.unsafeMake(
        "https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiGWe25pqRXuepd0hncJ-vYW2M8h7kGQcegq0osoCcc4hOahM9d0D18AFlgMJo25cLYGtRb3oiVpup6k00cZLkfeZVaQvHLuzchYb_H19czh_QLLG7OTGYWSNxdcAWyX0i6YlylOvJOmEe0694b-1RKxQbhB1wbPHHZsIpwA5Z_SUuKCMtRKK8Krwt1/s1600/02.jpg",
      ),
    ),
    ArtistTag(
      tag_id: 1,
      image_url: NonEmptyString.unsafeMake(
        "https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjPZJEEv8Tx8b-l6VQwlZ7w1d5KxImcoqdY9POMXYJEBqpmDHkU18alSwGgcYl87d7pPhvLpRk6jgZ3cg8vFmO9IL9m4ZR7Mm8urORYO6RGKz2BBhXCD8HVhnT60t5J5iHTj6UyRGkhH8vBYcgaQW2BIIXDPfLcv_nDEeZrRat4PuATk4pvsJL-iCgL/s2133/05.jpg",
      ),
    ),
    ArtistTag(
      tag_id: 2,
      image_url: NonEmptyString.unsafeMake(
        "https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhJdhOIv8EydfMJNR2Uf0cATMZyJB0iu8fXs5WpfUDk7F_KbdX4towpWBMTqppolgcUOqZxbIYuUEELpx5VA6GamyNrxen2xB8Fr1ZIs4h3ENtkKt1L0LmIq15QDDHfnnExWuJCX4PiWHYh89ufZsotemfUiArjVuqxr7ryXqxWfN0pwMVBVlnLNQ6Q/s1600/07.jpg",
      ),
    ),
    ArtistTag(
      tag_id: 3,
      image_url: NonEmptyString.unsafeMake(
        "https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEin8I9uhcHN2cyamr6cIeWH5uAyn-6KRKnkAx96XqHhKEp_PdoczzPWuj3RHebIbSU6VpL2FEiYlHSVY3fuCn5d5P-vR2YQyaV3KMRnHi4HwSDWwLP2Y2aqqzxvPRMfiCN_bea7y_VZVNzmWPIFn39zfbcyO7AxSLn-Pjm-4JUeK66TLSTZWyiwBwHW/s1600/09.jpg",
      ),
    ),
    ArtistTag(
      tag_id: 4,
      image_url: NonEmptyString.unsafeMake(
        "https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjXq6WAPV8sDb2YDdjsjGUQu1r6fx9aaBVtqC-kM43qCfL7bD_4NW5uA5Obkqdd3aU5kyCGjuUlSdHGoqnW3jz5VTzAnmRCwXFP40LcPRJRbbcf1NYjRVYGmDE0WavqSZCvjpPo3h1VdU-e9R2yrtQOouTslpeh8JZQcGl9GyzYHXsq8ToyZabn4oAH/s1600/10.jpg",
      ),
    ),
    ArtistTag(
      tag_id: 5,
      image_url: NonEmptyString.unsafeMake(
        "https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhJkPna2XmAlJ36Y0A0dQmv6BqmLdyUKuCD5mo3rX2qg_G3363wKOVJI4w4OAU9i6-SOtL_vs4WI-t2rhp2-hi7lMxFh-vSIK99uGyBw6UNBvmFm5R2cfAu8bitljEg6BfrXHYok0oHU6Iz16bmq_EkQW7Wz-mysd9XbHxMfJUAyRCE5YCc0sydrX56/s1600/12.jpg",
      ),
    ),
  ],
);

// O(n) but more cache locality
final vec_tags = [
  Tag(id: 0, name: .unsafeMake("Tag 1")),
  Tag(id: 1, name: .unsafeMake("Tag 2")),
  Tag(id: 2, name: .unsafeMake("Tag 3")),
  Tag(id: 3, name: .unsafeMake("Tag 4")),
  Tag(id: 4, name: .unsafeMake("Tag 5")),
  Tag(id: 5, name: .unsafeMake("Tag 6")),
];

final test_tags = {
  0: vec_tags[0],
  1: vec_tags[1],
  2: vec_tags[2],
  3: vec_tags[3],
  4: vec_tags[4],
  5: vec_tags[5],
};

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  final controller = PageController(initialPage: 1, keepPage: true);

  App({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        theme: get_app_theme_data(),
        home: Scaffold(
          body: Padding(
            padding: EdgeInsetsGeometry.all(16),
            child: SafeArea(
              child: PageView(
                controller: controller,
                children: [buildHomePage(), buildAddPage()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHomePage() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          flex: 0,
          child: TextField(
            decoration: InputDecoration(hintText: "Search by..."),
          ),
        ),
        SizedBox(height: 10),
        home.ArtistItem(test_artist),
      ],
    );
  }

  Widget buildAddPage() {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const Text(
          "Add",
          textAlign: .center,
          style: TextStyle(fontWeight: .bold, fontSize: 24),
        ),
        SizedBox(height: 10),
        add.TagForm(),
      ],
    );
  }
}