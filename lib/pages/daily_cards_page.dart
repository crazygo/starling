import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/daily_card.dart';
import '../models/star.dart';
import '../services/star_data_service.dart';
import '../widgets/daily_card_item.dart';

/// The Daily Cards page — a vertically scrollable list of curated astronomy
/// content cards with links to Wikipedia.
class DailyCardsPage extends StatefulWidget {
  const DailyCardsPage({super.key});

  @override
  State<DailyCardsPage> createState() => _DailyCardsPageState();
}

class _DailyCardsPageState extends State<DailyCardsPage> {
  List<DailyCard> _cards = [];
  Map<String, Star> _starMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = await StarDataService.instance();
    if (mounted) {
      setState(() {
        _cards = service.dailyCards;
        _starMap = {for (final s in service.stars) s.id: s};
        _loading = false;
      });
    }
  }

  Future<void> _openWikipedia(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05091A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF05091A),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          '每日星空',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _cards.isEmpty
              ? const Center(
                  child: Text(
                    '暂无内容',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: _cards.length,
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    final star = card.relatedStarId != null
                        ? _starMap[card.relatedStarId]
                        : null;
                    return DailyCardItem(
                      card: card,
                      relatedStar: star,
                      onWikipediaTap: card.wikipediaUrl != null
                          ? () => _openWikipedia(card.wikipediaUrl!)
                          : null,
                    );
                  },
                ),
    );
  }
}
