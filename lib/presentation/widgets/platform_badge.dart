import 'package:flutter/material.dart';

class PlatformBadge extends StatelessWidget {
  final String providerKey;
  final double size;
  final bool showTooltip;

  const PlatformBadge({
    super.key,
    required this.providerKey,
    this.size = 20,
    this.showTooltip = true,
  });

  static const Map<String, String> _displayNames = {
    'bibishort': 'Bibi Short',
    'bilitv': 'BiliTV',
    'cubetv': 'CubeTV',
    'dotdrama': 'DotDrama',
    'dramabite': 'DramaBite',
    'dramabox': 'DramaBox',
    'dramanova': 'DramaNova',
    'dramawave': 'DramaWave',
    'flareflow': 'FlareFlow',
    'flextv': 'FlexTV',
    'flickreels': 'FlickReels',
    'freereels': 'FreeReels',
    'fundrama': 'FunDrama',
    'goodshort': 'GoodShort',
    'happyshort': 'HappyShort',
    'idrama': 'iDrama',
    'joyreels': 'JoyReels',
    'kalostv': 'KalosTV',
    'melolo': 'MeLoLo',
    'microdrama': 'MicroDrama',
    'moboreels': 'MoboReels',
    'netshort': 'NetShort',
    'pinedrama': 'PineDrama',
    'rapidtv': 'RapidTV',
    'reelbuzz': 'ReelBuzz',
    'reelife': 'Reelife',
    'reelshort': 'ReelShort',
    'serealplus': 'SerealPlus',
    'shortical': 'Shortical',
    'shortmax': 'ShortMax',
    'stardusttv': 'StardustTV',
    'starshort': 'StarShort',
    'shortwave': 'ShortWave',
    'dramafren_dramabox': 'DramaFren Box',
    'shortflix': 'ShortFlix',
    'shortdizilab': 'ShortDiziLab',
    'dramaexpress': 'DramaExpress',
    'velolo': 'VeLoLo',
    'vigloo': 'Vigloo',
    'vyntage': 'Vyntage',
  };

  String get _displayName {
    final name = _displayNames[providerKey];
    if (name != null) return name;
    if (providerKey.isEmpty) return 'Narto';
    return providerKey[0].toUpperCase() + providerKey.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: providerKey.isEmpty
          ? const Icon(Icons.language, size: 12, color: Colors.white)
          : Image.asset(
              'assets/logos/${providerKey.toLowerCase()}.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  providerKey[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
    );
    if (!showTooltip || _displayName.isEmpty) return badge;
    return Tooltip(message: _displayName, child: badge);
  }
}
