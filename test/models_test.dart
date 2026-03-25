import 'package:flutter_test/flutter_test.dart';
import 'package:starling/models/star.dart';
import 'package:starling/models/constellation.dart';
import 'package:starling/models/daily_card.dart';

void main() {
  group('Star model', () {
    const json = {
      'id': 'vega',
      'name': 'Vega',
      'chineseName': '织女星',
      'rightAscension': 279.235,
      'declination': 38.784,
      'magnitude': 0.03,
      'spectralType': 'A0Va',
      'description': 'Bright star in Lyra.',
      'constellation': 'lyra',
    };

    test('fromJson round-trips via toJson', () {
      final star = Star.fromJson(json);
      expect(star.id, 'vega');
      expect(star.name, 'Vega');
      expect(star.chineseName, '织女星');
      expect(star.rightAscension, 279.235);
      expect(star.declination, 38.784);
      expect(star.magnitude, 0.03);
      expect(star.spectralType, 'A0Va');
      expect(star.description, 'Bright star in Lyra.');
      expect(star.constellation, 'lyra');

      final roundTrip = Star.fromJson(star.toJson());
      expect(roundTrip.id, star.id);
      expect(roundTrip.name, star.name);
      expect(roundTrip.magnitude, star.magnitude);
    });

    test('nullable fields default to null', () {
      final minimal = Star.fromJson({
        'id': 'x',
        'name': 'X',
        'rightAscension': 0.0,
        'declination': 0.0,
        'magnitude': 5.0,
      });
      expect(minimal.chineseName, isNull);
      expect(minimal.spectralType, isNull);
      expect(minimal.description, isNull);
      expect(minimal.constellation, isNull);
    });
  });

  group('Constellation model', () {
    const json = {
      'id': 'orion',
      'name': 'Orion',
      'chineseName': '猎户座',
      'starIds': ['rigel', 'betelgeuse'],
      'lines': [
        {'starId1': 'rigel', 'starId2': 'betelgeuse'}
      ],
      'description': 'The hunter.',
    };

    test('fromJson parses all fields', () {
      final c = Constellation.fromJson(json);
      expect(c.id, 'orion');
      expect(c.name, 'Orion');
      expect(c.chineseName, '猎户座');
      expect(c.starIds, ['rigel', 'betelgeuse']);
      expect(c.lines.length, 1);
      expect(c.lines.first.starId1, 'rigel');
      expect(c.lines.first.starId2, 'betelgeuse');
    });

    test('toJson round-trips', () {
      final c = Constellation.fromJson(json);
      final rt = Constellation.fromJson(c.toJson());
      expect(rt.id, c.id);
      expect(rt.lines.first.starId1, c.lines.first.starId1);
    });
  });

  group('DailyCard model', () {
    const json = {
      'id': 'card1',
      'date': '2024-01-15',
      'title': 'Sirius',
      'chineseTitle': '天狼星',
      'body': 'The brightest star.',
      'imageUrl': 'https://example.com/img.png',
      'wikipediaUrl': 'https://en.wikipedia.org/wiki/Sirius',
      'relatedStarId': 'sirius',
    };

    test('fromJson parses all fields', () {
      final card = DailyCard.fromJson(json);
      expect(card.id, 'card1');
      expect(card.date, '2024-01-15');
      expect(card.title, 'Sirius');
      expect(card.chineseTitle, '天狼星');
      expect(card.body, 'The brightest star.');
      expect(card.imageUrl, 'https://example.com/img.png');
      expect(card.wikipediaUrl, 'https://en.wikipedia.org/wiki/Sirius');
      expect(card.relatedStarId, 'sirius');
    });

    test('toJson round-trips', () {
      final card = DailyCard.fromJson(json);
      final rt = DailyCard.fromJson(card.toJson());
      expect(rt.id, card.id);
      expect(rt.wikipediaUrl, card.wikipediaUrl);
    });

    test('nullable fields default to null', () {
      final minimal = DailyCard.fromJson({
        'id': 'x',
        'date': '2024-01-01',
        'title': 'X',
        'body': 'body',
        'imageUrl': 'https://example.com/img.png',
      });
      expect(minimal.chineseTitle, isNull);
      expect(minimal.wikipediaUrl, isNull);
      expect(minimal.relatedStarId, isNull);
    });
  });
}
