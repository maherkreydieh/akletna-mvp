import 'package:akletna_frontend/widgets/kitchen_thumbnail.dart';
import 'package:akletna_frontend/widgets/recipe_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'recipe images request bounded physical decode sizes and retain error fallbacks',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 3),
            child: Scaffold(
              body: Column(
                children: const [
                  KitchenThumbnail(
                    url: 'https://example.test/photo.jpg',
                    size: 80,
                  ),
                  RecipeImage(
                    url: 'https://example.test/hero.jpg',
                    height: 160,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final thumbnail = images[0].image as ResizeImage;
      final hero = images[1].image as ResizeImage;
      expect(thumbnail.width, 240);
      expect(hero.height, 480);
      expect(images.every((image) => image.errorBuilder != null), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
