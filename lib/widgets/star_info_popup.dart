import 'package:flutter/material.dart';
import '../models/star.dart';

/// A modal-like overlay that shows details about a tapped [star].
class StarInfoPopup extends StatelessWidget {
  final Star star;
  final VoidCallback onClose;
  /// When `true` (default), the primary name shown is the Chinese name (falling
  /// back to the Latin name).  When `false`, the primary name is always the
  /// Latin/IAU name.
  final bool showChineseName;

  const StarInfoPopup({
    super.key,
    required this.star,
    required this.onClose,
    this.showChineseName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE6081428),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blueAccent.withAlpha(102),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showChineseName
                              ? (star.chineseName ?? star.name)
                              : star.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (showChineseName && star.chineseName != null)
                          Text(
                            star.name,
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 14,
                            ),
                          ),
                        if (!showChineseName && star.chineseName != null)
                          Text(
                            star.chineseName!,
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white54),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Chip(
                    label: 'Mag ${star.magnitude.toStringAsFixed(2)}',
                    icon: Icons.brightness_3,
                  ),
                  if (star.spectralType != null)
                    _Chip(
                      label: star.spectralType!,
                      icon: Icons.colorize,
                    ),
                  if (star.constellation != null)
                    _Chip(
                      label: star.constellation!
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                      icon: Icons.star_border,
                    ),
                ],
              ),
              if (star.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  star.description!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _CoordRow(
                label: 'RA',
                value: '${star.rightAscension.toStringAsFixed(3)}°',
              ),
              _CoordRow(
                label: 'Dec',
                value: '${star.declination.toStringAsFixed(3)}°',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withAlpha(76)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  final String label;
  final String value;

  const _CoordRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              label,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
