import 'package:flutter/material.dart';
import '../models/daily_card.dart';
import '../models/star.dart';

/// A card widget for the Daily Cards list.
///
/// Displays the card's image, date, title, and a snippet of the body.
/// Tapping opens an expanded detail sheet; a "Learn More" button launches
/// the linked Wikipedia page.
class DailyCardItem extends StatelessWidget {
  final DailyCard card;
  final Star? relatedStar;
  final VoidCallback? onWikipediaTap;
  final VoidCallback? onStarTap;

  const DailyCardItem({
    super.key,
    required this.card,
    this.relatedStar,
    this.onWikipediaTap,
    this.onStarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueAccent.withAlpha(51)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageHeader(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _buildBody(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeader() {
    return Stack(
      children: [
        Image.network(
          card.imageUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 180,
            color: const Color(0xFF071020),
            child: const Icon(Icons.broken_image,
                color: Colors.blueGrey, size: 48),
          ),
        ),
        Positioned(
          top: 8,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              card.date,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.chineseTitle != null)
          Text(
            card.chineseTitle!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (card.chineseTitle != null)
          Text(
            card.title,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
          )
        else
          Text(
            card.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          card.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white60, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (card.wikipediaUrl != null)
              OutlinedButton.icon(
                onPressed: onWikipediaTap,
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Wikipedia'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side:
                      BorderSide(color: Colors.blueAccent.withAlpha(128)),
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                ),
              ),
            if (card.wikipediaUrl != null && relatedStar != null)
              const SizedBox(width: 8),
            if (relatedStar != null)
              TextButton.icon(
                onPressed: onStarTap,
                icon: const Icon(Icons.star, size: 14),
                label: Text(relatedStar!.chineseName ?? relatedStar!.name),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amber,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Image.network(
                card.imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              if (card.chineseTitle != null)
                Text(
                  card.chineseTitle!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                card.title,
                style: TextStyle(
                  color: card.chineseTitle != null
                      ? Colors.blueGrey
                      : Colors.white,
                  fontSize: card.chineseTitle != null ? 14 : 22,
                  fontWeight: card.chineseTitle != null
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.date,
                style:
                    const TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Text(
                card.body,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 15, height: 1.7),
              ),
              const SizedBox(height: 20),
              if (card.wikipediaUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onWikipediaTap?.call();
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Learn More on Wikipedia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withAlpha(179),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
